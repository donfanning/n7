# To help debugging, put this line where you want to start stepping through the commands.
#
# trap '(read -p "[$BASH_SOURCE:$LINENO] $BASH_COMMAND?")' DEBUG
#

N7::cleanup() {
    local last_rc=$?

    # Restore STDOUT and STDERR
    exec 1>&$N7_STDOUT 2>&$N7_STDERR

    # Dump stack trace if cleaning up because of an error
    if [[ $last_rc -ne 0 ]]; then
        set +x; N7::print_stack_trace
    fi

    set +e +E

    # Close FDs that's keeping the ssh pipes open
    local fd 
    for fd in ${N7_SSH_PIPE_FDs[*]}; do
        eval "exec $fd>&-"
    done

    # Show errors if any
    if [[ -s $N7_INTERNAL_ERR_FILE ]]; then
        N7::log "Errors found during initialization or cleanup: --------
$(<"$N7_INTERNAL_ERR_FILE")" ERROR
    fi

    # This is to keep bash from reporting to stderr that each of the child
    # process that invokes ssh has been killed.
    exec 2>/dev/null

    # Kill each of the whole process groups that's reading the ssh pipes.
    local pid_pgid pids=$(ps x -opid,pgid | awk 'NR==1 {next}; {printf("%d,%d\n", $1, $2)}')
    for pid_pgid in $pids; do
        if [[ " ${N7_SSH_PPIDs[*]} " =~ " ${pid_pgid%,*} " ]]; then
            kill -TERM -- -${pid_pgid#*,}
        fi
    done

    # Remove the n7 run dir if not keeping it
    if [[ ! $N7_KEEP_RUN_DIR ]]; then
        rm -rf "$N7_RUN_DIR"
    fi

    exit $last_rc
}

N7::ssh_read_pipe() { echo "$N7_RUN_DIR/$1.pipe_r"; }
N7::ssh_out_file() { echo "$N7_RUN_DIR/$1.out"; }
N7::ssh_err_file() { echo "$N7_RUN_DIR/$1.err"; }
N7::ssh_host_from_out_file() { echo $(basename "${1%.out}"); }
N7::send_cmd() { printf "%s\n" "$1" >"$(N7::ssh_read_pipe ${2:?'Empty host!'})" || true; }

N7::send_eot_line() {
    # the line is: <eot_hash> <hostname> <task_index|-1> <exit_status|$?> <changed|->
    local line="
        $N7_EOT
        $1
        ${N7_TASK_IDX:-"-1"}
        ${2:-\$N7_RC}
        \$(N7::remote::tasks::changed 2>/dev/null && echo changed || echo -)
    "
    line=$(echo $line)
    N7::send_cmd "N7_RC=\$?; (echo; echo $line) | tee /dev/stderr" ${1:?'Empty host!'}
    #
    # NOTE: we always output a newline before sending the EOT line so
    #       that the EOT line will always be on its own line.
}

N7::ssh_ehosts() {
    if [[ -r $N7_EHOSTS_FILE ]]; then
        N7_EHOSTS=$(<"$N7_EHOSTS_FILE") 2>/dev/null
        rm -f "$N7_EHOSTS_FILE"
    fi
    echo $N7_EHOSTS
}


# Output a list of function names matching a specific pattern in the order
# they are defined in $N7_SCRIPT.
#
N7::_get_func_names() {
    shopt -s extdebug
    for f in $(declare -f | grep -- "$1" | cut -d' ' -f1); do
        line=$(declare -F $f)
        p=${line#* }; p=${p#* }
        if [[ $p = ${2:-"$N7_SCRIPT"} ]]; then
            if [[ $line =~ ^\.N7::cli_task:: ]]; then
                # Special handling for cli tasks that were generated at runtime.
                # This ensures that cli_tasks will be after any built-in tasks.
                fname=${line%% *}
                printf "%s %s\n" $fname $(( $N7_PROG_LINE_COUNT + ${fname##*:} ))
            else
                printf "%s\n" "$line"
            fi
        fi
    done | sort -nk2 | cut -d' ' -f1
    shopt -u extdebug
}


# N7::load_tasks
#
# Load up N7_TASKS with task names in the order they are defined in N7_SCRIPT.
#
# The task indexes are layed out in this order(just an example):
#
#    0    1    2    3    4    5    6    7    8    9   10   11   12  13...
#    <built-in task names...> <user-defined task names...> <handler names...>
#    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ^^^^^^^^^^^^^^^^^^
#                 \________ defined in N7_TASKS                \___ defined in N7_HANDLERS
#
#
# Thus, the first built-in task will have task index 0, and the handlers,
# which are not part of N7_TASKS, will have the first task index starting
# from ${#N7_TASKS[*]}
#
N7::load_tasks() {
    # If command line commands are provided then wrap the commands
    # in N7 tasks.
    if [[ ! $N7_SCRIPT ]]; then
        local i=0 cmd
        for cmd in "${N7_CLI_ARGS[@]}"; do
            eval "
            .N7::cli_task::$i() {
                : REMOTE=1
                $cmd
            } $(if [[ ! $N7_CLI_TASK_NO_REDIRECTION ]]; then echo "2>&1"; fi)
            "
            let ++i
        done
    fi
    # Add built-in tasks and cmdline tasks
    N7_TASKS+=($(N7::_get_func_names '^\.' "$N7_PROG_NAME"))

    # Add tasks from $N7_SCRIPT
    N7_TASKS+=($(N7::_get_func_names '^\.'))

    # Handlers are not part of $N7_TASKS, they will only be run
    # when called or notified.
    N7_HANDLERS+=($(N7::_get_func_names '^:'))

    # Create the reverse, task name -> task index map.
    local task i=0
    for task in ${N7_TASKS[*]} ${N7_HANDLERS[*]}; do
        N7_TASK_NAME_2_INDEX[$task]=$((i++))
    done

    N7::load_task_opts ${N7_TASKS[*]} ${N7_HANDLERS[*]}
}

# N7::parse_task_opts <task_defn>
#
# Take a function definition, parse all leading null commands(:) of the form:
#
#     ': name1=value1'
#     ': name2=value2'
# 
# until the first non-null command, which marks the end of the task option section.
#
# Output the right hand side of an associative array assignment of this form:
#
#     '(
#      [name1]=value1
#      [name2]=value2
#        ...
#      )'
#
N7::parse_task_opts() {
    local section=$(awk '/^ *: /, $0 ~ "^ *[^#]" && $0 !~ "^ *: " {print}' <<<"$(declare -f $1)")
    echo "("
    echo "$section" | sed '$d
      s/^ *:  *//g 
      s/\([^ ]\)/\[\1/ 
      s/=/\]=/
      s/;$//
    '
    echo ")"
}

# Usage: N7::get_task_opt <task_idx> <opt_name>
N7::get_task_opt() {
    local task_opt="N7_TASK_OPTS_$1[$2]"
    printf "%s\n" "${!task_opt}"  
}

# N7::load_task_opts <all task definitions...>
#
# Dynamically assign a global array variable, N7_TASK_OPTS_{n}.
#
# So as an example, for the first task(task 0) you have N7_TASK_OPTS_0.
# The options in such array can be obtained via the `N7::get_task_opt' function.
#
N7::load_task_opts() {
    local task_idx=-1 task task_opts name val
    while (( $# > 0 )); do
        name=N7_TASK_OPTS_$((++task_idx))
        task=$1; shift
        task_opts=$(N7::parse_task_opts "$task")

        declare -gA "$name=$task_opts"

        # check if each option name is valid by removing all known option
        # names from an array of user specified option names.
        val=($(eval echo '${!'$name'[*]}'))
        for name in ${N7_TASK_OPT_NAMES[*]}; do # 
            val=(${val[*]/#$name})
        done

        # if there's still any options left over then it's an unknown option.
        if [[ $(printf %s "${val[*]}") ]]; then
            N7::die "Invalid task options(${val[*]}) in task #$task_idx"
        fi
        
        # validate the TIMEOUT value
        val=$(N7::get_task_opt $task_idx TIMEOUT)
        [[ ! $val || $val -gt 0 ]] || N7::die "Invalid timeout(\`$val') for task #$task_idx!"

        # set NAME to function name if it's not specified.
        if [[ ! $(eval echo \${N7_TASK_OPTS_$task_idx[NAME]}) ]]; then
            declare -g "N7_TASK_OPTS_$task_idx[NAME]=$task"
        fi

        # deal with LOCAL and REMOTE
        local localremote=$(echo "$task_opts" | grep -P '^\[LOCAL|REMOTE\]=' | tail -n1)
        val=N7_TASK_OPTS_$task_idx
        if [[ ! $localremote ]]; then
            declare -g "$val[$N7_DEFAULT_TASK_TYPE]=1"
        elif [[ $localremote  == \[LOCAL\]=* ]]; then
            unset $val[REMOTE]
        elif [[ $localremote  == \[REMOTE\]=* ]]; then
            unset $val[LOCAL]
        fi
    done
}


# N7::wait_for_tasks_on_hosts <task_idx> [host1 host2 ...]
#
# Periodically look at the last line of each host out-file, expecting the EOT marker.
#
# If the EOT line is found at the end within task timeout, then it means the last
# task has finished. Otherwise, the task has been timed out.
#
# Output the EOT lines. For timed out hosts, the rc field of the EOT line will be
# set to $N7_ERRNO_TIMEOUT.
#
N7::wait_for_task_on_hosts() {
    local task_idx=$1; shift
    local timeout=$(N7::get_task_opt $task_idx TIMEOUT)
    local out_files=$(for h in $*; do N7::ssh_out_file $h; done)
    # NOTE: $out_files is a newline separated string of pathes.
    #       The use of IFS=$'\n' below is to make word-splitting split on
    #       newlines instead of white spaces, because a path may contain spaces.

    local eot_lines

    timeout=${timeout:-$N7_TASK_TIMEOUT}
    SECONDS=0
    while (( SECONDS < timeout )); do
        sleep 0.01
        eot_lines=$(IFS=$'\n' 
            tail -v -n1 $out_files |  # with tail's '==> path <==' headers
            grep -aPB1 "^$N7_EOT [^ ]+ (-1|\b$task_idx\b) \d+" || true
        )

        if [[ $eot_lines ]]; then grep "^$N7_EOT" <<<"$eot_lines"; fi
        out_files=$(
            diff <(echo "$eot_lines" | grep "^==>" | cut -d' ' -f2 | sort) \
                 <(echo "$out_files" | sort) | grep '^>' | cut -d' ' -f2
        )
        if [[ ! $out_files ]]; then return; fi  # ie, all out files have the EOT at the end.

    done
    local path oIFS=$IFS
    IFS=$'\n'
    for path in $out_files; do
        echo "$N7_EOT $(N7::ssh_host_from_out_file "$path") $task_idx $N7_ERRNO_TIMEOUT"
    done
    IFS=$oIFS
}

# N7::wait_for_task <task_idx> [host1 host2 ...]
#
# Wait for task to finish running until a timeout on each host.
#
# Updates N7_EHOSTS and N7_EHOSTS_FILE with the list of hosts that N7
# will be using for running the next task.
#
N7::wait_for_task() {
    local task_idx=$1; shift
    local ignore_status=$(N7::get_task_opt $task_idx IGNORE_STATUS)
    local hosts=$*
    local host rc

    # wait for the EOT marker at the end in each host's out file
    local results=$(N7::wait_for_task_on_hosts $task_idx $hosts)

    # Update host list base on EOT lines
    while read -r _ host _ rc _; do
        if [[ $rc != 0 ]]; then

            # remove timed out host so that it won't block the next task
            if [[ $rc = $N7_ERRNO_TIMEOUT ]]; then
                hosts=$(echo ${hosts/$host})

            # remove failed host if the task has no IGNORE_STATUS set
            elif [[ ! $ignore_status ]]; then
                hosts=$(echo ${hosts/$host})
            fi
        fi
        #NOTE: if a task is timed out but has IGNORE_STATUS set, and
        #  is actually still executing, it will block the tasks after
        #  it(because all tasks for a host share one ssh pipe), thus
        #  its following tasks are likely also going to be timed out.
    done <<<"$results"

    N7_EHOSTS=$hosts
    echo $hosts >$N7_EHOSTS_FILE
}


# N7::ssh_connect [host1 host2 ...]
#
# Establish ssh connections to remote hosts and setup named pipes and
# I/O redirects for N7 to communicate with the ssh processes and to
# recieve task outputs.
#
N7::ssh_connect() {
    local host port ssh_pipe ssh_out ssh_err fd
    for host in $*; do
        ssh_pipe=$(N7::ssh_read_pipe $host)
        if [[ -e $ssh_pipe ]]; then
            continue
        fi
        N7::debug "Creating pipes for $host..."
        ssh_out=$(N7::ssh_out_file $host) && touch "$ssh_out" && chmod 0600 "$ssh_out"
        ssh_err=$(N7::ssh_err_file $host) && touch "$ssh_err" && chmod 0600 "$ssh_err"

        mkfifo -m600 "$ssh_pipe" || N7::die "Failed making named pipes for ssh!"

        port=${N7_HOST_PORTS[$host]#:}

        N7::debug "Connecting to $host..."
        N7::debug "$N7_SSH_CMD ${port:+-p$port} $host"

        set -m  # temporarily enable job control to create the following
        (       # subshell in its own process group for easy killing during clean up.
          set +e +E

          # Run ssh command and connect its stdin to $ssh_pipe and outputs to files on the file system.
          $N7_SSH_CMD ${port:+-p$port} $host "exec -l $N7_REMOTE_SHELL" <"$ssh_pipe" >"$ssh_out" 2>"$ssh_err"

          # Make any further writes to the pipe fail without blocking.
          chmod a-w "$ssh_pipe"

          # Inject a time-out EOT line directly into the host outfile to avoid timeout
          echo $N7_EOT $host -1 $N7_ERRNO_TIMEOUT - > "$(N7::ssh_out_file $host)"

          # Read from the pipe to unblock the process that had written to it before the chmod.
          while true; do cat "$ssh_pipe" >/dev/null; done

        ) 2>>"$N7_INTERNAL_ERR_FILE" &
        set +m
        N7_SSH_PPIDs+=($!)

        N7::debug "SSH ppid=${N7_SSH_PPIDs[-1]} for $host"

        # this is just to keep the pipe from being closed when its
        # write end closes.
        exec {fd}>"$ssh_pipe" || N7::die "Failed FD creations and redirections"
        N7_SSH_PIPE_FDs+=($fd)
    done
}

# N7::show_task_outputs <task_idx> <hosts>
#
# Print the stdout of the task specified by the task index if the task is a
# command-line task or if the -o command-line option is set.
#
# Standard output of local tasks are always shown unless redirected within the
# local tasks.
#
# Further more, only the outputs delimited by the last EOT line are shown in
# cases where a task produces multiple EOT lines.
#
N7::show_task_outputs() {
    local task_idx=$1; shift
    local task_name=${N7_TASKS[$task_idx]}
    local last_task_idx=$((task_idx - 1))

    local show_output  # if -o is specified or if it's a cmdline task
    if [[ $N7_TASK_SHOW_STDOUT ||
          ${task_name/#.N7::cli_task::} != $task_name ]]; then
        show_output=1
    fi

    local host from_line out_file
    for host in $*; do
        out_file=$(N7::ssh_out_file $host)

        if [[ $show_output ]]; then
            from_line=$(grep -an "^$N7_EOT $host $last_task_idx " "$out_file" |
                    tail -n1 | cut -d: -f1)
            let ++from_line
            tail -n+$from_line "$out_file"
            #
            #NOTE: when outputing stdout, we are not removing the EOT line nor the
            #      empty line before it because even though those are not send by
            #      the user, removing them risk removing user output in the case
            #      of timeout.
            #
            # The N7::local::tasks::get_stdout() won't output the EOT line, and
            # using $(...) with the function usually gives the desired result
            # because bash always remove trailing newlines from a command
            # substitution.
        else
            local rc_change=$(grep -a "^$N7_EOT $host $task_idx" "$out_file" | tail -n1 | cut -d' ' -f4,5)
            N7::log "$host rc=${rc_change% *} state=${rc_change#* }"
        fi
    done
}

# N7::run_tasks <"task_name1 task_name2 ..."> <"host1 host2 ...">
# 
# Execute the bash functions(tasks) named on all the hosts specified.
# Each task will be run on all hosts, and a task must finish its execution on all hosts
# before the next will be run. If a task execution fails or timed out on a host then
# that host will be removed from execution of any further tasks unless the task has
# its IGNORE_STATUS option set and is not timed out.
#
# Moreover, the following environment variables will be available to all tasks:
#
#   N7_TASK_IDX - The index number(0-based) of the current task.
#   N7_EHOSTS   - "The effective hosts". A space separated list of hosts that the
#                 current task is going through.
#   N7_HOST     - The host on which the current task is running.
#
N7::run_tasks() {
    N7_EHOSTS=$(echo $2)

    # export it so this will be available to local tasks.
    local N7_TASK_IDX; export N7_TASK_IDX

    set -- $1

    local n7_builtin_tasks_count=$(
        declare -F | cut -d' ' -f3 | grep -P '^\.N7::' | grep -v '::cli_task::' | wc -l)

    N7::ssh_connect $N7_EHOSTS

    local host task rc no_subshell sudo hosts

    while [[ $# -gt 0 && $N7_EHOSTS ]]; do
        task=$1; shift
        N7_TASK_IDX=${N7_TASK_NAME_2_INDEX[$task]}

        no_subshell=$(N7::get_task_opt $N7_TASK_IDX NO_SUBSHELL)

        N7::log "Running Task: $(N7::get_task_opt $N7_TASK_IDX NAME) ..."

        # handle local task, which has no timeout control.
        if [[ $(N7::get_task_opt $N7_TASK_IDX LOCAL) ]]; then
            export N7_HOST=localhost;

            if [[ $no_subshell ]]; then $task; else ($task); fi; rc=$?
            N7::log "localhost rc=$rc"
            #FIXME: this doesn't tell us about the change status of the local task

            if [[ $rc != 0 && ! $(N7::get_task_opt $N7_TASK_IDX IGNORE_STATUS) ]]; then
                N7::die "Error running local task #$N7_TASK_IDX: $(N7::get_task_opt $N7_TASK_IDX NAME)"
            fi

            # We also send an EOT line to each remote host at the end of a local task.
            # This is to make extracting stdout or stderr of a remote task easier.
            for host in $N7_EHOSTS; do N7::send_eot_line $host $rc; done
            #FIXME: there should be a way to set the eot line's host to localhost 

        else
            # run the remote task on each host
            hosts=$(echo $N7_EHOSTS)
            for host in $hosts; do
                N7::run_pre_task_function $task $host
                N7::send_cmd " \
                    export N7_TASK_IDX=$N7_TASK_IDX \
                           N7_EHOSTS=$(N7::q "$hosts") \
                           N7_HOST=$(N7::q "$host") \
                    " $host
                [[ $no_subshell ]] || N7::send_cmd '('             $host
                                      N7::send_cmd $task           $host
                [[ $no_subshell ]] || N7::send_cmd ') </dev/null'  $host
                N7::send_eot_line $host
            done
            N7::wait_for_task $N7_TASK_IDX $hosts

            # Show output if it's not a built-in tasks, whose outputs are redirected
            # to $N7_INTERNAL_ERR_FILE
            #
            if [[ $N7_TASK_IDX -ge $n7_builtin_tasks_count ]]; then
                N7::show_task_outputs $N7_TASK_IDX $hosts
            fi
        fi

    done
}

# 
# N7::run_pre_task_function <task_name> <hostname>
#
# Every remote task is allowed to have a pre-task function, which
# will be executed locally before the remote task is run.
#
# Such function will be passed the hostname, on which the remote
# task will be run as its first argument.
#
# One use of such function is to obtain, via the N7::local::tasks:get_stdout
# function, the stdout of the last remote task run on the same host, and then
# do something immediately.
#
N7::run_pre_task_function() {
    local fname=pre:$1
    local host=$2
    if declare -f $fname; then
 #FIXME: need to make sure the function is defined in the same source file, 
 #       in which the remote task is defined.
        $fname $host
    fi
}


#N7::run_tasks_on_hosts "tasks..." "hosts..."
#
N7::run_tasks_on_hosts() {
    local tasks=$1 hosts=$2
    if [[ $N7_SSH_COUNT ]]; then
        while read hosts; do
            N7::run_tasks "$tasks" "${hosts}"
            if [[ $(N7::ssh_ehosts) != $hosts ]]; then
                return $?
            fi
        done < <(tr ' ' '\n' <<<$hosts | paste -d' ' $(seq -f - ${N7_SSH_COUNT}))
    else
        N7::run_tasks "$tasks" "$hosts"
        if [[ $(N7::ssh_ehosts) != $hosts ]]; then return $?; fi
    fi
}


