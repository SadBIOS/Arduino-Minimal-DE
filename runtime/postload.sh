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
ARCHIVE=""
ARCHIVE_IN_STORE=""
PRELOAD_LIST=""
PRELOAD_CODE=""
ARDUINO_USER_DIR=""
LIBRARY_ROOT=""

declare -a REQUESTED_LIBRARIES=()
declare -a LIBRARY_DIRS=()

function print_ok() {
    printf "  [\e[32m OK \e[0m] %s\n" "$1"
}

function print_fail() {
    printf "  [\e[31mFAIL\e[0m] %s\n" "$1"
}

function print_info() {
    printf "  [\e[36mINFO\e[0m] %s\n" "$1"
}

function fail() {
    print_fail "$1"
    exit 1
}

function extract_preload_info() {
    preload_file="$1"
    line=""
    trimmed=""
    PRELOAD_CODE=""
    REQUESTED_LIBRARIES=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        trimmed="${line#"${line%%[![:space:]]*}"}"
        [[ -z "$trimmed" ]] && continue
        [[ "$trimmed" == \#* ]] && continue
        if [[ "$trimmed" =~ ^\>\!\<[[:space:]]PRE-LOAD-CODE[[:space:]]*==[[:space:]]*([0-9]+) ]]; then
            PRELOAD_CODE="${BASH_REMATCH[1]}"
            continue
        fi

        if [[ -n "$PRELOAD_CODE" ]]; then
            REQUESTED_LIBRARIES+=("$trimmed")
        fi

    done < "$preload_file"

    [[ -n "$PRELOAD_CODE" ]] || return 1
    [[ "${#REQUESTED_LIBRARIES[@]}" -gt 0 ]] || return 1
    return 0
}

function find_preload_list() {
    found=""
    found="$(find "$TMP_LIB_STORE" -maxdepth 2 -type f -name 'lib_preload_list_linux.txt' -print -quit 2>/dev/null)"
    [[ -n "$found" ]] || return 1
    PRELOAD_LIST="$found"
    return 0
}

function verify_archive_code() {
    archive_name=""
    archive_code=""
    archive_name="$(basename "$ARCHIVE_IN_STORE")"
    archive_code="${archive_name%.tar.gz}"
    if [[ ! "$archive_code" =~ ^[0-9]+$ ]]; then
        print_fail "Archive name does not contain a numeric preload code: $archive_name"
        return 1
    fi

    if [[ "$archive_code" != "$PRELOAD_CODE" ]]; then
        print_fail "Archive code mismatch"
        printf "          Archive : %s\n" "$archive_code"
        printf "          List    : %s\n" "$PRELOAD_CODE"
        return 1
    fi

    print_ok "Archive code matches PRE-LOAD-CODE == $PRELOAD_CODE"
    return 0
}

function extract_archive() {
    rm -vrf "$TMP_LIB_STORE"/* 2>/dev/null
    mkdir -p "$TMP_LIB_STORE" || return 1
    if ! tar -xzvf "$ARCHIVE_IN_STORE" -C "$TMP_LIB_STORE"; then
        return 1
    fi

    return 0
}

function verify_library_directories() {
    library=""
    expected_dir=""
    actual_dir=""
    failed=0
    LIBRARY_DIRS=()
    printf '%s\n' "Checking libraries:"
    printf '%s\n' "==================================================="
    for library in "${REQUESTED_LIBRARIES[@]}"; do
        expected_dir="${library// /_}"
        actual_dir="$TMP_LIB_STORE/$expected_dir"
        if [[ ! -d "$actual_dir" ]]; then
            print_fail "$library -> $expected_dir/ not found"
            failed=1
            continue
        fi

        if [[ ! -f "$actual_dir/library.properties" ]]; then
            print_fail "$library -> $expected_dir/ found, but library.properties is missing"
            failed=1
            continue
        fi

        LIBRARY_DIRS+=("$actual_dir")
        print_ok "$library -> $expected_dir/"
    
    done

    printf '%s\n' "==================================================="
    if [[ "$failed" -ne 0 ]]; then
        return 1
    fi

    return 0
}

function arduino_user_dir_resolver() {
    line=""
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
    return 0
}

function ask_confirmation() {
    answer=""
    printf '\n'
    printf '%s\n' "The following libraries will be installed:"
    printf '%s\n' "---------------------------------------------------"
    for library_dir in "${LIBRARY_DIRS[@]}"; do
        printf '  %s\n' "$(basename "$library_dir")"
    done

    printf '%s\n' "---------------------------------------------------"
    printf 'Destination: %s\n' "$LIBRARY_ROOT"
    printf '\n'
    while true; do
        read -r -p "Copy these libraries to the Arduino library directory? [y/n]: " answer
        case "$answer" in
            y|Y)
                return 0
            ;;

            n|N)
                return 1
            ;;

        esac
    done
}

function install_libraries() {
    library_dir=""
    library_name=""
    destination=""
    mkdir -p "$LIBRARY_ROOT" || {
        print_fail "Unable to create library directory: $LIBRARY_ROOT"
        return 1
    }
    for library_dir in "${LIBRARY_DIRS[@]}"; do
        library_name="$(basename "$library_dir")"
        destination="$LIBRARY_ROOT/$library_name"
        if [[ -e "$destination" ]]; then
            print_info "Replacing existing library: $library_name"

            if ! rm -vrf "$destination"; then
                print_fail "Unable to remove existing library: $library_name"
                return 1
            fi
        fi

        if cp -va "$library_dir" "$destination"; then
            print_ok "$library_name installed"
        else
            print_fail "$library_name failed to install"
            return 1
        fi

    done

    return 0
}

function prepare_archive() {
    archive_basename=""
    target_archive=""
    mkdir -p "$LIB_STORE" "$TMP_LIB_STORE" || {
        print_fail "Unable to create library store directories"
        return 1
    }
    if [[ ! -f "$ARCHIVE" ]]; then
        print_fail "Archive does not exist: $ARCHIVE"
        return 1
    fi

    archive_basename="$(basename "$ARCHIVE")"
    target_archive="$LIB_STORE/$archive_basename"
    if [[ "$(realpath "$ARCHIVE" 2>/dev/null)" != "$(realpath "$target_archive" 2>/dev/null)" ]]; then
        if [[ -e "$target_archive" ]]; then
            print_info "Replacing existing archive: $target_archive"
            if ! rm -vf "$target_archive"; then
                print_fail "Unable to replace existing archive"
                return 1
            fi

        fi

        if ! cp -v "$ARCHIVE" "$target_archive"; then
            print_fail "Unable to move archive into LIB_STORE"
            return 1
        fi

    fi

    ARCHIVE_IN_STORE="$target_archive"
    print_ok "Archive available at $ARCHIVE_IN_STORE"
    return 0
}

function cleanup() {
    rm -vrf "$TMP_LIB_STORE"/* 2>/dev/null
}

function init_postload_seq() {
    printf '%s\n' "==================================================="
    printf '%s\n' "Starting Offline Library Loader"
    printf '%s\n' "==================================================="
    prepare_archive || exit 1
    print_info "Extracting archive..."
    if ! extract_archive; then
        print_fail "Failed to extract archive"
        exit 1
    fi

    print_ok "Archive extracted"
    if ! find_preload_list; then
        print_fail "lib_preload_list_linux.txt was not found in extracted archive"
        cleanup
        exit 1
    fi

    print_ok "Found $(basename "$PRELOAD_LIST")"
    if ! extract_preload_info "$PRELOAD_LIST"; then
        print_fail "Unable to read preload information"
        exit 1
    fi

    print_ok "PRE-LOAD-CODE == $PRELOAD_CODE"
    print_ok "${#REQUESTED_LIBRARIES[@]} libraries requested"
    if ! verify_archive_code; then
        exit 1
    fi

    if ! verify_library_directories; then
        print_fail "Library verification failed"
        exit 1
    fi

    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_fail "Arduino CLI config file does not exist: $CONFIG_FILE"
        exit 1
    fi

    if ! arduino_user_dir_resolver; then
        print_fail "Unable to resolve Arduino user directory from $CONFIG_FILE"
        exit 1
    fi

    print_ok "Arduino user directory: $ARDUINO_USER_DIR"
    print_ok "Arduino library directory: $LIBRARY_ROOT"

    if ! ask_confirmation; then
        print_info "Installation cancelled"
        cleanup
        exit 0
    fi

    printf '\n'
    printf '%s\n' "Installing libraries..."
    printf '%s\n' "==================================================="
    if ! install_libraries; then
        print_fail "Library installation failed"
        cleanup
        exit 1
    fi

    printf '%s\n' "==================================================="
    print_ok "All libraries installed successfully"
    cleanup
    print_ok "Temporary files cleaned up"
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

        --offl-lib-arch)
            ARCHIVE="$2"
            shift 2
            init_postload_seq
            cleanup
            exit 0
        ;;

    esac
done