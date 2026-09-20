#!/bin/bash

if [[ $# -eq 0 ]]; then
    exit 0
fi

sudo -v || {
    printf "\n\e[31mAuthentication failed\e[0m\n" >&2
    exit 1
}

while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

ROOT_PATH=""
TOOLCHAIN_ROOT=""
UDEV_TGT=""
SCRIPT_ROOT=""
RUNTIME=""
PKG_ARCH=""
USER_NAM=""
USR_GRP=""
DEPS=()
MISSING=()
PKG=""
ARD_CORE=""
STAGING_DIR=""
DATASIG_FILE=""
FNAME=""
EXPECTED_HASH=""
CALC_HASH=""
UDEV_FILE=""

function dep_check() {
    SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    RUNTIME="$SCRIPT_ROOT/pack_proc.sh"
    PKG_ARCH="$SCRIPT_ROOT/ard_cli_dependencies.tar.gz"
    DEPS=(build-essential curl tar unzip ca-certificates python3 python3-pip python3-serial libusb-1.0-0 screen util-linux)
    MISSING=()
    for PKG in "${DEPS[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$PKG" 2>/dev/null | grep -q "ok installed"; then
            MISSING+=("$PKG")
        fi
    done
    
    if [ ${#MISSING[@]} -gt 0 ]; then
        echo "Missing packages:"
        printf '%s\n' "${MISSING[@]}"
        if [[ -f "$PKG_ARCH" ]]; then
            "$RUNTIME" --dgst-pkglist "$PKG_ARCH"
        fi
    fi
}

function import_data() {
    dep_check
    USER_NAM="${SUDO_USER:-$USER}"
    USR_GRP="$(id -gn "$USER_NAM")"
    ARD_CORE="${ROOT_PATH%/}/ardCORE.tar"
    if [[ ! -f "$ARD_CORE" ]]; then
        echo "Error: $ARD_CORE is missing." >&2
        exit 1
    fi

    tar -xvf "$ARD_CORE" -C "${ROOT_PATH%/}"
    STAGING_DIR="${ROOT_PATH%/}/staging"
    DATASIG_FILE="$STAGING_DIR/datasig.txt"
    if [[ ! -f "$DATASIG_FILE" ]]; then
        echo "Error: $DATASIG_FILE is missing." >&2
        exit 1
    fi

    while IFS=',' read -r FNAME EXPECTED_HASH; do
        if [[ -n "$FNAME" && -n "$EXPECTED_HASH" ]]; then
            CALC_HASH=$(sha512sum "$STAGING_DIR/$FNAME" | awk '{print $1}')
            if [[ "$CALC_HASH" != "$EXPECTED_HASH" ]]; then
                echo "Error: SHA512 hash mismatch for $FNAME" >&2
                exit 1
            fi
        fi
    done < "$DATASIG_FILE"

    sudo mkdir -pv "$TOOLCHAIN_ROOT"
    sudo chown -vR "$USER_NAM:$USR_GRP" "$TOOLCHAIN_ROOT"
    tar -xvf "$STAGING_DIR/datStor.tar" -C "$TOOLCHAIN_ROOT"
    sudo chown -vR "$USER_NAM:$USR_GRP" "$TOOLCHAIN_ROOT"
    UDEV_FILE=$(grep -v 'datStor.tar' "$DATASIG_FILE" | cut -d',' -f1)
    cat "$STAGING_DIR/$UDEV_FILE" | sudo tee "$UDEV_TGT" >/dev/null
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    if ! id -nG "$USER_NAM" | grep -qw dialout; then
        sudo usermod -aG dialout "$USER_NAM"
    fi

    rm -rvf "$STAGING_DIR"
    echo "Everything has been done successfully."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root-path)
            ROOT_PATH="$2"
            shift 2
        ;;

        --toolchain-root)
            TOOLCHAIN_ROOT="$2"
            shift 2
        ;;

        --udev-tgt)
            UDEV_TGT="$2"
            shift 2
            import_data
            exit 0
        ;;
    esac
done