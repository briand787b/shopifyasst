package asset

import (
	"bytes"
	"io"
)

// UploadPartition represents a segment of the file that can be
// uploaded separately from the other segments
type UploadPartition struct {
	ID        int
	URL       string // comes from response payload
	ETag      string
	StartByte uint64
	EndByte   uint64
	contents  *bytes.Reader
}

func (p *UploadPartition) Contents() io.Reader {
	return p.contents
}
