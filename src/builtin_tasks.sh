# This is the very first local task that gets run by N7 to bootstrap remote
# tasks, and environment variables.
#
.N7::init_local() { : LOCAL=1
    # define remote tasks on remote hosts
    local task i=0

    for task in ${N7_TASKS[*]} ${N7_HANDLERS[*]}; do
        if [ "$(N7::get_task_opt $i REMOTE)" ]; then
            N7::local::commands::send_funcs $task
        fi
        i=$((++i))
    done
    # NOTE: implementation-wise, handlers are treated just like a task.
    N7::local::commands::send_env  \
        N7_SUDO=$(N7::q "$N7_SUDO") \
        N7_REMOTE_RUN_DIR=$(N7::q "$N7_REMOTE_RUN_DIR") \
        N7_REMOTE_TMP_DIR=$(N7::q "$N7_REMOTE_TMP_DIR") \
        N7_ANSIBLE_OUT=$(N7::q "$N7_ANSIBLE_OUT")
}

# This is the first remote task run by N7 to setup remote N7 built-ins
#
.N7::init_remote() {
    : REMOTE=1
    : NO_SUBSHELL=1

    # create N7 runtime directories
    mkdir -p "$N7_REMOTE_RUN_DIR" "$N7_REMOTE_TMP_DIR"
}

.N7::define_remote_builtins() {
    : REMOTE=1
    : NO_SUBSHELL=1

#<   remote_builtins.sh 
}



