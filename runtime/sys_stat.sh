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
            system_checker
            exit 0
        ;;
    esac
done
