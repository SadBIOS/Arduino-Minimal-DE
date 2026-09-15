#!/bin/bash

if [[ $# -eq 0 ]]; then
    exit 0
fi

sudo -v || {
    printf "\n\e[31mAuthentication failed\e[0m\n" >&2
    exit 1
}

SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME="$SCRIPT_ROOT/pack_proc.sh"
PKGLIST="$SCRIPT_ROOT/pkglist.txt"
PKG_ARCH="$SCRIPT_ROOT/ard_cli_dependencies.tar.gz"

DEPS=(
    build-essential
    curl
    tar
    unzip
    ca-certificates
    python3
    python3-pip
    python3-serial
    libusb-1.0-0
    screen
    util-linux
)


function conn_stat() {
    ping -c 1 -W 2 1.1.1.1 &>/dev/null || ping -c 1 -W 2 8.8.8.8 &>/dev/null
}

function online() {
    if ! conn_stat; then
        echo -e "\033[31mCannot resolve dependencies on an offline machine\033[0m" >&2
        exit 1
    fi

    sudo apt update && sudo apt install -y "${DEPS[@]}"
}

function makepkg_cache() {
    if conn_stat; then
        if [[ -f "$PKGLIST" || -f "$PKG_ARCH" ]]; then
            rm -vrf "$PKGLIST"
            rm -vrf "$PKG_ARCH"
        fi

        printf '%s\n' "${DEPS[@]}" > "$PKGLIST"

        "$RUNTIME" --gen-pkglist "$PKGLIST"
        
        if [[ -f "$PKGLIST" ]]; then
            rm -vrf "$PKGLIST"
        fi

        find $SCRIPT_ROOT -maxdepth 1 -type f -name 'depsys-custpkg-*.tar.gz' -exec mv -v {} "$PKG_ARCH" \;
    fi
}

function offline() {
    if [[ ! -f "$PKG_ARCH" ]]; then
        if ! conn_stat; then
            echo -e "\033[31mNo Dependency archive was found\033[0m" >&2
            echo -e "\033[31mAdditionally the machine is offline thus dependency archive creation is not possible\033[0m" >&2
            exit 1
        else
            makepkg_cache
        fi
    else
        "$RUNTIME" --dgst-pkglist "$PKG_ARCH"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --resolve-online)
            online
            exit 0
        ;;

        --resolve-offline)
            offline
            exit 0
        ;;

        --build-offline)
            makepkg_cache
            exit 0
        ;;
    esac
done
