package asset

import (
	"fmt"
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

func AssociateImageWithShopifyProduct(ddaAssetID, shopifyProductID string, a Associater) error {
	// associate the asset with the shopify product

	return nil
}
