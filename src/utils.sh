
declare -rA N7_LOG_LEVELS=([DEBUG]=-1 [INFO]=0 [WARNING]=1 [ERROR]=2 [FATAL]=3 [QUIET]=99)
declare -i N7_VERBOSE=${N7_LOG_LEVELS[INFO]}

N7::log() {
    local level=${2:-"INFO"}; 
    local -i ilevel=${N7_LOG_LEVELS[$level]?:"Invalid log level: $level"}
    if [[ $ilevel -ge $N7_VERBOSE ]]; then
        printf "%(%Y-%m-%dT%T%z)T|N7|$USER|$level|$1\n" -1
    fi
}
N7::die() { N7::log "$1" ${2:-ERROR} >&2; exit 1; }

N7::print_stack_trace() {
    echo
    echo "Stack trace: --------"
    local i=0; while caller $((i++)); do :; done
    echo
    echo "Failed command: -->$BASH_COMMANDS<--"
}

N7::is_num() { [[ $1 ]] && printf "%.0f" "$1" >/dev/null 2>&1; }
N7::is_int() { [[ $1 ]] && printf "%d" "$1" >/dev/null 2>&1; }

