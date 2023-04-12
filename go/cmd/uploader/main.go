package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/briand787b/shopifyasst/internal/asset"
	"github.com/briand787b/shopifyasst/internal/dda"
)

const (
	filenameFlag  = "filename"
	productIDFlag = "product"
	authTokenFlag = "token"
)

var (
	filename  = flag.String(filenameFlag, "", "name of image file to upload")
	productID = flag.String(productIDFlag, "", "id of product to associate asset with")
	authToken = flag.String(authTokenFlag, "", "DDA auth token")
)

func main() {
	flag.Parse()
	if *filename == "" {
		fmt.Printf("%s flag is mandatory\n", filenameFlag)
		os.Exit(10)
	}

	if *productID == "" {
		fmt.Printf("%s flag is mandatory\n", productIDFlag)
		os.Exit(20)
	}

	if *authToken == "" {
		fmt.Printf("%s flag is mandatory\n", authTokenFlag)
		os.Exit(30)
	}

	ddaClient := dda.NewDownloadableDigitalAssetsClient(*authToken)

	img, err := asset.UploadAsset(*filename, ddaClient)
	if err != nil {
		fmt.Printf("could not create DDA image asset: %s\n", err)
		os.Exit(40)
	}

	err = asset.AssociateAssetWithShopifyProduct(img.ID, *productID, ddaClient)
	if err != nil {
		fmt.Printf("could not associate asset with Shopify product: %s\n", err)
		os.Exit(50)
	}

	fmt.Println("successfully uploaded and associated DDA image")
}
