#!/bin/bash

if [[ $# -eq 0 ]]; then
    exit 0
fi

TOOLCHAIN_ROOT=""
CONFIG_FILE=""
BINPATH=""

function board_lister() {
    BOLD="\033[1m"
    DIM="\033[2m"
    CYAN="\033[36m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    RESET="\033[0m"

    clear

    echo
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║              Installed Arduino Boards              ║${RESET}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
    echo

    TMPFILE=$(mktemp)
    trap 'rm -f "$TMPFILE"' EXIT

    "$BINPATH" --config-file "$CONFIG_FILE" board listall 2>/dev/null | \
    awk '
    NR==1 { next }{}
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
            board_lister
            exit 0
        ;;

    esac
done
