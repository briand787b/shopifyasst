package asset

// Uploader abstracts the methods required to
type Uploader interface {
	CreateMetaData(i *Asset) error
	UploadParts(i *Asset) error
	ConfirmUpload(i *Asset) error
}
