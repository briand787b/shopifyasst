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
source .env

readonly DOWNLOAD_DIR='./images'
readonly MAX_PREVIEW_SIZE=5000000

if [[ "$1" == '--recompile' ]]; then
    echo recompiling go binary...
    cd go
    go build -o ../upload_dda ./cmd/uploader/main.go
    cd ..
fi

UPLOAD_FILES=("$(aws s3 ls $S3_IMAGE_BUCKET --recursive \
    | awk '{$1=$2=$3=""; print substr($0, 4)}' \
    | grep '.jpg$')")
if [ -z "$UPLOAD_FILES" ]; then
    echo 'no files found in s3 bucket, nothing to do...'
    exit 0
fi

echo "upload files: '$UPLOAD_FILES'"

while IFS= read -r UF; do
    FILENAME=$(basename "$UF")
    DOWNLOAD_PATH="${DOWNLOAD_DIR}/original_$FILENAME"
    SHOPIFY_UPLOAD_PATH="${DOWNLOAD_DIR}/$FILENAME"

    echo downloading "$UF"...
    aws s3 cp $S3_IMAGE_BUCKET/$"$UF" "$DOWNLOAD_PATH"

    IMAGE_SIZE=$(ls -l "$DOWNLOAD_PATH" | awk '{print $5}')
    if (( $IMAGE_SIZE >= $MAX_PREVIEW_SIZE )); then
        echo image above Shopify size limit, resizing image...
        convert "$DOWNLOAD_PATH" -resize "${MAX_PREVIEW_SIZE}@" "$SHOPIFY_UPLOAD_PATH"
    else
        cp -l "$DOWNLOAD_PATH" "$SHOPIFY_UPLOAD_PATH"
    fi

    echo extracting tags...
    TAGS=$(exiftool '-Subject' -s -s -s "$DOWNLOAD_PATH")

    if [ -z "$TAGS" ]; then
        echo 'Warning: no tags found in image EXIF data'
    fi
    
    echo "creating shopify product from image $SHOPIFY_UPLOAD_PATH"
    PRODUCT_ID=$(python3 py/upload_shopify.py \
        $TAGS \
        --filename="$SHOPIFY_UPLOAD_PATH" \
        --token="$SHOPIFY_TOKEN" \
        --url="$SHOPIFY_URL")
    
    echo "uploading asset ($DOWNLOAD_PATH) to shopify and linking to product ($PRODUCT_ID)..."
    ./upload_dda \
        -filename="$DOWNLOAD_PATH" \
        -product="$PRODUCT_ID" \
        -token="$DDA_TOKEN"
    
    rm "$DOWNLOAD_PATH" "$SHOPIFY_UPLOAD_PATH"
    aws s3 rm "$S3_IMAGE_BUCKET/$UF"
done <<< "$UPLOAD_FILES"
