# citystock-watermarking-script

## Mains Steps
1. Yarn Install
2. Encode spaces, the script will decode the spaces from the CLI variables

## Cli Example:
> env AWS_ACCESS_KEY=AKIAZT6QL7KCVANBFXSM env AWS_SECRET_ACCESS_KEY=IDpabDe9M981Fpaq0YWlBSfSWt6lNZAgX6PLPgB2 env AWS_REGION=us-east-1 env AWS_BUCKET_NAME=citystock-video-watermarking env SHOTSTACK_BASE_URL=https://api.shotstack.io/stage/ env SHOTSTACK_API_KEY=bfG45Qppjh1fClwRTaemdaUCD5n5L6p33Y6ln6Yi env AWS_OUTPUT_FOLDER_KEY=output env AWS_WATERMARK_FILE_KEY=watermark-citystock.png env AWS_SOURCE_FILE_KEY=input/atlanta__georgia__fly%20over%202.mp4 env FILENAME=Fly%20Over%202 env TAGS=atlanta,georgia env PRICE=10.00 env SHOPIFY_PRODUCT_ID_OUT_PATH=outputProduct.txt node src/index.js
## Variables
- AWS_ACCESS_KEY
- AWS_SECRET_ACCESS_KEY
- AWS_REGION
- AWS_BUCKET_NAME
- SHOTSTACK_BASE_URL
- SHOTSTACK_API_KEY
- AWS_OUTPUT_FOLDER_KEY
- AWS_WATERMARK_FILE_KEY
- AWS_SOURCE_FILE_KEY
- FILENAME
- TAGS
- PRICE
- SHOPIFY_PRODUCT_ID_OUT_PATH