#!/usr/bin/env bash

set -e

source .env

readonly IMAGE_SRC_DIR='/home/brian/Pictures'
if [ -e $IMAGE_SRC_DIR ]; then
    if [ ! -d $IMAGE_SRC_DIR ]; then
        echo $IMAGE_SRC_DIR exists but is not a directory
        exit 2
    fi
else
    mkdir $IMAGE_SRC_DIR
fi

IMAGE_DST='./images/Small Image V20.jpg'
if [ -n "$1" ]; then
    IMAGE_DST="./images/$1"
fi

# select and modify JPEG file
readonly IMAGE_SRC="$IMAGE_SRC_DIR/*.jpg"
cp "$(ls -S --reverse $IMAGE_SRC | head -n 1)" "$IMAGE_DST"
exiftool -Subject='louisiana, new orleans' "$IMAGE_DST"
rm "${IMAGE_DST}_original" # exiftool creates this

# upload and clean up
if [ -n "$(aws s3 ls $S3_IMAGE_BUCKET)" ]; then
    echo "S3 bucket $S3_IMAGE_BUCKET is not empty"
    read -p 'Delete all files in bucket [y/N]: ' DELETE
    DELETE="$(echo "$DELETE" | tr '[:lower:]' '[:upper:]')"
    if [ "$DELETE" != 'Y' ]; then
        echo cannot proceed with non-empty bucket
        exit 1
    fi
        
    aws s3 rm $S3_IMAGE_BUCKET --recursive
fi
aws s3 cp "$IMAGE_DST" $S3_IMAGE_BUCKET
rm "$IMAGE_DST"
