#!/usr/bin/env bash

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

aws s3 ls $S3_VIDEO_BUCKET --recursive \
    | awk '{$1=$2=$3=""; print substr($0, 4)}' \
    | grep '\.mp4$\|\.mov$' \
    | \
while read UF; do
    # echo uf: "$UF"
    ./video_upload.sh "$UF"
done