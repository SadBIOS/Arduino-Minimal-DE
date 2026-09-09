
#!/bin/bash

SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HWDB="$SCRIPT_ROOT/hwdb"
BINPATH=""
TOOLCHAIN_ROOT=""
CONFIG_FILE=""
APPROVED_HWID_LIST=""
DB_DIRS=0
DB_ENTRIES=0
FQBN_INPUT=""
BOARD_NAME=""
SYM_FQBN=""
FOUND_VID_PID=""
FOUND_VENDOR=""
FOUND_MODEL=""
FOUND_TTY=""
ATTEMPTS=0
tty_node=""
EVAL_PROPS=""
DEV_VID_PID=""
line=""
DB_OPTION=""
DIR_PATH=""
KEY=""
VAL=""
ATTEMPTS_SUB=0
DB_SUB_OPTION=""
function fqbn_symstrip() {
    printf '%s\n' "${1//[^[:alnum:]]/}"
}
function initialize_db() {
    if [[ ! -d "$HWDB" ]]; then
        mkdir -pv "$HWDB"
    else
        DB_DIRS=$(find "$HWDB" -mindepth 1 -maxdepth 1 -type d | wc -l)
        DB_ENTRIES=$(find "$HWDB" -type f -name "*.txt" -exec wc -l {} + | grep total | awk '{print $1}')
        DB_ENTRIES=${DB_ENTRIES:-0}
        printf "Hardware Database Summary:\n"
        printf "Total FQBNs registered: %s\n" "$DB_DIRS"
        printf "Total entries documented: %s\n\n" "$DB_ENTRIES"
    fi

}
function prompt_fqbn() {
    ATTEMPTS=0
    while [[ $ATTEMPTS -lt 5 ]]; do
        read -r -p "Enter FQBN: " FQBN_INPUT
        BOARD_NAME=$("$BINPATH" --config-file "$CONFIG_FILE" board listall | awk -F '  +' -v fqbn="$FQBN_INPUT" '$2 == fqbn {print $1}')
        if [[ -n "$BOARD_NAME" ]]; then
            SYM_FQBN=$(fqbn_symstrip "$FQBN_INPUT")
            return 0
        else
            printf "Error: FQBN not found in board list. Try again.\n"
            ATTEMPTS=$((ATTEMPTS + 1))
        fi

    done

    printf "Error: Too many attempts with invalid FQBN. Exiting.\n"
    exit 1
}
