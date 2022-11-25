package asset

// Associater abstracts the method(s) required to associate a
// Shopify product with a saved Downloadable Digital Assets asset
type Associater interface {
	AssociateShopifyProductWithAsset(productID, assetID string) error
}
