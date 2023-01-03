#!/usr/bin/env bash

set -e
source .env

# cli args
#
# SMALLEST being non-empty string indicates that the script should pull only
# the smallest image from source dir
SMALLEST=
# FILE_NAMES is the array of file names that should be uploaded to S3
FILE_NAMES=
# IMAGE_SRC_DIR is the dir to search for images
IMAGE_SRC_DIR="$PWD/images"

# global vars
#
# FILES is the array of full filepaths that will be uploaded to S3
declare -a FILES

function usage ()
{
    printf "usage: %s [-h] [-d IMAGE_SRC_DIR] [-s | file1 ... filen]\n

description: Upload jpeg from local system to S3 bucket that shopifyasst can
    pull from.  Ensure that you have a valid .env file to pull configs from.

flags:
    -h: print this help info
    -d: provide directory path to search for images.  Defaults to '$PWD/images'
    -s: grabs smallest image in searched dir.  Exclusive to file args

positional args:
    file[1...n]: specific filename(s) to upload within searched directory. File
        args must not be copresent with -s flag.  Please make sure to only
        include the basename for the files, not the whole path.

examples:
    Upload all images in $PWD/images
    %s

    Upload smallest image in $PWD/images
    %s -s

    Upload all images from specified dir
    %s -d /path/to/images

    Upload two specific images from specific dir
    %s -d /path/to/images myimage1.jpg myimage2.jpg
    \n" ${0##*/} ${0##*/} ${0##*/} ${0##*/} ${0##*/} >& 2
}

while getopts ':hsd:' OPTION
do
    case $OPTION in
        h)
            usage
            exit 0
        ;;
        s)
            SMALLEST=TRUE
        ;;
        d)
            IMAGE_SRC_DIR="$OPTARG"
        ;;
        ?)
            usage
            printf "\nERROR: illegal option: -%s\n" $OPTARG
            exit 1
        ;;
    esac
done
shift $(($OPTIND - 1))

if [ -n "$SMALLEST" -a -n "$*" ]; then
    usage
    printf "\nERROR: cannot specify '-s' flag and file arg(s) simultaneously\n"
    exit 2
fi

if ! [ -d "$IMAGE_SRC_DIR" ]; then
    echo "ERROR: '$IMAGE_SRC_DIR' does not exist or is not a directory"
    exit 3
fi

if [ -z "$*" ]; then
    IMAGE_SRC="$IMAGE_SRC_DIR/*.jpg"
    LS_OUTPUT=("$(ls -S --reverse $IMAGE_SRC)")
    echo ls output: "$LS_OUTPUT"
    if [ -n "$SMALLEST" ]; then
        LS_OUTPUT=$(echo $LS_OUTPUT | head -n 1)
    fi

    while IFS= read -r FILE; do
        echo file: "$FILE"
        FILES+=("$FILE")
    done <<< "$LS_OUTPUT"
else
    echo args: "$@"
    for ARG in "$@"; do
        FILE=$(ls "$IMAGE_SRC_DIR/$ARG")
        echo "file: $FILE"
        FILES+=("$FILE")
    done
fi

if [ -z "$FILES" ]; then
    echo No Files to upload
    exit 5
fi

# declare -a NEW_FILES
for FILE in "${FILES[@]}"; do
    exiftool -Subject='louisiana, new orleans' "$FILE"
    rm "${FILE}_original" # exiftool creates this

    echo copying files to AWS

    # upload and clean up
    if [ -n "$(aws s3 ls $S3_IMAGE_BUCKET)" ]; then
        echo "S3 bucket $S3_IMAGE_BUCKET is not empty"
        read -p 'Delete all files in bucket [y/N]: ' DELETE
        DELETE="$(echo "$DELETE" | tr '[:lower:]' '[:upper:]')"
        if [ "$DELETE" != 'Y' ]; then
            echo cannot proceed with non-empty bucket
            exit 6
        fi
        
        aws s3 rm $S3_IMAGE_BUCKET --recursive
    fi

    UUID=$(uuidgen)
    aws s3 cp "$FILE" "$S3_IMAGE_BUCKET/$UUID"
    rm "$FILE"
done

echo exiting...
exit 0










# if [ -e $IMAGE_SRC_DIR ]; then
#     if [ ! -d $IMAGE_SRC_DIR ]; then
#         echo $IMAGE_SRC_DIR exists but is not a directory
#         exit 2
#     fi
# else
#     mkdir $IMAGE_SRC_DIR
# fi



FILE='./images/Small Image V26.jpg'
if [ -n "$1" ]; then
    FILE="./images/$1"
fi

# select and modify JPEG file
readonly IMAGE_SRC="$IMAGE_SRC_DIR/*.jpg"
cp "$(ls -S --reverse $IMAGE_SRC | head -n 1)" "$FILE"
exiftool -Subject='louisiana, new orleans' "$FILE"
rm "${FILE}_original" # exiftool creates this

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
aws s3 cp "$FILE" $S3_IMAGE_BUCKET
rm "$FILE"
