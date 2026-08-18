#!/bin/bash

if [[ $# -eq 0 ]]; then
    exit 0
fi

SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIB_STORE="$SCRIPT_ROOT/lib_store"
TMP_LIB_STORE="$SCRIPT_ROOT/lib_store/tmp"
BINPATH=""
TOOLCHAIN_ROOT=""
CONFIG_FILE=""
ROOT_PATH=""
SRC_CODE=""
LIB_CATALOG=""
PRELOAD_LIST=""
PRELOAD_CODE=""

declare -a SOURCE_LIBRARIES=()
declare -a CATALOG_LINES=()
declare -a CATALOG_NAMES=()
declare -a MISSING_LIBRARIES=()
declare -a QUEUED_LIBRARIES=()

function print_ok() {
    printf "  [\e[32m OK \e[0m] %s\n" "$1"
}

function print_fail() {
    printf "  [\e[31mFAIL\e[0m] %s\n" "$1"
}

function print_info() {
    printf "  [\e[36mINFO\e[0m] %s\n" "$1"
}

function die() {
    print_fail "$1"
    exit 1
}

function normalize_library_name() {
    value="$1"
    value="${value%$'\r'}"
    value="${value%.h}"
    value="${value//_/ }"
    value="$(printf '%s\n' "$value" | awk '{$1=$1; print}')"
    printf '%s\n' "$value"
}

function generate_preload_code() {
    n="$(shuf -i 6-8 -n 1)" || return 1
    shuf -i "$((10**(n-1)))-$((10**n-1))" -n 1
}

function current_timestamp() {
    date '+%Y%b%-d%-I%-M%S%p' | tr '[:lower:]' '[:upper:]'
}

function create_preload_list() {
    PRELOAD_LIST="$ROOT_PATH/lib_preload_list_linux.txt"
    if [[ -e "$PRELOAD_LIST" ]]; then
        timestamp="$(current_timestamp)" || return 1
        if ! mv -v -- "$PRELOAD_LIST" "$ROOT_PATH/backup_${timestamp}_lib_preload_list_linux.txt"; then
            return 1
        fi
        print_info "Existing preload list backed up as backup_${timestamp}_lib_preload_list_linux.txt"
    fi

    PRELOAD_CODE="$(generate_preload_code)" || return 1
    printf '%s\n' '# This File is Called in Supported Linux Systems Only' '# Please Change the Code Following "==" to Something Different for Each Batch' '# Please Refer to README.md for More Information' ">!< PRE-LOAD-CODE == $PRELOAD_CODE" > "$PRELOAD_LIST"
    print_ok "Created $PRELOAD_LIST"
    print_info "PRE-LOAD-CODE = $PRELOAD_CODE"
}

function load_catalog_into_memory() {
    line_number=0
    CATALOG_LINES=()
    CATALOG_NAMES=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        line_number=$((line_number + 1))
        CATALOG_LINES+=("$line_number")
        CATALOG_NAMES+=("$line")
    done < "$LIB_CATALOG"

    [[ "${#CATALOG_NAMES[@]}" -gt 0 ]]
}

function extract_source_libraries() {
    SOURCE_LIBRARIES=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        if [[ "$line" =~ ^[[:space:]]*\#[[:space:]]*include[[:space:]]*\<([^>]*)\>[[:space:]]*$ ]]; then
            include_name="${BASH_REMATCH[1]}"
            normalized="$(normalize_library_name "$include_name")"
            [[ -z "$normalized" ]] && continue
            already_seen=0
            for existing in "${SOURCE_LIBRARIES[@]}"; do
                if [[ "$existing" == "$normalized" ]]; then
                    already_seen=1
                    break
                fi
            done

            if [[ "$already_seen" -eq 0 ]]; then
                SOURCE_LIBRARIES+=("$normalized")
            fi
        fi
    done < "$SRC_CODE"

    [[ "${#SOURCE_LIBRARIES[@]}" -gt 0 ]]
}

function library_is_installed() {
    output="$("$BINPATH" --config-file "$CONFIG_FILE" lib list "$1" 2>/dev/null)" || return 1
    if printf '%s\n' "$output" |
        awk -v wanted="$1" '
            function trim(s) {
                sub(/^[[:space:]]+/, "", s)
                sub(/[[:space:]]+$/, "", s)
                return s
            }

            NR == 1 {
                next
            }

            {
                line = trim($0)
                if (line == "") {
                    next
                }

                gsub(/\033\[[0-9;]*m/, "", line)
                if (index(line, wanted) == 1) {
                    rest = substr(line, length(wanted) + 1)
                    if (rest == "" || rest ~ /^[[:space:]]/) {
                        found = 1
                    }
                }
            }

            END {
                exit(found ? 0 : 1)
            }
        '
    then
        return 0
    fi

    return 1
}
