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
DEPENDENCY_ENGINE="$SCRIPT_ROOT/dep.sh"
UDEV_RULES="$SCRIPT_ROOT/rules.txt"

USER_NAM="${SUDO_USER:-$USER}"
USR_GRP="$(id -gn "$USER_NAM")"
TOOLCHAIN_ROOT=""
RAW_CLI=""
CONFIG_FILE=""
