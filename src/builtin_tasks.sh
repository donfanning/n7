# These built-in tasks bootstrap the environment on each remote host by
# defining functions and environment variables.
#

# This is the very first task that gets run by N7 to bootstrap remote
# tasks, and environment variables.
#
.N7::init_remote() {
    : LOCAL=1
    exec >>"$N7_INTERNAL_ERR_FILE" 2>&1

    N7::local::commands::send_env  \
        "N7_SUDO=$N7_SUDO" \
        "N7_REMOTE_RUN_DIR=$N7_REMOTE_RUN_DIR" \
        "N7_REMOTE_TMP_DIR=$N7_REMOTE_TMP_DIR" \
        "N7_ANSIBLE_OUT=$N7_ANSIBLE_OUT"

    # create N7 runtime directories
    N7::local::commands::remote \
        'mkdir -p "$N7_REMOTE_RUN_DIR" "$N7_REMOTE_TMP_DIR"'

    # define remote tasks on remote hosts
    local i task tasks=()
    for task in ${N7_TASKS[*]} ${N7_HANDLERS[*]}; do
        i=${N7_TASK_NAME_2_INDEX[$task]}
        if [[ $(N7::get_task_opt "$i" REMOTE) ]]; then
            tasks+=($task)
        fi
    done
    N7::local::commands::send_funcs ${tasks[*]}
    # NOTE: implementation-wise, handlers are treated just like a task.
}

.N7::define_remote_builtins() {
    : REMOTE=1
    : NO_SUBSHELL=1

# NOTE: Due to NO_SUBSHELL=1, we can't set -e here because then any error
#       would exit the shell and terminates the ssh session!

    local fd1 fd2
    exec {fd1}>&1 {fd2}>&2

    if [[ ! $N7_IS_LOCAL ]]; then
        exec >>"$N7_REMOTE_RUN_DIR/$FUNCNAME" 2>&1
    else
        exec >> "$N7_INTERNAL_ERR_FILE" 2>&1
    fi

# Here we include the remote built-in definitions.
#
# Executing this task will have the effect of defining these
# functions globally on the remote host.
#
#< remote_builtins.sh 

    eval "exec 1>&$fd1 2>&$fd2"
    eval "exec $fd1>&- $fd2>&-"
} 



