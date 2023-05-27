#!/usr/bin/env bash

# *****************************************************************************
# NOTES:
# This script performs the work of creating shopify video products for
# CityStock.  Shopify product creation, along with all dependent steps,
# should be performed upon a simple invocation of this script (no args).
# This script will first list all videos in the target S3 bucket.  For 
# every video in that bucket, this script will:
#   1. download the file
#   2. watermark video
#   3. extract the EXIF data
#   4. create a Shopify product using the EXIF data
#   5. upload the video asset to Downloadable Digital Assets for storage
#   6. associate the asset with the Shopify product
#   7. delete the asset from local filesystem and from S3 bucket
#
# Iterative Development Notes:
# This script runs a go binary in the asset upload step for fast execution.  
# This script will only re-compile that binary when a '-recompile' flag is
# passed to it
# *****************************************************************************

set -e
source .env

readonly DOWNLOAD_DIR="$(pwd)/videos"
readonly WATERMARKER='watermarker.png'
readonly SHOPIFY_ID_PATH='shopify_product_id.txt'
readonly WATERMARKER_PATH="$DOWNLOAD_DIR/$WATERMARKER"

if [[ "$1" == '--recompile' ]]; then
    echo recompiling go binary...
    cd go
    go build -o ../upload_dda ./cmd/uploader/main.go
    cd ..
fi

aws s3 cp "$S3_VIDEO_BUCKET/$WATERMARKER" "$WATERMARKER_PATH"

UPLOAD_FILES=("$(aws s3 ls $S3_VIDEO_BUCKET --recursive \
    | awk '{$1=$2=$3=""; print substr($0, 4)}' \
    | grep '\.mp4$\|\.mov$')")
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
    aws s3 cp "${S3_VIDEO_BUCKET}/${UF}" "$DOWNLOAD_PATH"

    ffmpeg -i "$DOWNLOAD_PATH" -i "$WATERMARKER_PATH" \
        -filter_complex \
        "[1]lut=a=val*0.3[a];[0][a]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2" \
        -codec:a copy "$SHOPIFY_UPLOAD_PATH"

    echo extracting tags...
    TAGS=$(exiftool '-Subject' -s -s -s "$DOWNLOAD_PATH")
    : "${TAGS:=video}"

    if [ -z "$TAGS" ]; then
        echo 'Warning: no tags found in video EXIF data'
    fi
    
    cd node
    SHOPIFY_PRODUCT_ID_OUT_PATH="$SHOPIFY_ID_PATH" \
        TAGS="$TAGS" \
        SHOPIFY_TOKEN="$SHOPIFY_TOKEN" \
        FILENAME="$SHOPIFY_UPLOAD_PATH" \
        node src/index.js
    cd ..
    
    echo "uploading asset ($DOWNLOAD_PATH) to shopify and linking to product ($PRODUCT_ID)..."
    ./upload_dda \
        -filename="$DOWNLOAD_PATH" \
        -product="$(cat node/$SHOPIFY_ID_PATH)" \
        -token="$DDA_TOKEN"
    
    rm "$DOWNLOAD_PATH" "$SHOPIFY_UPLOAD_PATH" "node/$SHOPIFY_ID_PATH"
    aws s3 rm "$S3_VIDEO_BUCKET/$UF"
done <<< "$UPLOAD_FILES"
