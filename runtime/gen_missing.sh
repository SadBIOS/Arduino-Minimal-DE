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
