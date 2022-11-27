package asset

import (
	"bytes"
	"errors"
	"fmt"
	"log"
	"mime"
	"os"
	"path/filepath"
	"sync"
)

const (
	mimeTypeJPEG = "image/jpeg"
)

// Image represents any digital image, though it is currently only
// able to handle JPEGs
type Image struct {
	ID       string
	Filename string
	Size     int64
	MimeType string
	UploadID string

	contents     *os.File
	partitions   []UploadPartition
	partitionsMx *sync.RWMutex
}

// NewImage is the factory for creating an Image asset
func NewImage(filename string) (*Image, error) {
	fi, err := os.Stat(filename)
	if err != nil {
		return nil, fmt.Errorf("could not stat file %s: %w", filename, err)
	}

	mime := mime.TypeByExtension(filepath.Ext(filename))
	if mime != mimeTypeJPEG {
		return nil, fmt.Errorf("mime type is not %s (is: '%s')", mimeTypeJPEG, mime)
	}

	fd, err := os.Open(filename)
	if err != nil {
		return nil, fmt.Errorf("could not open file: %w", err)
	}

	return &Image{
		Filename: filename,
		Size:     fi.Size(),
		MimeType: mime,

		contents:     fd,
		partitions:   make([]UploadPartition, 0),
		partitionsMx: &sync.RWMutex{},
	}, nil
}

func (i *Image) Close() {
	if err := i.contents.Close(); err != nil {
		log.Printf("could not close file %s: %s", i.Filename, err)
	}
}

func (i *Image) GetPartitionIDs() []int {
	i.partitionsMx.RLock()
	defer i.partitionsMx.RUnlock()

	ids := make([]int, len(i.partitions))
	for i, p := range i.partitions {
		ids[i] = p.ID
	}

	return ids
}

func (i *Image) GetPartition(partID int) (UploadPartition, error) {
	i.partitionsMx.RLock()
	defer i.partitionsMx.RUnlock()

	// no need for sorting or searching algorithms
	for _, p := range i.partitions {
		if p.ID == partID {
			return p, nil
		}
	}

	return UploadPartition{}, fmt.Errorf("no partition found wtih id %d", partID)
}

func (i *Image) SetPartition(p UploadPartition) error {
	if p.ID < 1 {
		return errors.New("cannot set partition with non-positive ID")
	}

	partitionContents := make([]byte, p.EndByte-p.StartByte)
	n, err := i.contents.ReadAt(partitionContents, int64(p.StartByte))
	if err != nil {
		return fmt.Errorf("failed to read part of file: %w", err)
	} else if n < 1 {
		return errors.New("no bytes read from file")
	}

	p.contents = bytes.NewReader(partitionContents)

	i.partitionsMx.Lock()
	defer i.partitionsMx.Unlock()

	// no need for sorting or searching algorithms
	for idx, existant := range i.partitions {
		if existant.ID == p.ID {
			i.partitions[idx] = p
			return nil
		}
	}

	i.partitions = append(i.partitions, p)
	return nil
}
