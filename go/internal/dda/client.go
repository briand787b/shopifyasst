package dda

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/briand787b/shopifyasst/internal/asset"
)

const baseV1URL = "https://app.digital-downloads.com/api/v1"

// Client is a client that communicates with the Downloadable
// Digital Assets HTTP API
type Client struct {
	authToken string
	client    *http.Client
}

// NewDownloadableDigitalAssetsClient is the factory for the
// DDA client.  It defaults to a 60 second timeout to handle
// large files and slow connections
func NewDownloadableDigitalAssetsClient(token string) *Client {
	return &Client{
		authToken: token,
		client: &http.Client{
			// files might be large, give enough time
			Timeout: 60 * time.Second,
		},
	}
}

// CreateMetaData stores asset metadata in DDA
func (c *Client) CreateMetaData(i *asset.Image) error {
	body := CreateAssetMetaDataRequest{
		Name: i.Filename,
		Size: i.Size,
		Mime: i.MimeType,
	}

	bodyJSON, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("marshalling %T to JSON failed: %w", body, err)
	}

	req, err := http.NewRequest(
		http.MethodPost,
		baseV1URL+"/assets/signed",
		bytes.NewReader(bodyJSON),
	)
	if err != nil {
		return fmt.Errorf("request creation failed: %w", err)
	}

	resp, err := c.client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}

	defer resp.Body.Close()

	if code := resp.StatusCode; code != http.StatusOK {
		return fmt.Errorf("reponse status code not 200 (is: %d)", code)
	}

	bodyBS, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("response body is unreadable: %w", err)
	}

	var respBody CreateAssetMetaDataResponse
	if err := json.Unmarshal(bodyBS, &respBody); err != nil {
		return fmt.Errorf(
			"could not marshal %s into %T: %w",
			string(bodyBS), respBody, err,
		)
	}

	i.ID = respBody.ID
	i.UploadID = respBody.UploadID

	var uploadPart asset.UploadPartition
	for _, u := range respBody.Urls {
		if u.End < 1 {
			return fmt.Errorf("response suggests using a zero-length partition")
		}

		uploadPart.ID = u.Part
		uploadPart.URL = u.URL
		uploadPart.StartByte = u.Start
		uploadPart.EndByte = u.End

		i.SetPartition(uploadPart)
	}

	return nil
}

func (c *Client) UploadParts(i *asset.Image) error {
	partIDs := i.GetPartitionIDs()

	parts := make([]asset.UploadPartition, len(partIDs))
	for idx, partID := range partIDs {
		uploadPart, err := i.GetPartition(partID)
		if err != nil {
			return fmt.Errorf("could not get image partition: %w", err)
		}

		parts[idx] = uploadPart
	}

	wg := sync.WaitGroup{}
	errChan := make(chan error, len(parts))

	// must use index-based for loop (not range) to get correct
	// memory address when passing pointer to element
	for i := 0; i < len(parts); i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			part := parts[i]
			err := c.uploadPart(&part)
			if err != nil {
				err = fmt.Errorf("failed to upload partition #%d: %w",
					part.ID, err)
			}

			errChan <- err
		}(i)
	}

	wg.Wait()
	close(errChan)

	for err := range errChan {
		if err != nil {
			return fmt.Errorf("at least one partition upload failed: %w", err)
		}
	}

	for _, part := range parts {
		if err := i.SetPartition(part); err != nil {
			return fmt.Errorf("failed to set partition: %w", err)
		}
	}

	return nil
}

// uploadPart uploads the provided partition, returning its ETag and an
// optional error
func (c *Client) uploadPart(p *asset.UploadPartition) error {
	req, err := http.NewRequest(http.MethodPut, p.URL, p.Contents())
	if err != nil {
		return fmt.Errorf("failed to build request: %w", err)
	}

	req.Header.Del("Content-Type")

	resp, err := c.client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}

	defer resp.Body.Close()

	if code := resp.StatusCode; code != http.StatusOK {
		return fmt.Errorf("response status code not 200 (is %d)", code)
	}

	etag := resp.Header.Get("ETag")
	etag = strings.Trim(etag, "\"")
	if etag == "" {
		return errors.New("ETag header is empty")
	}

	p.ETag = etag

	return nil
}

func (c *Client) ConfirmUpload(i *asset.Image) error {
	payload := UploadConfirmationRequest{
		UploadID: i.UploadID,
	}

	for _, partID := range i.GetPartitionIDs() {
		part, err := i.GetPartition(partID)
		if err != nil {
			return fmt.Errorf("could not get partition: %w", err)
		}

		payload.Partitions = append(
			payload.Partitions,
			struct {
				Partition int    "json:\"PartNumber\""
				ETag      string "json:\"ETag\""
			}{
				Partition: part.ID,
				ETag:      part.ETag,
			},
		)
	}

	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("could not marshal request to JSON: %w", err)
	}

	req, err := http.NewRequest(
		http.MethodPost,
		baseV1URL+fmt.Sprintf("/assets/%s/uploaded", i.ID),
		bytes.NewReader(payloadJSON),
	)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	resp, err := c.client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}

	defer resp.Body.Close()

	if code := resp.StatusCode; code != http.StatusCreated {
		return fmt.Errorf("resp status code not 201 (is: %d)", code)
	}

	return nil
}

func (c *Client) AssociateShopifyProductWithAsset(productID, assetID string) error {
	payload := AssociateProductsRequest{
		Products: []string{productID},
	}

	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal request to JSON: %w", err)
	}

	req, err := http.NewRequest(
		http.MethodPost,
		baseV1URL+fmt.Sprintf("/assets/%s/attach", assetID),
		bytes.NewReader(payloadJSON),
	)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	resp, err := c.client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}

	if code := resp.StatusCode; code != http.StatusCreated {
		return fmt.Errorf("resp status code not 201 (is: %d)", code)
	}

	return nil
}
