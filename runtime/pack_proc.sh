#!/bin/bash

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "$ID" != "debian" && "$ID" != "linuxmint" ]]; then
        echo -e "\e[31mError: Unsupported OS ($PRETTY_NAME). Requires Debian or LMDE.\e[0m" >&2
        exit 1
    fi
else
    echo -e "\e[31mError: /etc/os-release not found.\e[0m" >&2
    exit 1
fi

if [[ $# -eq 0 ]]; then
    exit 0
fi

SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PRELOAD_DEPS="apt-offline gnupg"
TIMESTAMP=""
ARCHIVE_NAME=""
TMP_DIR=""
ARCHIVE_PATH=""
FILE_PATH=""
SYS_NAME=""
SYS_ID=""
SYS_VER_ID=""
SYS_VER_CODENAME=""
SYS_ARCH=""
FILE_NAME=""
FILE_ID=""
FILE_VER_ID=""
FILE_VER_CODENAME=""
FILE_ARCH=""
PKGS=""
TAR_BUNDLE=""
ARCHIVE_DIR=""
UPDATE_ZIP=""
DIGEST_FILE=""
OS_INFO_FILE=""
TMP_EXTRACT=""
TARGET_PKGS=""
BASE_PKGS=""
OUT_DIR=""

function check_sudo() {
    sudo -v || { echo "Error: Authentication failed" >&2; exit 1; }
}

function generate_os_info() {
    echo "NAME=$(grep -E '^NAME=' /etc/os-release | cut -d= -f2- | tr -d '\"')" > "$1"
    echo "ID=$(grep -E '^ID=' /etc/os-release | cut -d= -f2- | tr -d '\"')" >> "$1"
    echo "VERSION_ID=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2- | tr -d '\"')" >> "$1"
    echo "VERSION_CODENAME=$(grep -E '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2- | tr -d '\"')" >> "$1"
    echo "SYSTEM_ARCHITECTURE=$(dpkg --print-architecture)" >> "$1"
}

function verify_os_info() {
    SYS_NAME=$(grep -E '^NAME=' /etc/os-release | cut -d= -f2- | tr -d '\"')
    SYS_ID=$(grep -E '^ID=' /etc/os-release | cut -d= -f2- | tr -d '\"')
    SYS_VER_ID=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2- | tr -d '\"')
    SYS_VER_CODENAME=$(grep -E '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2- | tr -d '\"')
    SYS_ARCH=$(dpkg --print-architecture)
    FILE_NAME=$(grep '^NAME=' "$1" | cut -d= -f2-)
    FILE_ID=$(grep '^ID=' "$1" | cut -d= -f2-)
    FILE_VER_ID=$(grep '^VERSION_ID=' "$1" | cut -d= -f2-)
    FILE_VER_CODENAME=$(grep '^VERSION_CODENAME=' "$1" | cut -d= -f2-)
    FILE_ARCH=$(grep '^SYSTEM_ARCHITECTURE=' "$1" | cut -d= -f2-)
    if [[ "$SYS_NAME" != "$FILE_NAME" || "$SYS_ID" != "$FILE_ID" || "$SYS_VER_ID" != "$FILE_VER_ID" || "$SYS_VER_CODENAME" != "$FILE_VER_CODENAME" || "$SYS_ARCH" != "$FILE_ARCH" ]]; then
        echo "Error: OS info mismatch! System: $SYS_NAME $SYS_ID $SYS_VER_ID $SYS_VER_CODENAME $SYS_ARCH vs Archive: $FILE_NAME $FILE_ID $FILE_VER_ID $FILE_VER_CODENAME $FILE_ARCH" >&2
        exit 1
    fi
}

function generate_hashes() {
    cd "$1" && sha512sum *.deb | awk '{print $2 "," $1}' > "$2" && cd - > /dev/null
}

function verify_hashes() {
    cd "$1" && awk -F',' '{print $2 "  " $1}' "$2" | sha512sum -c - || { echo "Error: Hash mismatch, package corruption detected!" >&2; exit 1; } && cd - > /dev/null
}

function generate_apt_index() {
    echo "Generating APT Packages index..."
    cd "$1" || exit 1
    for deb in *.deb; do
        dpkg-deb -f "$deb" >> Packages
        echo "Filename: $deb" >> Packages
        echo "Size: $(stat -c%s "$deb")" >> Packages
        echo "MD5sum: $(md5sum "$deb" | awk '{print $1}')" >> Packages
        echo "SHA256: $(sha256sum "$deb" | awk '{print $1}')" >> Packages
        echo "" >> Packages
    done
    gzip -9cv Packages > Packages.gz
    rm -v Packages
    cd - > /dev/null
}

function prep_dep_pack() {
    check_sudo
    TIMESTAMP=$(date '+%b%d%Y%p%H%M%S' | tr '[:lower:]' '[:upper:]')
    ARCHIVE_NAME="depsys-preload-$TIMESTAMP.tar.gz"
    TMP_DIR="$PWD/preload_cache"
    mkdir -pv "$TMP_DIR/data" "$TMP_DIR/partial"
    touch "$TMP_DIR/empty-status"
    sudo apt update
    sudo apt -o Dir::State::status="$TMP_DIR/empty-status" -o Dir::Cache::archives="$TMP_DIR" --download-only install -y $PRELOAD_DEPS
    cp -v "$TMP_DIR"/*.deb "$TMP_DIR/data/"
    generate_os_info "$TMP_DIR/os_info.txt"
    generate_hashes "$TMP_DIR/data" "$TMP_DIR/hash_list.txt"
    generate_apt_index "$TMP_DIR/data"
    tar -czvf "$ARCHIVE_NAME" -C "$TMP_DIR" data os_info.txt hash_list.txt
    rm -vrf "$TMP_DIR"
    echo "Preload archive created: $PWD/$ARCHIVE_NAME"
}

function resolve_deps() {
    check_sudo
    ARCHIVE_PATH=$(realpath "$1")
    TMP_DIR="/tmp/depsys_preload_$$"
    mkdir -pv "$TMP_DIR"
    tar -xzvf "$ARCHIVE_PATH" -C "$TMP_DIR"
    verify_os_info "$TMP_DIR/os_info.txt"
    verify_hashes "$TMP_DIR/data" "$TMP_DIR/hash_list.txt"
    [[ -f /etc/apt/sources.list ]] && sudo mv -v /etc/apt/sources.list /etc/apt/sources.list.bak
    [[ -d /etc/apt/sources.list.d ]] && sudo mv -v /etc/apt/sources.list.d /etc/apt/sources.list.d.bak
    sudo mkdir -pv /etc/apt/sources.list.d
    sudo touch /etc/apt/sources.list
    trap 'echo "Restoring APT mirrors..."; sudo rm -vf /etc/apt/sources.list.d/depsys-local.list; [[ -f /etc/apt/sources.list.bak ]] && sudo mv -v /etc/apt/sources.list.bak /etc/apt/sources.list; [[ -d /etc/apt/sources.list.d.bak ]] && sudo rm -vrf /etc/apt/sources.list.d && sudo mv -v /etc/apt/sources.list.d.bak /etc/apt/sources.list.d; sudo rm -vrf "$TMP_DIR"' EXIT
    echo "deb [trusted=yes] file://$TMP_DIR/data ./" | sudo tee /etc/apt/sources.list.d/depsys-local.list > /dev/null
    sudo apt update
    sudo DEBIAN_FRONTEND=noninteractive apt install -y $PRELOAD_DEPS || { echo "Error: Failed to install $PRELOAD_DEPS" >&2; exit 1; }
    echo "Dependencies resolved successfully"
}

function gen_sys_meta_req() {
    check_sudo
    command -v apt-offline >/dev/null 2>&1 || { echo "Error: apt-offline not found." >&2; exit 1; }
    TIMESTAMP=$(date '+%b%d%Y%p%H%M%S' | tr '[:lower:]' '[:upper:]')
    ARCHIVE_NAME="depsys-meta-req-$TIMESTAMP.tar.gz"
    TMP_DIR="$PWD/sys_meta_req"
    mkdir -pv "$TMP_DIR"
    echo "Generating APT list update request..."
    sudo apt-offline set --verbose "$TMP_DIR/update.sig" --update
    generate_os_info "$TMP_DIR/os_info.txt"
    cd "$TMP_DIR" && sha512sum update.sig > digest.txt && cd - > /dev/null
    tar -czvf "$ARCHIVE_NAME" -C "$TMP_DIR" update.sig os_info.txt digest.txt
    rm -vrf "$TMP_DIR"
    echo "Metadata request archive created: $PWD/$ARCHIVE_NAME"
}

function gen_sys_upgrd_req() {
    check_sudo
    command -v apt-offline >/dev/null 2>&1 || { echo "Error: apt-offline not found." >&2; exit 1; }
    TIMESTAMP=$(date '+%b%d%Y%p%H%M%S' | tr '[:lower:]' '[:upper:]')
    ARCHIVE_NAME="depsys-upgrd-req-$TIMESTAMP.tar.gz"
    TMP_DIR="$PWD/sys_upgrd_req"
    mkdir -pv "$TMP_DIR"
    echo "Generating package upgrade request..."
    sudo apt-offline set --verbose "$TMP_DIR/upgrade.sig" --upgrade --upgrade-type dist-upgrade --install-packages linux-image-amd64 linux-headers-amd64
    generate_os_info "$TMP_DIR/os_info.txt"
    cd "$TMP_DIR" && sha512sum upgrade.sig > digest.txt && cd - > /dev/null
    tar -czvf "$ARCHIVE_NAME" -C "$TMP_DIR" upgrade.sig os_info.txt digest.txt
    rm -vrf "$TMP_DIR"
    echo "Upgrade request archive created: $PWD/$ARCHIVE_NAME"
}

function fetch_sys_upgrd_arch() {
    command -v apt-offline >/dev/null 2>&1 || { echo "Error: apt-offline required on host." >&2; exit 1; }
    ARCHIVE_PATH=$(realpath "$1")
    TIMESTAMP=$(date '+%b%d%Y%p%H%M%S' | tr '[:lower:]' '[:upper:]')
    TMP_DIR="$PWD/extracted_reqst"
    OUT_DIR="$PWD/fetched_bundle"
    mkdir -pv "$TMP_DIR" "$OUT_DIR"
    tar -xzvf "$ARCHIVE_PATH" -C "$TMP_DIR"
    cd "$TMP_DIR" && sha512sum -c digest.txt || { echo "Error: Digest mismatch!" >&2; exit 1; } && cd - > /dev/null
    if [[ -f "$TMP_DIR/update.sig" ]]; then
        echo "Fetching APT repository metadata..."
        apt-offline get "$TMP_DIR/update.sig" --bundle "$OUT_DIR/sync.zip" || exit 1
        ARCHIVE_NAME="depsys-meta-bundle-$TIMESTAMP.tar.gz"
    elif [[ -f "$TMP_DIR/upgrade.sig" ]]; then
        echo "Fetching system upgrades and kernel packages..."
        apt-offline get "$TMP_DIR/upgrade.sig" --bundle "$OUT_DIR/sync.zip" || exit 1
        ARCHIVE_NAME="depsys-final-$TIMESTAMP.tar.gz"
    else
        echo "Error: No valid signature found in archive." >&2; exit 1
    fi

    cp -v "$TMP_DIR/os_info.txt" "$OUT_DIR/"
    cd "$OUT_DIR" && sha512sum sync.zip > digest.txt && cd - > /dev/null
    tar -czvf "$ARCHIVE_NAME" -C "$OUT_DIR" sync.zip os_info.txt digest.txt
    rm -vrf "$TMP_DIR" "$OUT_DIR"
    echo "Bundle created successfully: $PWD/$ARCHIVE_NAME"
}

function dgst_sys_upgrd_arch() {
    TAR_BUNDLE="$1"
    ARCHIVE_DIR="$SCRIPT_ROOT/extracted_upgrd"
    if [[ -z "$TAR_BUNDLE" || ! -f "$TAR_BUNDLE" ]]; then
        echo "Error: Bundle archive not provided or not found!" >&2
        exit 1
    fi
    echo "Extracting bundle $TAR_BUNDLE..."
    mkdir -pv "$ARCHIVE_DIR"
    tar -xzvf "$TAR_BUNDLE" -C "$ARCHIVE_DIR"
    SYNC_ZIP="$ARCHIVE_DIR/sync.zip"
    DIGEST_FILE="$ARCHIVE_DIR/digest.txt"
    OS_INFO_FILE="$ARCHIVE_DIR/os_info.txt"
    if [[ ! -f "$SYNC_ZIP" ]]; then
        echo "Error: Sync archive sync.zip not found inside bundle!" >&2
        exit 1
    fi

    if [[ -f "$DIGEST_FILE" ]]; then
        echo "Verifying SHA-512 digest..."
        cd "$ARCHIVE_DIR" || exit 1
        if ! sha512sum -c "$DIGEST_FILE"; then
            echo -e "\e[31mError: Digest verification failed for sync.zip! The file may be corrupted.\e[0m" >&2
            cd "$SCRIPT_ROOT" || exit 1
            sudo rm -vrf "$ARCHIVE_DIR"
            exit 1
        fi
        echo "Digest verified successfully."
        cd "$SCRIPT_ROOT" || exit 1
    fi

    if [[ -f "$OS_INFO_FILE" ]]; then
        echo "--- Target OS Profile ---"
        cat "$OS_INFO_FILE"
        echo "-------------------------"
    fi

    echo "Syncing offline data to APT..."
    sudo apt-offline install "$SYNC_ZIP"
    if unzip -l "$SYNC_ZIP" | grep -q "\.deb$"; then
        echo "Packages detected in bundle. Executing system upgrade..."
        sudo apt dist-upgrade -y --no-download -o Acquire::Retries=0 -o Acquire::http::Timeout=1 -o Acquire::https::Timeout=1 -o Acquire::Allow-Network=false
        sudo apt install -y linux-image-amd64 linux-headers-amd64 --no-download -o Acquire::Retries=0 -o Acquire::http::Timeout=1 -o Acquire::https::Timeout=1 -o Acquire::Allow-Network=false
        if [[ $? -eq 0 ]]; then
            echo -e "\n\e[32mSystem upgrade applied successfully.\e[0m"
        else
            echo -e "\n\e[31mSystem upgrade completed with errors.\e[0m" >&2
            exit 1
        fi
    else
        echo -e "\n\e[32mAPT metadata lists updated successfully. You can now run --gen-sys-upgrd-req to generate the package request.\e[0m"
    fi

    echo "Cleaning up temporary files..."
    sudo rm -vrf "$ARCHIVE_DIR"
}

function gen_pkglist() {
    check_sudo
    FILE_PATH=$(realpath "$1")
    TIMESTAMP=$(date '+%b%d%Y%p%H%M%S' | tr '[:lower:]' '[:upper:]')
    ARCHIVE_NAME="depsys-custpkg-$TIMESTAMP.tar.gz"
    TMP_DIR="$PWD/custpkg_cache"
    mkdir -pv "$TMP_DIR/data" "$TMP_DIR/partial"
    touch "$TMP_DIR/empty-status"
    sudo apt update
    PKGS=$(grep -v '^#' "$FILE_PATH" | tr '\n' ' ')
    echo "$PKGS" > "$TMP_DIR/requested_pkgs.txt"
    BASE_PKGS=$(dpkg-query -W -f='${Package} ${Priority} ${Essential}\n' 2>/dev/null | awk '$2=="required" || $2=="important" || $3=="yes" {print $1}' | tr '\n' ' ')
    sudo apt -o Dir::State::status="$TMP_DIR/empty-status" -o Dir::Cache::archives="$TMP_DIR" --download-only install -y $PKGS $BASE_PKGS
    cp -v "$TMP_DIR"/*.deb "$TMP_DIR/data/"
    generate_os_info "$TMP_DIR/os_info.txt"
    generate_hashes "$TMP_DIR/data" "$TMP_DIR/hash_list.txt"
    generate_apt_index "$TMP_DIR/data"
    tar -czvf "$ARCHIVE_NAME" -C "$TMP_DIR" data os_info.txt hash_list.txt requested_pkgs.txt
    rm -vrf "$TMP_DIR"
    echo "Custom package archive created: $PWD/$ARCHIVE_NAME"
}

function dgst_pkglist() {
    check_sudo
    ARCHIVE_PATH=$(realpath "$1")
    TMP_DIR="/tmp/depsys_custpkg_$$"
    mkdir -pv "$TMP_DIR"
    tar -xzvf "$ARCHIVE_PATH" -C "$TMP_DIR"
    verify_os_info "$TMP_DIR/os_info.txt"
    verify_hashes "$TMP_DIR/data" "$TMP_DIR/hash_list.txt"
    if [[ ! -f "$TMP_DIR/requested_pkgs.txt" ]]; then
        echo "Error: requested_pkgs.txt not found in archive! Please regenerate the archive." >&2
        exit 1
    fi

    TARGET_PKGS=$(cat "$TMP_DIR/requested_pkgs.txt")
    [[ -f /etc/apt/sources.list ]] && sudo mv -v /etc/apt/sources.list /etc/apt/sources.list.bak
    [[ -d /etc/apt/sources.list.d ]] && sudo mv -v /etc/apt/sources.list.d /etc/apt/sources.list.d.bak
    sudo mkdir -pv /etc/apt/sources.list.d
    sudo touch /etc/apt/sources.list
    trap 'echo "Restoring APT mirrors..."; sudo rm -vf /etc/apt/sources.list.d/depsys-local.list; [[ -f /etc/apt/sources.list.bak ]] && sudo mv -v /etc/apt/sources.list.bak /etc/apt/sources.list; [[ -d /etc/apt/sources.list.d.bak ]] && sudo rm -vrf /etc/apt/sources.list.d && sudo mv -v /etc/apt/sources.list.d.bak /etc/apt/sources.list.d; sudo rm -vrf "$TMP_DIR"' EXIT
    echo "deb [trusted=yes] file://$TMP_DIR/data ./" | sudo tee /etc/apt/sources.list.d/depsys-local.list > /dev/null
    sudo apt update
    sudo DEBIAN_FRONTEND=noninteractive apt install -y $TARGET_PKGS || { echo "Error installing packages" >&2; exit 1; }
    echo "Custom packages resolved and installed successfully"
}

function cleanup_env() {
    rm -vrf "$PWD/preload_cache" "$PWD/extracted_preload" "$PWD/sys_upgrd_req" "$PWD/extracted_upgrd" "$PWD/custpkg_cache" "$PWD/extracted_custpkg" "$PWD"/depsys*.tar.gz
    echo "Environment cleanup complete"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prep-dep-pack)
            prep_dep_pack
            exit 0
        ;;
        
        --resolve-deps)
            resolve_deps "$2"
            shift 2
            exit 0
        ;;
        
        --gen-sys-upgrd-req)
            gen_sys_upgrd_req
            exit 0
        ;;

        --gen-sys-meta-req)
            gen_sys_meta_req
            exit 0
        ;;
        
        --fetch-sys-upgrd)
            fetch_sys_upgrd_arch "$2"
            shift 2
            exit 0
        ;;
        
        --dgst-sys-upgrd-arch)
            dgst_sys_upgrd_arch "$2"
            shift 2
            exit 0
        ;;
        
        --gen-pkglist)
            gen_pkglist "$2"
            shift 2
            exit 0
        ;;
        
        --dgst-pkglist)
            dgst_pkglist "$2"
            shift 2
            exit 0
        ;;
        
        --cleanup-env)
            cleanup_env
            exit 0
        ;;
    esac
done
