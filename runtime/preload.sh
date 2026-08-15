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
PRELOAD_LIST=""
PRELOAD_CODE=""
PRELOAD_CODE_FOUND=0
ARDUINO_USER_DIR=""
LIBRARY_ROOT=""
ARCHIVE=""
TEMP_ARCHIVE=""

declare -a REQUESTED_LIBRARIES=()
declare -a INSTALLED_DIRS=()

function print_ok() {
    printf "  [\e[32m OK \e[0m] %s\n" "$1"
}

function print_fail() {
    printf "  [\e[31mFAIL\e[0m] %s\n" "$1"
}

function conn_stat() {
    ping -c 1 -W 2 1.1.1.1 &>/dev/null || ping -c 1 -W 2 8.8.8.8 &>/dev/null
}

function preload_code_resolver() {
    PRELOAD_CODE=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        [[ -z "${line//[[:space:]]/}" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        if [[ "$line" =~ ^[[:space:]]*\>\!\<[[:space:]]PRE-LOAD-CODE[[:space:]]*==[[:space:]]*([0-9]+) ]]; then
            PRELOAD_CODE="${BASH_REMATCH[1]}"
            break
        fi
    done < "$PRELOAD_LIST"

    [[ -n "$PRELOAD_CODE" ]]
}

function preload_library_resolver() {
    REQUESTED_LIBRARIES=()
    PRELOAD_CODE_FOUND=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        [[ -z "$line" ]] && continue
        [[ "$line" == \#* ]] && continue

        if [[ "$line" =~ ^\>\!\<[[:space:]]PRE-LOAD-CODE[[:space:]]*==[[:space:]]*([0-9]+) ]]; then
            PRELOAD_CODE_FOUND=1
            continue
        fi

        if [[ "$PRELOAD_CODE_FOUND" -eq 1 ]]; then
            REQUESTED_LIBRARIES+=("$line")
        fi
    done < "$PRELOAD_LIST"

    [[ "${#REQUESTED_LIBRARIES[@]}" -gt 0 ]]
}

function arduino_user_dir_resolver() {
    ARDUINO_USER_DIR=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line#"${line%%[![:space:]]*}"}"
        if [[ "$line" =~ ^user:[[:space:]]*(.*)$ ]]; then
            ARDUINO_USER_DIR="${BASH_REMATCH[1]}"
            ARDUINO_USER_DIR="${ARDUINO_USER_DIR%\"}"
            ARDUINO_USER_DIR="${ARDUINO_USER_DIR#\"}"
            ARDUINO_USER_DIR="${ARDUINO_USER_DIR%\'}"
            ARDUINO_USER_DIR="${ARDUINO_USER_DIR#\'}"
            break
        fi
    done < "$CONFIG_FILE"

    [[ -n "$ARDUINO_USER_DIR" ]] || return 1
    LIBRARY_ROOT="$ARDUINO_USER_DIR/libraries"
    mkdir -p "$LIBRARY_ROOT" 2>/dev/null
}

function find_installed_library_dir() {
    RQST="$1"
    [[ -d "$LIBRARY_ROOT" ]] || return 1
    while IFS= read -r -d '' LIBDIR; do
        if [[ -f "$LIBDIR/library.properties" ]]; then
            LIBNAME="$(awk -F= '/^[[:space:]]*name[[:space:]]*=/ { value=$2; sub(/^[[:space:]]*/, "", value); sub(/[[:space:]]*$/, "", value); print value; exit }' "$LIBDIR/library.properties")"
            if [[ "$LIBNAME" == "$RQST" ]]; then
                printf '%s\n' "$LIBDIR"
                return 0
            fi
        fi
    done < <(find "$LIBRARY_ROOT" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

    return 1
}

function library_resolver() {
    INSTALLED_DIRS=()
    for library in "${REQUESTED_LIBRARIES[@]}"; do
        installed_dir="$(find_installed_library_dir "$library" 2>/dev/null || true)"
        if [[ -n "$installed_dir" ]]; then
            INSTALLED_DIRS+=("$installed_dir")
            print_ok "$library has been loaded"
            continue
        fi

        if ! "$BINPATH" --config-file "$CONFIG_FILE" lib install "$library" >/dev/null 2>&1; then
            print_fail "$library failed to load"
            return 1
        fi

        installed_dir="$(find_installed_library_dir "$library" 2>/dev/null || true)"
        if [[ -z "$installed_dir" ]]; then
            print_fail "$library failed to load"
            return 1
        fi

        INSTALLED_DIRS+=("$installed_dir")
        print_ok "$library has been loaded"
    done
}

function library_archive_builder() {
    rm -rfv "$TMP_LIB_STORE"/* 2>/dev/null
    for installed_dir in "${INSTALLED_DIRS[@]}"; do
        library_dir_name="$(basename "$installed_dir")"
        cp -av "$installed_dir" "$TMP_LIB_STORE/$library_dir_name" >/dev/null 2>&1 || return 1
    done

    cp -av "$PRELOAD_LIST" "$TMP_LIB_STORE/$(basename "$PRELOAD_LIST")" >/dev/null 2>&1 || return 1
    ARCHIVE="$LIB_STORE/${PRELOAD_CODE}.tar.gz"
    TEMP_ARCHIVE="$LIB_STORE/.${PRELOAD_CODE}.tar.gz.tmp"
    rm -fv "$TEMP_ARCHIVE" 2>/dev/null
    if ! tar -C "$TMP_LIB_STORE" -czvf "$TEMP_ARCHIVE" . >/dev/null 2>&1; then
        rm -fv "$TEMP_ARCHIVE" 2>/dev/null
        return 1
    fi

    if ! tar -tzvf "$TEMP_ARCHIVE" >/dev/null 2>&1; then
        rm -fv "$TEMP_ARCHIVE" 2>/dev/null
        return 1
    fi

    if ! mv -fv "$TEMP_ARCHIVE" "$ARCHIVE" 2>/dev/null; then
        rm -fv "$TEMP_ARCHIVE" 2>/dev/null
        return 1
    fi

    printf '%s\n' "Starting Cleanup in 5 Seconds"
    sleep 5
    rm -rfv "$TMP_LIB_STORE"/* 2>/dev/null
    return 0
}

function init_preload_seq() {
    if ! conn_stat; then
        print_fail "Machine is offline"
        exit 1
    fi

    print_ok "Machine is online"
    printf '%s\n' "==================================================="
    mkdir -p "$LIB_STORE" "$TMP_LIB_STORE" 2>/dev/null
    preload_code_resolver
    preload_library_resolver
    arduino_user_dir_resolver
    library_resolver
    library_archive_builder
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
    
        --pre-load-list)
            PRELOAD_LIST="$2"
            shift 2
            init_preload_seq
            exit 0
        ;;

    esac
done
