#!/bin/bash

if [[ $# -eq 0 ]]; then
    exit 0
fi

TOOLCHAIN_ROOT=""
CONFIG_FILE=""
BINPATH=""

function board_lister() {}
