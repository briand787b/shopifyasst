#!/usr/bin/env bash

# *****************************************************************************
# NOTES:
# This script performs the work of creating shopify image products for
# CityStock.  Shopify product creation, along with all dependent steps,
# should be performed upon a simple invocation of this script (no args).
# This script will first list all images in the target S3 bucket.  For 
# every image in that bucket, this script will:
#   1. download the file
#   2. extract the EXIF data
#   3. create a Shopify product using the EXIF data
#   4. upload the image asset to Downloadable Digital Assets for storage
#   5. associate the asset with the Shopify product
#   6. delete the asset from local filesystem and from S3 bucket
#
# Iterative Development Notes:
# This script runs a go binary in the asset upload step for fast execution.  
# This script will only re-compile that binary when a '-recompile' flag is
# passed to it
# *****************************************************************************

set -e

if [[ "$1" == '--recompile' ]]; then
    echo recompiling go binary...
    cd go
    go build -o ../upload_dda ./cmd/uploader/main.go
    cd ..
fi

source .env

UPLOAD_FILES=("$(aws s3 ls $S3_IMAGE_BUCKET | awk '{$1=$2=$3=""; print substr($0, 4)}')")
if [ -z "$UPLOAD_FILES" ]; then
    echo 'no files found in s3 bucket, nothing to do...'
    exit 0
fi

echo "upload files: $UPLOAD_FILES"

for UF in "$UPLOAD_FILES"
do
    UPLOAD_PATH="./images/$UF"

    echo downloading "$UF"...
    aws s3 cp $S3_IMAGE_BUCKET/$"$UF" "$UPLOAD_PATH"

    echo extracting tags...
    TAGS=$(exiftool '-Subject' -s -s -s "$UPLOAD_PATH")

    if [ -z "$TAGS" ]; then
        echo 'Warning: no tags found in image EXIF data'
    fi
    
    echo "creating shopify product..."
    PRODUCT_ID=$(./upload_shopify.py \
        $TAGS \
        --filename="$UPLOAD_PATH" \
        --token="$SHOPIFY_TOKEN" \
        --url="$SHOPIFY_URL")
    
    echo "uploading asset ($UPLOAD_PATH) to shopify and linking to product ($PRODUCT_ID)..."
    ./upload_dda \
        -filename="$UPLOAD_PATH" \
        -product="$PRODUCT_ID" \
        -token="$DDA_TOKEN"
    
    rm "$UPLOAD_PATH"
    aws s3 rm "$S3_IMAGE_BUCKET/$UF"
done