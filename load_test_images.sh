#!/usr/bin/env bash

set -e
source .env

# cli args
#
# REMOVE being non-empty string indicates that the AWS bucket should
# be cleaned before any new file(s) are uploaded
REMOVE=
# SMALLEST being non-empty string indicates that the script should pull only
# the smallest image from source dir
SMALLEST=
# IMG_SRC_DIR is the dir to search for images
IMG_SRC_DIR="$PWD/images"

# global vars
#
# FILES is the array of full filepaths that will be uploaded to S3
declare -a FILES

function usage ()
{
    printf "usage: %s [-h] [-d IMG_SRC_DIR] [-r] [-s | file1 ... filen]\n

description: Upload jpeg from local system to S3 bucket that shopifyasst can
    pull from.  Ensure that you have a valid .env file to pull configs from.

flags:
    -h: print this help info
    -d: provide directory path to search for images.  Defaults to '$IMG_SRC_DIR'
    -r: remove all existant files, if any exist, from the bucket
    -s: grabs smallest image in searched dir.  Exclusive to file args

positional args:
    file[1...n]: specific filename(s) to upload within searched directory. File
        args must not be copresent with -s flag.  Please make sure to only
        include the basename for the files, not the whole path.

examples:
    Upload all images in $IMG_SRC_DIR
    %s

    Upload smallest image in $IMG_SRC_DIR, cleaning aws bucket beforehand
    %s -r -s

    Upload all images from specified dir
    %s -d /path/to/images

    Upload two specific images from specific dir
    %s -d /path/to/images myimage1.jpg myimage2.jpg
    \n" ${0##*/} ${0##*/} ${0##*/} ${0##*/} ${0##*/} >& 2
}

while getopts ':hrsd:' OPTION
do
    case $OPTION in
        h)
            usage
            exit 0
        ;;
        d)
            IMG_SRC_DIR="$OPTARG"
        ;;
        r)
            REMOVE=TRUE
        ;;
        s)
            SMALLEST=TRUE
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

if ! [ -d "$IMG_SRC_DIR" ]; then
    echo "ERROR: '$IMG_SRC_DIR' does not exist or is not a directory"
    exit 3
fi

if [ -z "$*" ]; then
    IMAGE_SRC="$IMG_SRC_DIR/*.jpg"
    LS_OUTPUT=("$(ls -S --reverse $IMAGE_SRC)")
    echo ls output: "$LS_OUTPUT"
    if [ -n "$SMALLEST" ]; then
        LS_OUTPUT=$(echo "$LS_OUTPUT" | head -n 1)
    fi

    while IFS= read -r FILE; do
        FILES+=("$FILE")
    done <<< "$LS_OUTPUT"
else
    for ARG in "$@"; do
        FILE=$(ls "$IMG_SRC_DIR/$ARG")
        FILES+=("$FILE")
    done
fi

if [ -z "$FILES" ]; then
    echo No Files to upload
    exit 5
fi

echo "${#FILES[@]} file(s) will be uploaded to AWS"
for FILE in "${FILES[@]}"; do
    echo "copying file '$FILE' to AWS"

    if [ -n "$(aws s3 ls $S3_IMAGE_BUCKET)" -a -n "$REMOVE" ]; then
        echo "WARNING: You will delete all files in S3 bucket $S3_IMAGE_BUCKET"
        read -p 'Delete all files in bucket [y/N]: ' DELETE
        DELETE="$(echo "$DELETE" | tr '[:lower:]' '[:upper:]')"
        if [ "$DELETE" != 'Y' ]; then
            echo cannot proceed with non-empty bucket
            exit 6
        fi
        
        aws s3 rm $S3_IMAGE_BUCKET --recursive
    fi

    exiftool -Subject='louisiana, new orleans' "$FILE"
    rm "${FILE}_original" # exiftool creates this

    UUID=$(uuidgen)
    aws s3 cp "$FILE" "$S3_IMAGE_BUCKET/$UUID.jpg"
done

echo exiting successfully...
exit 0