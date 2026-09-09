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

function monitor_usb() {
    printf "Searching for devices...\n"
    for tty_node in /dev/ttyUSB* /dev/ttyACM*; do
        [[ -e "$tty_node" ]] || continue
        EVAL_PROPS=$(udevadm info --query=property --export --name="$tty_node" 2>/dev/null || true)
        eval "$EVAL_PROPS"
        DEV_VID_PID="${ID_VENDOR_ID}:${ID_MODEL_ID}"
        if grep -q -i "$DEV_VID_PID" "$APPROVED_HWID_LIST"; then
            FOUND_VID_PID="$DEV_VID_PID"
            FOUND_VENDOR="${ID_VENDOR:-Unknown}"
            FOUND_MODEL="${ID_MODEL:-Unknown}"
            FOUND_TTY="$tty_node"
            return 0
        fi

    done

    printf "No known device connected to host. Waiting for device to be plugged in...\n"
    while read -r line; do
        if echo "$line" | grep -q "ACTION=add"; then
            for tty_node in /dev/ttyUSB* /dev/ttyACM*; do
                [[ -e "$tty_node" ]] || continue
                EVAL_PROPS=$(udevadm info --query=property --export --name="$tty_node" 2>/dev/null || true)
                eval "$EVAL_PROPS"
                DEV_VID_PID="${ID_VENDOR_ID}:${ID_MODEL_ID}"
                if grep -q -i "$DEV_VID_PID" "$APPROVED_HWID_LIST"; then
                    FOUND_VID_PID="$DEV_VID_PID"
                    FOUND_VENDOR="${ID_VENDOR:-Unknown}"
                    FOUND_MODEL="${ID_MODEL:-Unknown}"
                    FOUND_TTY="$tty_node"
                    pkill -f "udevadm monitor"
                    break 2
                fi
            done
        fi
    done < <(timeout 60s udevadm monitor --udev --property --subsystem-match=usb)

    if [[ -z "$FOUND_VID_PID" ]]; then
        printf "\nTimeout reached. No device detected.\n"
        exit 1
    fi
}

function process_device() {
    printf "\nThe following device has been discovered:\n"
    printf "Board Name          : %s\n" "$BOARD_NAME"
    printf "FQBN                : %s\n" "$FQBN_INPUT"
    printf "HWID                : %s\n" "$FOUND_VID_PID"
    printf "Device Vendor Name  : %s\n" "$FOUND_VENDOR"
    printf "Device Model        : %s\n\n" "$FOUND_MODEL"
    printf "Choices:\n"
    printf "1. Append to Database and continue to next device\n"
    printf "2. Append and exit\n"
    printf "3. Discard and restart\n"
    printf "4. Discard and exit\n"
    read -r -p "Select option: " DB_OPTION
    DIR_PATH="$HWDB/$SYM_FQBN"
    if [[ "$DB_OPTION" == "1" || "$DB_OPTION" == "2" ]]; then
        if [[ ! -d "$DIR_PATH" ]]; then
            mkdir -pv "$DIR_PATH"
            lsusb -vd "$FOUND_VID_PID" 2>/dev/null | grep -E "idVendor|idProduct|iSerial|iManufacturer|iProduct|bcdDevice|bcdUSB|bDeviceClass|bDeviceSubClass|bDeviceProtocol|bMaxPacketSize0|bNumConfigurations" | while read -r line; do
                KEY=$(echo "$line" | awk '{print $1}')
                VAL=$(echo "$line" | awk '{$1=""; sub(/^[[:space:]]+/, ""); print $0}')
                echo "$VAL" > "$DIR_PATH/$KEY.txt"
            done

            echo "$BOARD_NAME" > "$DIR_PATH/descriptor.txt"
        else
            lsusb -vd "$FOUND_VID_PID" 2>/dev/null | grep -E "idVendor|idProduct|iSerial|iManufacturer|iProduct|bcdDevice|bcdUSB|bDeviceClass|bDeviceSubClass|bDeviceProtocol|bMaxPacketSize0|bNumConfigurations" | while read -r line; do
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
        
        if [[ "$DB_OPTION" == "2" ]]; then
            exit 0
        fi
        
        printf "Device signature added to known hardware database. Waiting for device unplug...\n"
        timeout 60s udevadm monitor --udev --property --subsystem-match=usb | while read -r line; do
            if echo "$line" | grep -q "ACTION=remove"; then
                if ! lsusb -d "$FOUND_VID_PID" >/dev/null 2>&1; then
                    pkill -f "udevadm monitor"
                    break
                fi
            fi

        done

        printf "Successfully disconnected from host.\n"
        printf "1. Keep the existing FQBN\n"
        printf "2. Start with new FQBN\n"
        
        ATTEMPTS_SUB=0
        while [[ $ATTEMPTS_SUB -lt 5 ]]; do
            read -r -p "Select option: " DB_SUB_OPTION
            if [[ "$DB_SUB_OPTION" == "1" ]]; then
                FOUND_VID_PID=""
                monitor_usb
                process_device
                return 0
            elif [[ "$DB_SUB_OPTION" == "2" ]]; then
                FOUND_VID_PID=""
                prompt_fqbn
                monitor_usb
                process_device
                return 0
            else
                printf "Invalid selection.\n"
                ATTEMPTS_SUB=$((ATTEMPTS_SUB + 1))
            fi

        done

        printf "Too many incorrect attempts.\n"
        exit 1
    elif [[ "$DB_OPTION" == "3" ]]; then
        printf "Discarding variables and restarting...\n"
        FOUND_VID_PID=""
        prompt_fqbn
        monitor_usb
        process_device
    elif [[ "$DB_OPTION" == "4" ]]; then
        printf "Discarding variables and exiting...\n"
        exit 0
    else
        printf "Invalid choice.\n"
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

        --approved-hwid-list) 
            APPROVED_HWID_LIST="$2" 
            shift 2 
            initialize_db
            prompt_fqbn
            monitor_usb
            process_device
        ;;
    esac
done