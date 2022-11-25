package asset

import (
	"fmt"
	"log"
	"strconv"
	"time"
)

// UploadImage is the entrypoint for asset upload.  It creates/uploads
// the asset, then associates that asset with a Shopify product.
// It returns the asset
func UploadImage(filename string, u Uploader) (*Image, error) {
	img, err := NewImage(filename)
	if err != nil {
		return nil, fmt.Errorf("could not create image: %w", err)
	}

	defer img.Close()

	// store image metadata
	if err := u.CreateMetaData(img); err != nil {
		return nil, fmt.Errorf("could not create metadata: %w", err)
	}

	// upload image parts
	if err := u.UploadParts(img); err != nil {
		return nil, fmt.Errorf("could not upload image parts: %w", err)
	}

	// confirm upload completion
	if err := u.ConfirmUpload(img); err != nil {
		return nil, fmt.Errorf("could not confirm upload: %w", err)
	}

	return img, nil
}

func AssociateImageWithShopifyProduct(ddaAssetID, shopifyProductIDStr string, a Associater) error {
	shopifyProductID, err := strconv.Atoi(shopifyProductIDStr)
	if err != nil {
		return fmt.Errorf("cannot convert %s to integer: %w", shopifyProductIDStr, err)
	}

	// find the product's DDA id - have some retries
	var ddaProductID string
	for i := 0; i < 10; i++ {
		ddaProductID, err = a.GetDDAProductID(shopifyProductID)
		if err == nil {
			break
		}

		err = fmt.Errorf("cannot find product in DDA: %w", err)
		log.Printf("product search failed (%s). retrying in 500ms", err)
		time.Sleep(100 * time.Millisecond)
	}

	if err != nil {
		return err
	}

	// associate the asset with the shopify product
	if err := a.AssociateShopifyProductWithAsset(ddaProductID, ddaAssetID); err != nil {
		return fmt.Errorf("cannot associate shopify product with asset: %w", err)
	}

	return nil
}
