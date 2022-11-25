#!/usr/bin/env bash

# *****************************************************************************
# NOTES:
# This script is used to upload the tarred, zipped source code to aws s3.  
# This is because there are passwords hardcoded in the source code which will
# eventually need to be removed
# *****************************************************************************

readonly COMPRESSED_ARCHIVE='uploader.tgz'

set -e

source .env

#tar --create --file $COMPRESSED_ARCHIVE -z -v --exclude 'images/*' --exclude $COMPRESSED_ARCHIVE .
go build -o upload_dda ./upload_dda.go
tar --create --file $COMPRESSED_ARCHIVE -z -v main.sh upload_dda upload_shopify.py
aws s3 cp $COMPRESSED_ARCHIVE "$S3_SCRIPT_BUCKET/$COMPRESSED_ARCHIVE"