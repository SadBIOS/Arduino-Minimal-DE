
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
