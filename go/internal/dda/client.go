package dda

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/briand787b/shopifyasst/internal/asset"
)

const (
	baseV1URL                      = "https://app.digital-downloads.com/api/v1"
	reqTryCountCtxKey clientCtxKey = "reqTryCount"
)

type clientCtxKey string

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
func (c *Client) CreateMetaData(i *asset.Asset) error {
	body := CreateAssetMetaDataRequest{
		Name: filepath.Base(i.Filename),
		Size: i.Size,
		Mime: i.MimeType,
	}

	bodyJSON, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("marshalling %T to JSON failed: %w", body, err)
	}

	log.Printf("[DEBUG] create metadata request JSON: %s", bodyJSON)

	req, err := http.NewRequest(
		http.MethodPost,
		baseV1URL+"/assets/signed",
		bytes.NewReader(bodyJSON),
	)
	if err != nil {
		return fmt.Errorf("request creation failed: %w", err)
	}
	log.Printf("[DEBUG] create metadata request url: %s", req.URL)

	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", c.authToken))
	req.Header.Set("Content-Type", "applicatin/json")
	log.Printf("[DEBUG] create metadata request headers: %+v", req.Header)

	var respBody CreateAssetMetaDataResponse
	err = send(context.Background(), c.client, req, http.StatusOK, &respBody)
	if err != nil {
		return fmt.Errorf("request failed: %w", err)
	}

	i.ID = respBody.ID
	i.UploadID = respBody.UploadID

	var uploadPart asset.UploadPartition
	for _, u := range respBody.Urls {
		if u.End < 1 {
			return errors.New("response suggests using a zero-length partition")
		}

		uploadPart.ID = u.Part
		uploadPart.URL = u.URL
		uploadPart.StartByte = u.Start
		uploadPart.EndByte = u.End

		i.SetPartition(uploadPart)
	}

	return nil
}

func (c *Client) UploadParts(i *asset.Asset) error {
	partIDs := i.PartitionIDs()

	parts := make([]asset.UploadPartition, len(partIDs))
	for idx, partID := range partIDs {
		uploadPart, err := i.Partition(partID)
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
			err := c.uploadPart(&parts[i])
			if err != nil {
				err = fmt.Errorf("failed to upload partition #%d: %w",
					parts[i].ID, err)
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
		log.Printf("[DEBUG] setting partition: %+v", part)
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

// ConfirmUpload is the final stage of creating an asset in DDA.
// Call this method after all partitions of the asset have already
// been successfully uploaded.
func (c *Client) ConfirmUpload(i *asset.Asset) error {
	payload := UploadConfirmationRequest{
		UploadID: i.UploadID,
	}

	for _, partID := range i.PartitionIDs() {
		part, err := i.Partition(partID)
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

	log.Printf("[DEBUG] confirmation request JSON: %s", payloadJSON)

	req, err := http.NewRequest(
		http.MethodPost,
		baseV1URL+fmt.Sprintf("/assets/%s/uploaded", i.ID),
		bytes.NewReader(payloadJSON),
	)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	log.Printf("[DEBUG] confirmation request url: %s", req.URL)

	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", c.authToken))
	req.Header.Set("Content-Type", "applicatin/json")
	log.Printf("[DEBUG] confirmation request headers: %+v", req.Header)

	err = send(context.Background(), c.client, req, http.StatusCreated, nil)
	if err != nil {
		return fmt.Errorf("request failed: %w", err)
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

	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", c.authToken))
	req.Header.Set("Content-Type", "applicatin/json")
	log.Printf("[DEBUG] association request headers: %+v", req.Header)

	err = send(context.Background(), c.client, req, http.StatusCreated, nil)
	if err != nil {
		return fmt.Errorf("request failed: %w", err)
	}

	return nil
}

func (c *Client) GetDDAProductID(shopifyProductID int) (string, error) {
	req, err := http.NewRequest(
		http.MethodGet,
		baseV1URL+fmt.Sprintf("/products?product_id=%d", shopifyProductID),
		nil,
	)
	if err != nil {
		return "", fmt.Errorf("could not build product list request: %w", err)
	}

	log.Printf("[DEBUG] product list request url: %s", req.URL)

	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", c.authToken))
	req.Header.Set("Content-Type", "applicatin/json")
	log.Printf("[DEBUG] product list request headers: %+v", req.Header)

	var productListResp ProductListResponse
	if err := send(context.Background(), c.client, req, http.StatusOK, &productListResp); err != nil {
		return "", fmt.Errorf("failed to send request: %w", err)
	}

	searchedProductIDs := make([]int, len(productListResp.Data))
	for _, product := range productListResp.Data {
		if product.ProductID == shopifyProductID {
			return product.ID, nil
		}

		searchedProductIDs = append(searchedProductIDs, product.ProductID)
	}

	log.Printf("[DEBUG] %d not found in %+v", shopifyProductID, searchedProductIDs)
	log.Printf("[DEBUG] product list: %+v", productListResp)

	return "", fmt.Errorf("product_id '%d' does not exist in DDA", shopifyProductID)
}

func send(ctx context.Context, client *http.Client, req *http.Request, expCode int, marshalTarget interface{}) error {
	// this API enforces request limits - use exponential backoff
	reqTryCount, _ := ctx.Value(reqTryCountCtxKey).(int)
	backoff := math.Pow(math.E, float64(reqTryCount)) - 1
	time.Sleep(time.Second * time.Duration(backoff))

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send request: %w", err)
	}

	defer resp.Body.Close()

	if code := resp.StatusCode; code != expCode {
		if code == http.StatusTooManyRequests {
			// recursive might not be ideal, but it should work
			log.Printf("[DEBUG] Attempt #%d failed (%d), backing off...",
				reqTryCount, code)
			ctx = context.WithValue(ctx, reqTryCountCtxKey, reqTryCount+1)
			return send(ctx, client, req, expCode, marshalTarget)
		}

		body, err := io.ReadAll(resp.Body)
		if err != nil {
			log.Printf("could not read failure resp msg body: %s", err)
		} else {
			log.Printf("association resp body: %s", body)
		}

		return fmt.Errorf("expected HTTP status code %d, got %d", expCode, code)
	}

	if marshalTarget == nil {
		return nil
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("coud not read resp body: %w", err)
	}

	if err := json.Unmarshal(body, marshalTarget); err != nil {
		return fmt.Errorf("could not unmarshal resp JSON %s into %T: %w",
			body, marshalTarget, err,
		)
	}

	return nil
}
