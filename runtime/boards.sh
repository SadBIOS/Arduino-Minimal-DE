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
    NR==1 { next }{
        fqbn=$NF

        if (fqbn !~ /:/)
            next

        name=substr($0,1,length($0)-length($NF))
        sub(/[[:space:]]+$/,"",name)

        split(fqbn,p,":")

        package=p[1]
        arch=p[2]

        if(package=="esp32")
            family="ESP32 Family"
        else if(package=="esp8266")
            family="ESP8266 Family"
        else if(package=="arduino" && arch=="avr")
            family="Arduino AVR Family"
        else
            next

        if(family=="ESP32 Family") {
            str = tolower(name " " fqbn)
            gsub(/plus2/, "plus 2", str)
            if(str ~ /esp32-?p4/ || str ~ /p4[^a-z0-9]/ || str ~ /p4$/)
                series="P Series"
            else if(str ~ /esp32-?c[2356]/ || str ~ /c[2356][^a-z0-9]/ || str ~ /c[2356]$/)
                series="C Series"
            else if(str ~ /esp32-?s[23]/ || str ~ /s[23][^a-z0-9]/ || str ~ /s[23]$/)
                series="S Series"
            else if(str ~ /esp32-?h2/ || str ~ /h2[^a-z0-9]/ || str ~ /h2$/)
                series="H Series"
            else
                series="Basic"
        }
        else {
            series="Basic"
        }

        key=family "|" series
        count[key]++

        if(count[key] > 1)
            boards[key]=boards[key]"###"

        boards[key]=boards[key]name" | "fqbn
    }

    END {
        order[1]="ESP32 Family|Basic"
        order[2]="ESP32 Family|S Series"
        order[3]="ESP32 Family|C Series"
        order[4]="ESP32 Family|H Series"
        order[5]="ESP32 Family|P Series"
        order[6]="ESP8266 Family|Basic"
        order[7]="Arduino AVR Family|Basic"

        for(i=1;i<=7;i++) {
            key=order[i]
            if(count[key])
                print key "\t" count[key] "\t" boards[key]
        }
    }
    ' > "$TMPFILE"

    CURRENT_FAMILY=""

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
