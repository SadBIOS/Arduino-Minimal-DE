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
    printf "\n\e[34m=== %s ===\e[0m\n" "$1"
}

function system_checker() {}

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
