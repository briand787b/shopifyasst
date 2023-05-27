#!/usr/bin/env bash

set -e
source .env

# # THIS IS NOT THE SAME AS THE MAIN SCRIPT
# # FOR TEST PURPOSES ONLY
# readonly S3_VIDEO_BUCKET="s3://citystock-uploader-test"
# # ---------------------------------------

readonly DOWNLOAD_DIR="$(pwd)/videos"
readonly WATERMARKER='watermarker.png'
readonly SHOPIFY_ID_PATH='shopify_product_id.txt'
readonly WATERMARKER_PATH="$DOWNLOAD_DIR/$WATERMARKER"

function upload()
{
    FILENAME=$(basename "$UF")
    DOWNLOAD_PATH="${DOWNLOAD_DIR}/original_$FILENAME"
    SHOPIFY_UPLOAD_PATH="${DOWNLOAD_DIR}/$FILENAME"

    echo downloading "$UF"...
    aws s3 cp "${S3_VIDEO_BUCKET}/${UF}" "$DOWNLOAD_PATH"

    ffmpeg -i "$DOWNLOAD_PATH" -i "$WATERMARKER_PATH" \
        -v error -nostats -hide_banner -filter_complex \
        "[1]lut=a=val*0.3[a];[0][a]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2" \
        -codec:a copy "$SHOPIFY_UPLOAD_PATH" &> ffmpeg.log
    # cp "$DOWNLOAD_PATH" "$SHOPIFY_UPLOAD_PATH"

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
}

aws s3 cp "$S3_VIDEO_BUCKET/$WATERMARKER" "$WATERMARKER_PATH"

aws s3 ls $S3_VIDEO_BUCKET --recursive \
    | awk '{$1=$2=$3=""; print substr($0, 4)}' \
    | grep '\.mp4$\|\.mov$' \
    | \
while read UF; do
    upload
done