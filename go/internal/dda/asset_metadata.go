package dda

// CreateAssetMetaDataRequest is the request payload to create
// the metadata that represents a digital asset
type CreateAssetMetaDataRequest struct {
	Name string `json:"name"`
	Size int64  `json:"size"`
	Mime string `json:"mime"`
}

// CreateAssetMetaDataResponse is the reponse payload upon
// creation of asset metadata
type CreateAssetMetaDataResponse struct {
	ChunkSize uint64 `json:"chunk_size"`
	UploadID  string `json:"upload_id"`
	Urls      []struct {
		Start uint64 `json:"start"`
		End   uint64 `json:"end"`
		Part  int    `json:"part"`
		URL   string `json:"url"`
	} `json:"urls"`
	ID      string `json:"id"`
	FileURL string `json:"file_url"`
}
