#!/usr/bin/env bash

set -e
source .env

# cli args
#
# COUNT is the number of copies to create from each original image
COUNT=1
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
    printf "usage: %s [-h] [-c COUNT] [-d IMG_SRC_DIR] [-r] [-s | file1 ... filen]\n

description: Upload jpeg from local system to S3 bucket that shopifyasst can
    pull from.  Ensure that you have a valid .env file to pull configs from.

flags:
    -h: print this help info
    -c: number of copies to create from each original image
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

    Upload smallest image in $IMG_SRC_DIR 5 times
    %s -s -c 5

    Upload all images from specified dir
    %s -d /path/to/images

    Upload two specific images from specific dir
    %s -d /path/to/images myimage1.jpg myimage2.jpg
    \n" ${0##*/} ${0##*/} ${0##*/} ${0##*/} ${0##*/} >& 2
}

while getopts ':hc:d:rs' OPTION
do
    case $OPTION in
        h)
            usage
            exit 0
        ;;
        c)
            COUNT="$OPTARG"
            re='^[0-9]+$'
            if ! [[ "$COUNT" =~ $re ]] ; then
                printf "ERROR: -c arg '%s' is not a number\n" $COUNT
                exit 1
            fi
        ;;
        d)
            IMG_SRC_DIR="$OPTARG"
            if ! [ -d "$IMG_SRC_DIR" ]; then
                echo "ERROR: '$IMG_SRC_DIR' is not a valid directory"
                exit 3
            fi
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

echo "${#FILES[@]} file(s) will be uploaded to AWS"
for FILE in "${FILES[@]}"; do
    echo "copying file '$FILE' to AWS $COUNT time(s)"
    
    exiftool -Subject='louisiana, new orleans' "$FILE"
    rm "${FILE}_original" # exiftool creates this

    for (( c=1; c<="$COUNT"; c++ )); do
        UUID=$(uuidgen)
        aws s3 cp "$FILE" "$S3_IMAGE_BUCKET/$UUID.jpg"
    done
done

echo exiting successfully...
exit 0