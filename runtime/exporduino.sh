#!/bin/bash

ROOT_PATH=""
SOURCE_PATH=""
UDEV_SRC=""
TMP_DIR=""
STAGING_DIR=""
TAR_HASH=""
UDEV_FILE=""
UDEV_HASH=""

function export_data() {
    TMP_DIR="$ROOT_PATH/TMP"
    mkdir -pv "$TMP_DIR"
    cp -rv "$SOURCE_PATH"/. "$TMP_DIR/"
    tar -cvf "$ROOT_PATH/datStor.tar" -C "$TMP_DIR" .
    STAGING_DIR="$ROOT_PATH/staging"
    mkdir -pv "$STAGING_DIR"
    cp -v "$UDEV_SRC" "$STAGING_DIR/"
    mv -v "$ROOT_PATH/datStor.tar" "$STAGING_DIR/"
    rm -rvf "$TMP_DIR"
    UDEV_FILE=$(basename "$UDEV_SRC")
    cd "$STAGING_DIR" || exit 1
    TAR_HASH=$(sha512sum datStor.tar | awk '{print $1}')
    UDEV_HASH=$(sha512sum "$UDEV_FILE" | awk '{print $1}')
    echo "datStor.tar,$TAR_HASH" > datasig.txt
    echo "$UDEV_FILE,$UDEV_HASH" >> datasig.txt
    cd "$ROOT_PATH" || exit 1
    tar -cvf "$ROOT_PATH/ardCORE.tar" staging
    rm -rvf "$STAGING_DIR"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root-path)
            ROOT_PATH="$2"
            shift 2
        ;;
        
        --source-path)
            SOURCE_PATH="$2"
            shift 2
        ;;
        
        --udev-src)
            UDEV_SRC="$2"
            shift 2
            export_data
            exit 0
        ;;
    esac
done
