package dda

// UploadConfirmationRequest is the request payload to
// confirm the completion of all parts of the asset upload
type UploadConfirmationRequest struct {
	Partitions []struct {
		Partition int    `json:"PartNumber"`
		ETag      string `json:"ETag"`
	} `json:"parts"`
	UploadID string `json:"upload_id"`
}
