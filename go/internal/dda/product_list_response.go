package dda

type ProductListResponse struct {
	Data []struct {
		ID          string      `json:"id"`
		Name        string      `json:"name"`
		VariantName interface{} `json:"variant_name"`
		Sku         string      `json:"sku"`
		ProductID   int         `json:"product_id"`
		VariantID   int64       `json:"variant_id"`
		Vendor      string      `json:"vendor"`
		Tags        []string    `json:"tags"`
	} `json:"data"`
	Links struct {
		First string      `json:"first"`
		Last  string      `json:"last"`
		Prev  interface{} `json:"prev"`
		Next  interface{} `json:"next"`
	} `json:"links"`
	Meta struct {
		CurrentPage int `json:"current_page"`
		From        int `json:"from"`
		LastPage    int `json:"last_page"`
		Links       []struct {
			URL    interface{} `json:"url"`
			Label  string      `json:"label"`
			Active bool        `json:"active"`
		} `json:"links"`
		Path    string `json:"path"`
		PerPage int    `json:"per_page"`
		To      int    `json:"to"`
		Total   int    `json:"total"`
	} `json:"meta"`
}
