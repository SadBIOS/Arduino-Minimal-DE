#!/bin/bash

if [[ $# -eq 0 ]]; then
  exit 0
fi

sudo -v || {
    printf "\n\e[31mAuthentication failed\e[0m\n" >&2
    exit 1
}

SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

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
