
declare -rA N7_LOG_LEVELS=([DEBUG]=-1 [INFO]=0 [WARNING]=1 [ERROR]=2 [FATAL]=3 [QUIET]=99)
declare -i N7_VERBOSE=${N7_LOG_LEVELS[INFO]}

N7::log() {
    local level=${2:-"INFO"}; 
    local -i ilevel=${N7_LOG_LEVELS[$level]?:"Invalid log level: $level"}
    if [[ $ilevel -ge $N7_VERBOSE ]]; then
        printf "%(%Y-%m-%dT%T%z)T|N7|%s|$level|%s\n" -1 "$USER" "$1"
    fi
}
N7::die() { N7::log "$1" ${2:-ERROR} >&2; exit 1; }
N7::debug() { N7::log "$1" DEBUG >&2; }

# NOTE: this can also be used in a (sub-shelled) local task like this:
#       trap 'N7::print_stack_trace' ERR
#
N7::print_stack_trace() {
    echo
    echo "Stack trace: --------"
    local i=0; while caller $((i++)); do :; done
    echo
    echo "Failed command: -->$BASH_COMMANDS<--"
} >&2

N7::is_num() { [[ $1 ]] && printf "%.0f" "$1" >/dev/null 2>&1; }
N7::is_int() { [[ $1 ]] && printf "%d" "$1" >/dev/null 2>&1; }


# A shared data stack, meant for passing small amount of data between function calls only.
#
# To push on to the stack:                DS+=("item1" "item2" ...)
# To pop the last item off the stack:     ${DS[-1]}; ds::pop
# To pop the last $N items off the stack: ${DS[@]:${#DS[@]}-N:N}; ds::pop $N
#
DS=()
ds::pop() {
    local len=${1:-1}
    while ((len--)); do
        unset DS["${#DS[@]} - 1"]
    done
}

