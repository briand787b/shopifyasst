package asset

import (
	"fmt"
	"log"
	"strconv"
	"time"
)

const (
	// seconds to wait before retry
	searchProductRetrySec = 1
	// # of retries before considered failure
	searchProductRetryCount = 60
)

// UploadAsset is the entrypoint for asset upload.  It creates/uploads
// the asset, then associates that asset with a Shopify product.
// It returns the asset
func UploadAsset(filename string, u Uploader) (*Asset, error) {
	img, err := NewAsset(filename)
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

// AssociateAssetWithShopifyProduct links a Shopify product with a DDA asset (image).
// The DDA API requires the DDA id of the Shopify product, which is held in DDA's database.
// This requires the function to search DDA product API with the Shopify product ID.  The
// returned product, if found, will contain the DDA product ID to use in the association
// method that ultimately links the product and the asset.  Retries are required because
// DDA can be slow to update their product API
func AssociateAssetWithShopifyProduct(ddaAssetID, shopifyProductIDStr string, a Associater) error {
	shopifyProductID, err := strconv.Atoi(shopifyProductIDStr)
	if err != nil {
		return fmt.Errorf("cannot convert %s to integer: %w", shopifyProductIDStr, err)
	}

	// find the product's DDA id - allow retries for slow DDA updates
	var ddaProductID string
	for i := 0; i < searchProductRetryCount; i++ {
		ddaProductID, err = a.GetDDAProductID(shopifyProductID)
		if err == nil {
			break
		}

		err = fmt.Errorf("cannot find product in DDA: %w", err)
		log.Printf("product search failed (%s). retrying in %ds", err, searchProductRetrySec)
		time.Sleep(searchProductRetrySec * time.Second)
	}

	if err != nil {
		return fmt.Errorf("retry count exceeded: %w", err)
	}

	// associate the asset with the shopify product
	if err := a.AssociateShopifyProductWithAsset(ddaProductID, ddaAssetID); err != nil {
		return fmt.Errorf("cannot associate shopify product with asset: %w", err)
	}

	return nil
}
