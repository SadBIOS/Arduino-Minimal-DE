#!/bin/bash

if [[ $# -eq 0 ]]; then
    exit 0
fi

sudo -v || {
    printf "\n\e[31mAuthentication failed\e[0m\n" >&2
    exit 1
}

while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIB_STORE="$SCRIPT_ROOT/lib_store"
TMP_LIB_STORE="$SCRIPT_ROOT/lib_store/tmp"
DEPENDENCY_ENGINE="$SCRIPT_ROOT/dep.sh"
USER_NAM="${SUDO_USER:-$USER}"
USR_GRP="$(id -gn "$USER_NAM")"
TOOLCHAIN_ROOT=""
RAW_CLI=""
CONFIG_FILE=""
UDEV_SRC=""
UDEV_SYS_TGT=""
LIB_MASTER_CAT=""

function conn_stat() {
    ping -c 1 -W 2 1.1.1.1 &>/dev/null || ping -c 1 -W 2 8.8.8.8 &>/dev/null
}

function run_cli() {
    sudo -u "$USER_NAM" -H "$RAW_CLI" --config-file "$CONFIG_FILE" "$@"
}

function dep_check() {
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

    missing=()
    for pkg in "${DEPS[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
            missing+=("$pkg")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "Missing packages:"
        printf '%s\n' "${missing[@]}"
        echo
        echo "1. Online"
        echo "2. From local archive"

        read -rp "Type the option number only: " option

        case "$option" in
            1) bash "$DEPENDENCY_ENGINE" --resolve-online ;;
            2) bash "$DEPENDENCY_ENGINE" --resolve-offline ;;
        esac
    fi
}

function system_builder() {
    sudo mkdir -p "$TOOLCHAIN_ROOT"
    sudo chown -R "$USER_NAM:$USR_GRP" "$TOOLCHAIN_ROOT"
    mkdir -p "$LIB_STORE" "$TMP_LIB_STORE" 2>/dev/null
    sudo chown -R "$USER_NAM:$USR_GRP" "$LIB_STORE" "$TMP_LIB_STORE"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        sudo -u "$USER_NAM" "$RAW_CLI" config init --config-file "$CONFIG_FILE" >/dev/null 2>&1 || true
    fi

    run_cli config set directories.data "$TOOLCHAIN_ROOT"
    run_cli config set directories.downloads "$TOOLCHAIN_ROOT/staging"
    run_cli config set directories.user "$TOOLCHAIN_ROOT/user"

    BOARD_URLS=(
        "http://arduino.esp8266.com/stable/package_esp8266com_index.json"
        "https://espressif.github.io/arduino-esp32/package_esp32_index.json"
        "https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json"
        "https://mcudude.github.io/MiniCore/package_MCUdude_MiniCore_index.json"
    )

    run_cli config delete board_manager.additional_urls >/dev/null 2>&1 || true
    for url in "${BOARD_URLS[@]}"; do
        run_cli config add board_manager.additional_urls "$url"
    done

    CORES=(
        "arduino:avr"
        "esp8266:esp8266"
        "esp32:esp32"
        "Seeeduino:samd"
        "MiniCore:avr"
    )

    INSTALLED_CORES=$(run_cli core list 2>/dev/null | awk '{print $1}' | tail -n +2 || true)
    MISSING_ANY=false
    for core in "${CORES[@]}"; do
        if ! echo "$INSTALLED_CORES" | grep -qx "$core"; then
            MISSING_ANY=true
            break
        fi
    done

    if [ "$MISSING_ANY" = true ]; then
        run_cli core update-index
        run_cli lib update-index
    fi

    for core in "${CORES[@]}"; do
        if ! echo "$INSTALLED_CORES" | grep -qx "$core"; then
            run_cli core install "$core"
        fi
    done

    sudo chown -R "$USER_NAM:$USR_GRP" "$TOOLCHAIN_ROOT"
}

function driver_resolver() {
    cat "$UDEV_SRC" | sudo tee "$UDEV_SYS_TGT" >/dev/null
    sudo udevadm control --reload-rules
    sudo udevadm trigger
}

function grp_set() {
    current_user="${SUDO_USER:-$USER}"

    if ! id -nG "$current_user" | grep -qw dialout; then
        sudo usermod -aG dialout "$current_user"
    fi
}

function build_lib_cat() {
    if ! conn_stat; then
        if [[ -f "$LIB_MASTER_CAT" ]]; then
            echo "System offline; not modifying $LIB_MASTER_CAT"
        else
            echo "System offline and $LIB_MASTER_CAT does not exist."
            read -r -p "Please create and load $LIB_MASTER_CAT into the work directory, then press Enter to continue: "
        fi
        return 0
    fi

    if [[ -f "$LIB_MASTER_CAT" ]]; then
        while true; do
            read -r -p "$LIB_MASTER_CAT already exists. Overwrite it? [y/n] " answer
            case "$answer" in
                y|Y)
                    break
                ;;
                
                n|N)
                    echo "Not modifying $LIB_MASTER_CAT"
                    return 0
                ;;

            esac
        done
    fi

    run_cli lib search --names | sed -n 's/^Name: "\(.*\)"$/\1/p' | sort -f > "$LIB_MASTER_CAT"
}

function init_build() {
    dep_check
    system_builder
    driver_resolver
    grp_set
    build_lib_cat
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --binpath)
            RAW_CLI="$2"
            shift 2
        ;;
        
        --toolchain-root)
            TOOLCHAIN_ROOT="$2"
            shift 2
        ;;

        --config-file)
            CONFIG_FILE="$2"
            shift 2
        ;;

        --udev-src)
            UDEV_SRC="$2"
            shift 2
        ;;

        --udev-tgt)
            UDEV_SYS_TGT="$2"
            shift 2
        ;;
        
        --lib-catalog)
            LIB_MASTER_CAT="$2"
            shift 2
            init_build
            exit 0
        ;;

    esac
done
