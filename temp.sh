#!/usr/bin/env bash

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

aws s3 cp "$S3_VIDEO_BUCKET/$WATERMARKER" "$WATERMARKER_PATH"

aws s3 ls $S3_VIDEO_BUCKET --recursive \
    | awk '{$1=$2=$3=""; print substr($0, 4)}' \
    | grep '\.mp4$\|\.mov$' \
    | \
while read UF; do
    echo uf: "$UF"
done