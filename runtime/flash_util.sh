#!/bin/bash

SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HWDB="$SCRIPT_ROOT/hwdb"
BINPATH=""
TOOLCHAIN_ROOT=""
CONFIG_FILE=""
LINUX_BUILD_CONF=""
ROOT_PATH=""
SRC_CODE=""
APPROVED_HWID_LIST=""
PORT=""
AUTO_DISCOVERY=""
VERIFY_DEVICES=""
FQBN_VAL=""
ADDITIONAL_OPTIONS_VAL=""
SYM_FQBN=""
DEVICE_COUNT=0
SELECTED_PORT=""
VID_PID=""
BOARD_NAME=""
ISERIAL=""
FINAL_FQBN=""
DIR_PATH=""
NEEDS_PROMPT=0
MATCH_FOUND=0
EVAL_PROPS=""
DEV_VID_PID=""
DPORT=""
DVP=""
DSER=""
ATTEMPTS=0
USER_SELECTION=""
KEY=""
VAL=""
tty_node=""
i=0
line=""

function fqbn_symstrip() {
    printf '%s\n' "${1//[^[:alnum:]]/}"
}

function load_config() {
    FQBN_VAL=$(grep "FQBN ==" "$LINUX_BUILD_CONF" | awk -F ' == ' '{print $2}')
    ADDITIONAL_OPTIONS_VAL=$(grep "ADDITIONAL_OPTIONS ==" "$LINUX_BUILD_CONF" | awk -F ' == ' '{print $2}')
    SYM_FQBN=$(fqbn_symstrip "$FQBN_VAL")
    BOARD_NAME=$("$BINPATH" --config-file "$CONFIG_FILE" board listall | awk -F '  +' -v fq="$FQBN_VAL" '$2 == fq {print $1}')
}
