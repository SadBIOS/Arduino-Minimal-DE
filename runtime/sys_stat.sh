#!/bin/bash

if [[ $# -eq 0 ]]; then
    exit 0
fi

function print_ok() {
    printf "  [\e[32m OK \e[0m] %s\n" "$1"
}

function print_fail() {
    printf "  [\e[31mFAIL\e[0m] %s\n" "$1"
    ERRORS=$((ERRORS + 1))
}

function print_header() {
    printf "\n\e[34m===== %s =====\e[0m\n" "$1"
}

function system_checker() {
    USR_NAM="${SUP_USER:-$USER}"
    ERRORS=0
    clear
    echo -e "${BOLD}${CYAN}╔═════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║              Arduino Environment Status Report              ║${RESET}"
    echo -e "${BOLD}${CYAN}╚═════════════════════════════════════════════════════════════╝${RESET}"
    print_header "System Dependencies"

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

    for pkg in "${DEPS[@]}"; do
        if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
            print_ok "$pkg"
        else
            print_fail "$pkg is missing"
        fi
        
    done

    print_header "Arduino CLI"
    if [[ -n "$BINPATH" && -x "$BINPATH" ]]; then
        print_ok "Arduino CLI binary exists and is executable ($BINPATH)"
    elif [[ -n "$BINPATH" && -f "$BINPATH" ]]; then
        print_fail "Arduino CLI binary exists but is not executable ($BINPATH)"
    else
        print_fail "Arduino CLI binary missing ($BINPATH)"
    fi

    print_header "Toolchain & Configuration"
    if [[ -n "$TOOLCHAIN_ROOT" && -d "$TOOLCHAIN_ROOT" ]]; then
        print_ok "Toolchain root directory exists ($TOOLCHAIN_ROOT)"
    else
        print_fail "Toolchain root missing ($TOOLCHAIN_ROOT)"
    fi

    if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
        print_ok "Portable configuration exists ($CONFIG_FILE)"
    else
        print_fail "Portable configuration missing ($CONFIG_FILE)"
    fi

    if [[ -d "$TOOLCHAIN_ROOT" ]]; then
        ROOT_OWNER=$(stat -c '%U' "$TOOLCHAIN_ROOT" 2>/dev/null)
        if [[ "$ROOT_OWNER" == "$USR_NAM" ]]; then
            print_ok "Toolchain directory ownership is correct ($USR_NAM)"
        else
            print_fail "Toolchain ownership is $ROOT_OWNER, expected $USR_NAM"
        fi
    fi

    print_header "Installed Arduino-CLI Cores"
    declare -A CORE_PATHS=(
        ["arduino:avr"]="$TOOLCHAIN_ROOT/packages/arduino/hardware/avr"
        ["esp8266:esp8266"]="$TOOLCHAIN_ROOT/packages/esp8266/hardware/esp8266"
        ["esp32:esp32"]="$TOOLCHAIN_ROOT/packages/esp32/hardware/esp32"
        ["Seeeduino:samd"]="$TOOLCHAIN_ROOT/packages/Seeeduino/hardware/samd"
        ["MiniCore:avr"]="$TOOLCHAIN_ROOT/packages/MiniCore/hardware/avr"
    )

    for core in "${!CORE_PATHS[@]}"; do
        path="${CORE_PATHS[$core]}"
        if [[ -d "$path" ]]; then
            version=$(ls -1 "$path" 2>/dev/null | head -n 1)
            if [[ -n "$version" ]]; then
                print_ok "$core (v$version)"
            else
                print_fail "$core (Directory exists, but no version found)"
            fi
        else
            print_fail "$core is missing"
        fi
    done

    print_header "Drivers & Permissions"
    UDEV_TARGET_EXISTS=false
    DIALOUT_MEMBER=false
    if [[ -n "$UDEV_TARGET" && -f "$UDEV_TARGET" ]]; then
        UDEV_TARGET_EXISTS=true
        print_ok "Udev rules deployed ($UDEV_TARGET)"
    else
        print_fail "Udev rules missing ($UDEV_TARGET)"
    fi

    if id -nG "$USR_NAM" 2>/dev/null | grep -qw dialout; then
        DIALOUT_MEMBER=true
        print_ok "User '$USR_NAM' is in the 'dialout' group"
    else
        print_fail "User '$USR_NAM' is NOT in the 'dialout' group"
    fi

    if [[ "$UDEV_TARGET_EXISTS" == true ]]; then
        print_ok "Serial device access is configured through udev"
    elif [[ "$DIALOUT_MEMBER" == true ]]; then
        print_ok "Serial device access is available through the dialout group"
    else
        print_fail "No udev rule and user has no dialout access"
    fi

    print_header "Arduino Library Master Catalog"
    if [[ -n "$LIB_MASTER_CAT" && -f "$LIB_MASTER_CAT" ]]; then
        print_ok "Library catalog exists ($LIB_MASTER_CAT)"
        if [[ -r "$LIB_MASTER_CAT" ]]; then
            SHA256=$(sha256sum "$LIB_MASTER_CAT" 2>/dev/null | awk '{print $1}')
            if [[ -n "$SHA256" ]]; then
                print_ok "SHA-256: $SHA256"
            else
                print_fail "Unable to calculate SHA-256 hash"
            fi

            LIB_COUNT=$(wc -l < "$LIB_MASTER_CAT")
            if [[ "$LIB_COUNT" =~ ^[0-9]+$ ]]; then
                print_ok "Listed Library count: $LIB_COUNT"
            else
                print_fail "Unable to count libraries"
            fi
        else
            print_fail "Library catalog exists but is not readable ($LIB_MASTER_CAT)"
        fi

    elif [[ -n "$LIB_MASTER_CAT" ]]; then
        print_fail "Library catalog missing ($LIB_MASTER_CAT)"
    else
        print_fail "Library catalog path was not provided"
    fi

    echo ""
    if [[ $ERRORS -eq 0 ]]; then
        printf "\e[32m\e[1mAll checks passed! The environment is fully configured.\e[0m\n"
        return 0
    else
        printf "\e[31m\e[1mFound %d error(s). The environment might not be fully functional.\e[0m\n" "$ERRORS"
        return 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --binpath)
            BINPATH="$2"
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

        --udev-tgt)
            UDEV_TARGET="$2"
            shift 2
        ;;
        
        --lib-catalog)
            LIB_MASTER_CAT="$2"
            shift 2
            system_checker
            exit 0
        ;;
        
    esac
done
