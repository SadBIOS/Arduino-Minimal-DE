#!/bin/bash

if [[ $# -eq 0 ]]; then
  exit 0
fi

sudo -v || {
    printf "\n\e[31mAuthentication failed\e[0m\n" >&2
    exit 1
}
