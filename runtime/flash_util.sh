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

function scan_devices() {
    DEVICE_COUNT=0
    for tty_node in /dev/ttyUSB* /dev/ttyACM*; do
        [[ -e "$tty_node" ]] || continue
        EVAL_PROPS=$(udevadm info --query=property --export --name="$tty_node" 2>/dev/null || true)
        eval "$EVAL_PROPS"
        DEV_VID_PID="${ID_VENDOR_ID}:${ID_MODEL_ID}"
        if grep -q -i "$DEV_VID_PID" "$APPROVED_HWID_LIST"; then
            DEVICE_COUNT=$((DEVICE_COUNT + 1))
            eval "DEV_${DEVICE_COUNT}_PORT=$tty_node"
            eval "DEV_${DEVICE_COUNT}_VID_PID=$DEV_VID_PID"
            eval "DEV_${DEVICE_COUNT}_ISERIAL=${ID_USB_SERIAL_SHORT:-Unknown}"
        fi
    done
}
