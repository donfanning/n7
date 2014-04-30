# These built-in tasks bootstrap the environment on each remote host by
# defining functions and environment variables.
#

# This is the very first task that gets run by N7 to bootstrap remote
# tasks, and environment variables.
#
.N7::init_remote() { : LOCAL=1; set -e
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
    local task i=0

    for task in ${N7_TASKS[*]} ${N7_HANDLERS[*]}; do
        if [[ $(N7::get_task_opt $i REMOTE) ]]; then
            N7::local::commands::send_funcs $task
        fi
        i=$((++i))
    done
    # NOTE: implementation-wise, handlers are treated just like a task.
}

.N7::define_remote_builtins() {
    : REMOTE=1
    : NO_SUBSHELL=1
    if [[ ! $N7_IS_LOCAL ]]; then
        exec 3>&1 4>&2
        exec >>"$N7_REMOTE_RUN_DIR/$FUNCNAME" 2>&1
    fi

# NOTE: Due to NO_SUBSHELL=1, we can't set -e here because then any error
#       would exit the shell and terminates the ssh session!

# Here we include the remote built-in definitions.
#
# Executing this task will have the effect of defining these
# functions globally on the remote host.
#
#< remote_builtins.sh 

    if [[ ! $N7_IS_LOCAL ]]; then
        exec 1>&3 2>&4
        exec 3>&- 4>&-
    fi
} # >> "$N7_INTERNAL_ERR_FILE" 2>&1


