#!/bin/bash

if [[ $# -eq 0 ]]; then
    exit 0
fi

SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR=""
FIRMWARE_DIR=""
BINPATH=""
TOOLCHAIN_ROOT=""
CONFIG_FILE=""
SRC_CODE=""
LINUX_BUILD_CONF=""
ROOT_PATH=""
PARSED_FQBN=""
FQBN_OPTIONS=""
FINAL_FQBN=""
CONFIG_LINE=""
CONFIG_KEY=""
CONFIG_VAL=""
COMPILE_STATUS=0
QUERY_FQBN=""
LEV_DIST=""
LEV_FQBN=""
LEV_FULL=""
BOARD_LIST=""
BOARD_FQBN=""
BOARD_MATCH=""
MATCH_COUNT=0
MATCH_INDEX=""
SELECTED_FQBN=""
CHOICE=""

function load_board_list() {
    BOARD_LIST="$("$BINPATH" --config-file "$CONFIG_FILE" board listall 2>/dev/null)"
    if [[ $? -ne 0 || -z "$BOARD_LIST" ]]; then
        printf "[\e[31mFAIL\e[0m] Unable to retrieve boards from '%s --config-file %s board listall'.\n" "$BINPATH" "$CONFIG_FILE"
        exit 1
    fi
}

function show_closest_matches() {
    printf '%s\n' "$BOARD_LIST" | awk -v query="$1" '
        function minimum(a, b, c) {
            if (a <= b && a <= c) return a
            if (b <= a && b <= c) return b
            return c
        }
        function lev(a, b) {
            lev_a = tolower(a)
            lev_b = tolower(b)
            lev_la = length(lev_a)
            lev_lb = length(lev_b)
            delete lev_prev
            delete lev_curr
            for (lev_j = 0; lev_j <= lev_lb; lev_j++) lev_prev[lev_j] = lev_j
            for (lev_i = 1; lev_i <= lev_la; lev_i++) {
                lev_curr[0] = lev_i
                for (lev_j = 1; lev_j <= lev_lb; lev_j++) {
                    lev_cost = (substr(lev_a, lev_i, 1) == substr(lev_b, lev_j, 1)) ? 0 : 1
                    lev_curr[lev_j] = minimum(lev_curr[lev_j - 1] + 1, lev_prev[lev_j] + 1, lev_prev[lev_j - 1] + lev_cost)
                }
                for (lev_j = 0; lev_j <= lev_lb; lev_j++) lev_prev[lev_j] = lev_curr[lev_j]
            }
            return lev_prev[lev_lb]
        }
        NR == 1 { next }
        /^[[:space:]]*$/ { next }
        {
            fqbn_val = $NF
            if (fqbn_val !~ /^[^:]+:[^:]+:[^:]+/) next
            dist = lev(query, fqbn_val)
            printf "%d\t%s\t%s\n", dist, fqbn_val, $0
        }
    ' | sort -n -k1,1 -k2,2 | head -n 5
}

function fqbn_exists() {
    while IFS=$'\t' read -r BOARD_FQBN BOARD_NAME; do
        if [[ "$BOARD_FQBN" == "$PARSED_FQBN" ]]; then
            return 0
        fi
    done < <(printf '%s\n' "$BOARD_LIST" | awk 'NR > 1 && NF >= 2 { print $NF "\t" substr($0, 1, length($0) - length($NF) - 1) }')

    return 1
}

function update_config_fqbn() {
    awk -v new_fqbn="$SELECTED_FQBN" '
        /^[[:space:]]*FQBN[[:space:]]*==/ {
            sub(/==.*/, "== " new_fqbn)
        }
        { print }
    ' "$LINUX_BUILD_CONF" > "${LINUX_BUILD_CONF}.tmp"

    if [[ $? -ne 0 ]]; then
        rm -f "${LINUX_BUILD_CONF}.tmp"
        printf "[\e[31mFAIL\e[0m] Unable to update FQBN in %s.\n" "$LINUX_BUILD_CONF"
        exit 1
    fi

    mv -v "${LINUX_BUILD_CONF}.tmp" "$LINUX_BUILD_CONF"
    if [[ $? -ne 0 ]]; then
        printf "[\e[31mFAIL\e[0m] Unable to replace %s with the updated configuration.\n" "$LINUX_BUILD_CONF"
        exit 1
    fi

    PARSED_FQBN="$SELECTED_FQBN"
    printf "[\e[32m OK \e[0m] Updated FQBN in %s to %s\n" "$LINUX_BUILD_CONF" "$SELECTED_FQBN"
}

function select_closest_match() {
    QUERY_FQBN="$PARSED_FQBN"
    printf "[\e[31mFAIL\e[0m] FQBN '%s' was not found in 'board listall'.\n\n" "$QUERY_FQBN"
    printf "Closest valid FQBN matches:\n\n"
    MATCH_COUNT=0
    while IFS=$'\t' read -r LEV_DIST LEV_FQBN LEV_FULL; do
        [[ -z "$LEV_FQBN" ]] && continue
        MATCH_COUNT=$((MATCH_COUNT + 1))
        printf "  %d) %s\n" "$MATCH_COUNT" "$LEV_FULL"
        printf "     FQBN: %s\n" "$LEV_FQBN"
        printf "     Distance: %s\n\n" "$LEV_DIST"
    done < <(show_closest_matches "$QUERY_FQBN")

    if [[ $MATCH_COUNT -eq 0 ]]; then
        printf "[\e[31mFAIL\e[0m] No valid FQBNs were returned by 'board listall'.\n"
        exit 1
    fi

    while true; do
        printf "Select a board [1-%d], or 0 to abort: " "$MATCH_COUNT"
        read -r CHOICE
        if [[ "$CHOICE" == "0" ]]; then
            printf "[\e[31mFAIL\e[0m] FQBN selection cancelled.\n"
            exit 1
        fi

        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && (( CHOICE >= 1 && CHOICE <= MATCH_COUNT )); then
            MATCH_INDEX=0
            SELECTED_FQBN=""
            while IFS=$'\t' read -r LEV_DIST LEV_FQBN LEV_FULL; do
                [[ -z "$LEV_FQBN" ]] && continue
                MATCH_INDEX=$((MATCH_INDEX + 1))

                if [[ "$MATCH_INDEX" -eq "$CHOICE" ]]; then
                    SELECTED_FQBN="$LEV_FQBN"
                    break
                fi
            done < <(show_closest_matches "$QUERY_FQBN")

            if [[ -n "$SELECTED_FQBN" ]]; then
                update_config_fqbn
                return 0
            fi
        fi

        printf "[\e[31mFAIL\e[0m] Invalid selection. Please choose a number from 1 to %d, or 0 to abort.\n" "$MATCH_COUNT"
    done
}

function map_config_key() {
    case "$1" in
        FQBN)
            printf '%s' "FQBN"
            ;;
        CPU_FREQ)
            printf '%s' "CPUFreq"
            ;;
        CDC_OPTN)
            printf '%s' "CDCOnBoot"
            ;;
        USB_MODE)
            printf '%s' "USBMode"
            ;;
        UPLOAD_MODE)
            printf '%s' "UploadMode"
            ;;
        FLASH_MODE)
            printf '%s' "FlashMode"
            ;;
        FLASH_FREQ)
            printf '%s' "FlashFreq"
            ;;
        FLASH_SIZE)
            printf '%s' "FlashSize"
            ;;
        PSRAM)
            printf '%s' "PSRAM"
            ;;
        PARTITION_SCHEME)
            printf '%s' "PartitionScheme"
            ;;
        ERASE_FLASH)
            printf '%s' "EraseFlash"
            ;;
        MSC_ON_BOOT)
            printf '%s' "MSCOnBoot"
            ;;
        DFU_ON_BOOT)
            printf '%s' "DFUOnBoot"
            ;;
        UPLOAD_SPEED)
            printf '%s' "UploadSpeed"
            ;;
        DEBUG_LEVEL)
            printf '%s' "DebugLevel"
            ;;
        JTAG_ADAPTER)
            printf '%s' "JTAGAdapter"
            ;;
        LOOP_CORE)
            printf '%s' "LoopCore"
            ;;
        EVENTS_CORE)
            printf '%s' "EventsCore"
            ;;
        *)
            return 1
            ;;
    esac
}

function parse_config() {
    PARSED_FQBN=""
    FQBN_OPTIONS=""
    while IFS= read -r CONFIG_LINE || [[ -n "$CONFIG_LINE" ]]; do
        CONFIG_LINE="${CONFIG_LINE%$'\r'}"
        if [[ -z "$CONFIG_LINE" || "$CONFIG_LINE" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        CONFIG_LINE="${CONFIG_LINE%%#*}"
        if [[ "$CONFIG_LINE" =~ ^([^=]+)[[:space:]]*==[[:space:]]*(.*)$ ]]; then
            CONFIG_KEY="${BASH_REMATCH[1]}"
            CONFIG_VAL="${BASH_REMATCH[2]}"
            CONFIG_KEY="$(printf '%s' "$CONFIG_KEY" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            CONFIG_VAL="$(printf '%s' "$CONFIG_VAL" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            if [[ "$CONFIG_KEY" == "FQBN" ]]; then
                PARSED_FQBN="$CONFIG_VAL"
            elif [[ -n "$CONFIG_VAL" ]]; then
                MAPPED_KEY="$(map_config_key "$CONFIG_KEY")"
                if [[ -z "$MAPPED_KEY" ]]; then
                    printf "[\e[33mWARN\e[0m] Unknown configuration key '%s'; ignoring.\n" "$CONFIG_KEY"
                    continue
                fi

                if [[ -n "$FQBN_OPTIONS" ]]; then
                    FQBN_OPTIONS="${FQBN_OPTIONS},${MAPPED_KEY}=${CONFIG_VAL}"
                else
                    FQBN_OPTIONS="${MAPPED_KEY}=${CONFIG_VAL}"
                fi
            fi

        fi
    done < "$LINUX_BUILD_CONF"

    if [[ -z "$PARSED_FQBN" ]]; then
        printf "[\e[31mFAIL\e[0m] FQBN is missing or empty in your config file.\n"
        printf "Provided FQBN: '%s'\n\n" "$PARSED_FQBN"
        printf "The FQBN must exactly match an FQBN returned by:\n"
        printf "%s --config-file %s board listall\n\n" "$BINPATH" "$CONFIG_FILE"
        exit 1
    fi

    if ! fqbn_exists; then
        select_closest_match
    fi

    if [[ -n "$FQBN_OPTIONS" ]]; then
        FINAL_FQBN="${PARSED_FQBN}:${FQBN_OPTIONS}"
    else
        FINAL_FQBN="${PARSED_FQBN}"
    fi
}

function mover() {
    find "$ROOT_PATH" -maxdepth 1 -type f -name "$(basename "${SRC_CODE%.ino}").*" ! -name "$(basename "$SRC_CODE")" -exec mv -v {} "$ROOT_PATH/firmware/" \;
}

function prepare_firmware_dir() {
    if [[ ! -d "$ROOT_PATH/firmware" ]]; then
        mkdir -pv "$ROOT_PATH/firmware"
    elif [[ -n "$(find "$ROOT_PATH/firmware" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        find "$ROOT_PATH/firmware" -mindepth 1 -maxdepth 1 -exec rm -vrf {} +
    fi
}

function build_firmware() {
    printf "Starting build process...\n"
    printf "Final Configured FQBN: %s\n" "$FINAL_FQBN"

    mkdir -pv "$ROOT_PATH"
    mkdir -pv "$TMP_DIR/build"
    mkdir -pv "$TMP_DIR/cache"

    "$BINPATH" --config-file "$CONFIG_FILE" --verbose compile --fqbn "$FINAL_FQBN" --build-path "$TMP_DIR/build" --build-cache-path "$TMP_DIR/cache" --output-dir "$ROOT_PATH" "$SRC_CODE"

    COMPILE_STATUS=$?

    if [[ $COMPILE_STATUS -eq 0 ]]; then
        mover
        printf "[\e[32m OK \e[0m] Compilation successful. Compiled binaries extracted to %s\n" "$ROOT_PATH/firmware"
    else
        printf "[\e[31mFAIL\e[0m] Compilation failed.\n"
    fi

    rm -vrf "$TMP_DIR"

    if [[ $COMPILE_STATUS -ne 0 ]]; then
        exit "$COMPILE_STATUS"
    fi
}

function prep() {
    prepare_firmware_dir
    build_firmware
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

        --src-code)
            SRC_CODE="$2"
            shift 2
        ;;

        --linux-build-conf)
            LINUX_BUILD_CONF="$2"
            shift 2
        ;;

        --root-path)
            ROOT_PATH="$2"
            shift 2
            ROOT_PATH="${ROOT_PATH%/}"
            FIRMWARE_DIR="$ROOT_PATH/firmware"
            TMP_DIR="$ROOT_PATH/TMP"
            load_board_list
            parse_config
            prep
            exit 0
        ;;
    esac
done
