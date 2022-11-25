package dda

// AssociateProductsRequest is the payload to associate a
// DDA asset with one or more Shopify products
type AssociateProductsRequest struct {
	Products []string `json:"products"`
}
