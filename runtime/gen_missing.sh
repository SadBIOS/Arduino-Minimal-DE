#!/bin/bash

if [[ $# -eq 0 ]]; then
    exit 0
fi

SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIB_STORE="$SCRIPT_ROOT/lib_store"
TMP_LIB_STORE="$SCRIPT_ROOT/lib_store/tmp"
BINPATH=""
TOOLCHAIN_ROOT=""
CONFIG_FILE=""
ROOT_PATH=""
SRC_CODE=""
LIB_CATALOG=""
PRELOAD_LIST=""
PRELOAD_CODE=""

declare -a SOURCE_LIBRARIES=()
declare -a CATALOG_LINES=()
declare -a CATALOG_NAMES=()
declare -a MISSING_LIBRARIES=()
declare -a QUEUED_LIBRARIES=()

function print_ok() {
    printf "  [\e[32m OK \e[0m] %s\n" "$1"
}

function print_fail() {
    printf "  [\e[31mFAIL\e[0m] %s\n" "$1"
}

function print_info() {
    printf "  [\e[36mINFO\e[0m] %s\n" "$1"
}

function die() {
    print_fail "$1"
    exit 1
}

function normalize_library_name() {
    value="$1"
    value="${value%$'\r'}"
    value="${value%.h}"
    value="${value//_/ }"
    value="$(printf '%s\n' "$value" | awk '{$1=$1; print}')"
    printf '%s\n' "$value"
}

function generate_preload_code() {
    n="$(shuf -i 6-8 -n 1)" || return 1
    shuf -i "$((10**(n-1)))-$((10**n-1))" -n 1
}

function current_timestamp() {
    date '+%Y%b%-d%-I%-M%S%p' | tr '[:lower:]' '[:upper:]'
}
