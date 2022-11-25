package asset

// Uploader abstracts the methods required to
type Uploader interface {
	CreateMetaData(i *Image) error
	UploadParts(i *Image) error
	ConfirmUpload(i *Image) error
}
