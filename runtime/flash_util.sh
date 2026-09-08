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

function display_and_select() {
    for ((i=1; i<=DEVICE_COUNT; i++)); do
        eval "DPORT=\$DEV_${i}_PORT"
        eval "DVP=\$DEV_${i}_VID_PID"
        eval "DSER=\$DEV_${i}_ISERIAL"
        printf "Device %d\n" "$i"
        printf "%s\n" "-------------------------------------------------------------"
        printf "Board Name  : %s\n" "$BOARD_NAME"
        printf "FQBN        : %s\n" "$FQBN_VAL"
        printf "HWID        : %s\n" "$DVP"
        printf "Serial ID   : %s\n" "$DSER"
        printf "Device Port : %s\n\n" "$DPORT"
    done
    ATTEMPTS=0
    while [[ $ATTEMPTS -lt 5 ]]; do
        read -r -p "Select device number [1]: " USER_SELECTION
        USER_SELECTION=${USER_SELECTION:-1}
        if [[ "$USER_SELECTION" -ge 1 && "$USER_SELECTION" -le "$DEVICE_COUNT" ]]; then
            eval "SELECTED_PORT=\$DEV_${USER_SELECTION}_PORT"
            eval "VID_PID=\$DEV_${USER_SELECTION}_VID_PID"
            return 0
        else
            printf "Invalid selection. Please try again.\n"
            ATTEMPTS=$((ATTEMPTS + 1))
        fi
    done
    printf "Too many erroneous attempts. Exiting.\n"
    exit 1
}

function verify_hwdb() {
    DIR_PATH="$HWDB/$SYM_FQBN"
    if [[ ! -d "$DIR_PATH" ]]; then
        mkdir -pv "$DIR_PATH"
        lsusb -vd "$VID_PID" 2>/dev/null | grep -E "idVendor|idProduct|iSerial|iManufacturer|iProduct|bcdDevice|bcdUSB|bDeviceClass|bDeviceSubClass|bDeviceProtocol|bMaxPacketSize0|bNumConfigurations" | while read -r line; do
            KEY=$(echo "$line" | awk '{print $1}')
            VAL=$(echo "$line" | awk '{$1=""; sub(/^[[:space:]]+/, ""); print $0}')
            echo "$VAL" > "$DIR_PATH/$KEY.txt"
        done
        echo "$BOARD_NAME" > "$DIR_PATH/descriptor.txt"
    else
        lsusb -vd "$VID_PID" 2>/dev/null | grep -E "idVendor|idProduct|iSerial|iManufacturer|iProduct|bcdDevice|bcdUSB|bDeviceClass|bDeviceSubClass|bDeviceProtocol|bMaxPacketSize0|bNumConfigurations" | while read -r line; do
            KEY=$(echo "$line" | awk '{print $1}')
            VAL=$(echo "$line" | awk '{$1=""; sub(/^[[:space:]]+/, ""); print $0}')
            if [[ -f "$DIR_PATH/$KEY.txt" ]]; then
                if ! grep -F -q -x "$VAL" "$DIR_PATH/$KEY.txt"; then
                    echo "$VAL" >> "$DIR_PATH/$KEY.txt"
                fi
            else
                echo "$VAL" > "$DIR_PATH/$KEY.txt"
            fi
        done
    fi
}


function update_makefile_and_flash() {
    if [[ -n "$SELECTED_PORT" ]]; then
        sed -i "s|^port :=.*|port := $SELECTED_PORT|" "${ROOT_PATH%/}/Makefile"
        PORT="$SELECTED_PORT"
    fi
    FINAL_FQBN="$FQBN_VAL"
    if [[ -n "$ADDITIONAL_OPTIONS_VAL" ]]; then
        FINAL_FQBN="${FQBN_VAL}:${ADDITIONAL_OPTIONS_VAL}"
    fi
    "$BINPATH" --config-file "$CONFIG_FILE" upload --fqbn "$FINAL_FQBN" --port "$PORT" --verbose --input-dir "${ROOT_PATH%/}/firmware"
    if [[ $? -ne 0 ]]; then
        printf "Error occurred during flashing sequence.\n"
        exit 1
    fi
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
        ;;

        --linux-build-conf) 
            LINUX_BUILD_CONF="$2"
            shift 2 
        ;;

        --root-path) 
            ROOT_PATH="$2"
            shift 2 
        ;;

        --src-code) 
            SRC_CODE="$2"
            shift 2 
        ;;

        --approved-hwid-list) 
            APPROVED_HWID_LIST="$2"
            shift 2 
        ;;

        --port) 
            PORT="$2"
            shift 2 
        ;;

        --auto-discovery) 
            AUTO_DISCOVERY="$2"
            shift 2 
        ;;

        --verify-devices) 
            VERIFY_DEVICES="$2"
            shift 2 
        ;;
    esac
done

if [[ "$AUTO_DISCOVERY" == "off" && "$VERIFY_DEVICES" == "on" ]]; then
    printf "Invalid configuration: --auto-discovery off and --verify-devices on is not a valid combination.\n"
    exit 1
fi
