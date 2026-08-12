#!/bin/bash

if [[ $# -eq 0 ]]; then
  exit 0
fi

sudo -v || {
    printf "\n\e[31mAuthentication failed\e[0m\n" >&2
    exit 1
}

SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

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
)

function conn_stat() {
    ping -c 1 -W 2 1.1.1.1 &>/dev/null || ping -c 1 -W 2 8.8.8.8 &>/dev/null
}

function online() {
    if ! conn_stat; then
        echo "Cannot resolve dependencies on an offline machine" >&2
        exit 1
    fi

    sudo apt update && sudo apt install -y "${DEPS[@]}"
}

function makepkg_cache() {
    if conn_stat; then
        read -rp "Machine is online. Force build offline dependency archive? (y/n): " choice
        case "$choice" in
            [yY][eE][sS]|[yY])
                sudo apt clean
                sudo apt update
                cache_dir="$SCRIPT_ROOT/ard_cli_download_cache/partial"
                target_dir="$SCRIPT_ROOT/ard_cli_dependencies"
                mkdir -p "$cache_dir" "$target_dir"
                touch "$SCRIPT_ROOT/ard_cli_download_cache/empty-status"
                sudo apt-get -o Dir::State::status="$SCRIPT_ROOT/ard_cli_download_cache/empty-status" -o Dir::Cache::archives="$SCRIPT_ROOT/ard_cli_download_cache" --download-only install -y "${DEPS[@]}"
                sudo cp -v $SCRIPT_ROOT/ard_cli_download_cache/*.deb "$target_dir/"
                sudo chown -Rv "$USER:$USER" "$target_dir"
                cd "$SCRIPT_ROOT"
                tar -czvf ard_cli_dependencies.tar.gz ard_cli_dependencies
                sudo rm -vrf "$SCRIPT_ROOT/ard_cli_dependencies"
                sudo rm -vrf "$SCRIPT_ROOT/ard_cli_download_cache"
                echo "Offline archive successfully created at: $SCRIPT_ROOT/ard_cli_dependencies.tar.gz"
                exit 0
                ;;
        esac
    else
        echo "Machine is offline. Cannot build dependency archive" >&2
        exit 1
    fi
}

function offline() {
    archive="${1:-$SCRIPT_ROOT/ard_cli_dependencies.tar.gz}"
    if [[ ! -f "$archive" ]]; then
        echo "Archive '$archive' does not exist" >&2
        read -p "Build archive now? (y/n): " optn
        case "$optn" in
            y|Y|yes|YES)
                makepkg_cache
                exit 0
            ;;
            
            n|N|no|NO)
                exit 0
            ;;
        
        esac
    fi

    tar -xzvf "$archive" -C "$SCRIPT_ROOT"

    dirpath="$SCRIPT_ROOT/ard_cli_dependencies"
    if [[ -f /etc/apt/sources.list || -d /etc/apt/sources.list.d ]]; then
        [[ -f /etc/apt/sources.list ]] && sudo mv -v /etc/apt/sources.list /etc/apt/sources.list.bak
        [[ -d /etc/apt/sources.list.d ]] && sudo mv -v /etc/apt/sources.list.d /etc/apt/sources.list.d.bak
        trap '
            echo "Restoring APT mirrors..."
            [[ -f /etc/apt/sources.list.bak ]] && sudo mv -v /etc/apt/sources.list.bak /etc/apt/sources.list
            [[ -d /etc/apt/sources.list.d.bak ]] && sudo mv -v /etc/apt/sources.list.d.bak /etc/apt/sources.list.d
        ' EXIT
    fi

    sudo apt install -y "$dirpath"/*.deb
    rm -vrf "$SCRIPT_ROOT/ard_cli_dependencies"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --resolve-online)
            online
            exit 0
        ;;

        --resolve-offline)
            offline "$2"
            shift 2
            exit 0
        ;;

        --build-offline)
            makepkg_cache
            exit 0
        ;;

    esac
done
