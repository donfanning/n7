# Functions under the N7::local "namespace" can only be used locally.

#
# Wrapper around Bash's built-in trap command.
# It takes care not to overwrite existing commands already assigned to a signal.
#
# Use it instead if you would like to use trap in your N7 script.
#
N7::local::utils::trap() {
    local cmd=$1; shift
    local signal cur_cmd;
    for signal in $*; do
        cur_cmd=$(trap -p $signal)
        cur_cmd=${cur_cmd#*\'}
        cur_cmd=${cur_cmd%\'*}
        trap "${cur_cmd:+"$cur_cmd;"} $cmd" $signal
    done
}


# N7::local::commands::remote <cmd>
#
# Run cmd on ALL effective remote hosts.
# The command will be run in a subshell unless the env var no_subshell is
# set for the command. Eg, no_subshell=1 N7::local::commands::remote "echo hello"
#
# Return 0 if the command was run successfully on all remote hosts;
# return 1 otherwise.
#
# This function can only be used from a local task.
#
N7::local::commands::remote() {
    local host hosts=$(N7::ssh_ehosts)
    for host in $hosts; do
        [[ $no_subshell ]] || N7::send_cmd '(' $host
        N7::send_cmd "$1"                      $host
        [[ $no_subshell ]] || N7::send_cmd ')' $host
        N7::send_eot_line $host
    done
    N7::wait_for_task $N7_TASK_IDX $hosts
    if [[ $N7_EHOSTS != $hosts ]]; then return $?; fi
}


# N7::local::commands::send_funcs [func_name1 func_name2 ...]
#
# Define the list of functions specified on the remote end.
# Abort n7 with an error if it can't locate all functions specified.
#
# Return 0 if all functions are defined successfully on the remote hosts;
# return 1 otherwise.
#
# Alternatively, you can define your remote helper functions within
# a remote task function that declares ': NO_SUBSHELL=1' so that when
# the task is run remotely, all the functions within it will be defined
# globally for later tasks.
#
# This function can only be used from a local task.
#
N7::local::commands::send_funcs() {
    local name funcs=() failed=()
    for name in $*; do
        funcs+=("$(declare -f "$name")") || failed+=("$name")
    done
    [[ $failed ]] && N7::die "Failed locating functions: ${failed[*]}"

    local hosts=$(N7::ssh_ehosts)
    if [[ $N7_REMOTE_STDERR_TO_STDOUT ]]; then
        local f i=0 j
        for f in "${funcs[@]}"; do
            # skip redirecting command line tasks since they are already, by default, redirected.
            ((j = i + 1))
            if [[ ${!j} =~ ^\.N7::cli_task:: ]]; then
                continue
            fi
            funcs[$i]=$(printf %s "$f" | sed '$s/}$/} 2>\&1/')
            ((++i))
        done
    fi
    local src=$(N7::q "$N7_REMOTE_TASKS_SRC")
    N7::local::commands::remote "echo '$(printf '%s\n' "${funcs[@]}" | base64)' | base64 --decode >> $src"
    no_subshell=1 N7::local::commands::remote "source $src"

    if [[ $N7_EHOSTS != $hosts ]]; then return $?; fi
}


# N7::local::commands::send_env [name1=value1 name2=value2 ...]
#
# Define environment variables on all remote hosts.
#
# Each name=value pair must be passed to this function as a single argument.
# (i.e., space and special shell characters will need to be quoted)
#
# Return 0 if all functions are defined successfully on the remote hosts;
# return 1 otherwise.
#
# This function can only be used from a local task.
#
N7::local::commands::send_env() {
    local host name_value hosts=$(N7::ssh_ehosts)
    for host in $hosts; do
        for name_value in "$@"; do
            N7::send_cmd "export -- $(N7::q "$name_value") && " $host
        done
        N7::send_cmd "true" $host
        N7::send_eot_line $host
    done
    N7::wait_for_task $N7_TASK_IDX $hosts
    if [[ $N7_EHOSTS != $hosts ]]; then return $?; fi
}


# N7::local::commands::n7 -s <n7script_path> [options] [args]
#
# Run n7 in a subshell with the current effective hosts.
#
# The current effective hosts will be passed to the n7 subprocess, therefore
# you should not specify the -m option.
#
N7::local::commands::n7() {
    echo $N7_EHOSTS | N7_EHOSTS_FILE=$N7_EHOSTS_FILE "$0" -m - "$@"
}


# N7::local::files::cp <local_path> <remote_path> [options]
#
# Copy a file from localhost to the remote hosts.
# Any host it fails to copy the file to will be removed from $N7_EHOSTS.
# Return 0 if the file is copied to all hosts successfully; return 1 otherwise.
#
# Options are name=value pairs. Quotes are needed to escape space and other
# special characters.
#
# Options:
#
#   tplcmd - template command to run to process <local_path> before sending it
#            to a remote host.
#
#            Environment variables available to the invoking local task will
#            still be availalbe, plus a N7_HOST env var will be set to the
#            remote host that the file will be copied to.
#
#            N7 includes a built-in N7::local::files::bash_tpl function, which 
#            will process the file as a here-doc.
#
# All options allowed by the N7::remote::files::file task are also allowed here.
# 
# Environment vars that affect the command:
#
#   sudo   - sudo before the operation. 1 to use $N7_SUDO, any other
#            value to use as the command to sudo.
#
# This function can only be used from a local task one at a time. 
#
N7::local::files::cp() {
    local src=$1 dest=$(N7::q "$2"); shift; shift
    local -A params=()
    local nv; for nv in "$@"; do
        [[ $nv =~ .+= ]] && params[${nv%%=*}]=${nv#*=}
    done
    local tplcmd=${params[tplcmd]}
    local _sudo=${sudo:+$(N7::get_sudo "$sudo")}

    local token=$(openssl rand -hex 8)
    N7::local::commands::remote "echo $token \$($_sudo openssl md5 -r $(N7::q "$dest") 2>/dev/null | cut -d' ' -f1)"

    local host hosts=$(N7::ssh_ehosts)
    local lmd5 rmd5 encoded content

    if [[ $tplcmd ]]; then
        for host in $hosts; do
            content=$(N7_HOST=$host $tplcmd "$src") || return $?
            lmd5=$(openssl md5 -r <<<"$content" | cut -d' ' -f1)
            rmd5=$(N7::local::tasks::get_stdout $host $N7_TASK_IDX $token); rmd5=${rmd5#* }

            # only copy the file if their md5 sums differ
            if [[ $rmd5 != $lmd5 ]]; then
                encoded=$(base64 <<<"$content") || return $?
                N7::send_cmd "unset N7_RC; echo \"$encoded\" | base64 --decode |
                    $_sudo tee $dest >/dev/null && N7::remote::tasks::touch_change; N7_RC=\$?" $host
            fi
            N7::send_cmd "sudo=$(N7::q "$sudo") N7::remote::files::file $dest $(N7::qm "$@")" $host
            N7::send_eot_line $host '$(( N7_RC | $? ))'
        done
    else
        content=$(<"$src") || return $?
        lmd5=$(openssl md5 -r <<<"$content" | cut -d' ' -f1)
        encoded=$(base64 <<<"$content") || return $?

        for host in $hosts; do
            rmd5=$(N7::local::tasks::get_stdout $host $N7_TASK_IDX $token); rmd5=${rmd5#* }

            # only copy the file if their md5 sums differ
            if [[ $rmd5 != $lmd5 ]]; then
                N7::send_cmd "unset N7_RC; echo \"$encoded\" | base64 --decode |
                    $_sudo tee $dest >/dev/null && N7::remote::tasks::touch_change; N7_RC=\$?" $host
            fi
            N7::send_cmd "sudo=$(N7::q "$sudo") N7::remote::files::file $dest $(N7::qm "$@")" $host
            N7::send_eot_line $host '$(( N7_RC | $? ))'
        done
    fi

    N7::wait_for_task $N7_TASK_IDX $hosts
    if [[ $N7_EHOSTS != $hosts ]]; then return $?; fi
}


# N7::local::files::bash_tpl <bash_template_file_path>
#
# Print the contents of a local file to stdout.
# The file content is subject to parameter expansions and process substitutions.
#
# Output lines(with optional leading space characters) that begin with the
# character sequence #: will be removed from the output. 
#
# In cases where variable assignment is needed, parameter expansion
# can be used to achieve the desired side effect.
#
# Example template file:
#
#    #: ${time_start:=$(date +%s)}
#    Sleeping...
#    #: $(sleep 2)
#    Slept for $(($(date +%s) - time_start)) seconds.
#
# Note that time_start must not have been set in order for it to be
# set, and once it's set, it cannot be unset or re-assigned. So, rather
# this trick is more like "binding" a var name to a value than setting
# a variable to a value.
#
N7::local::files::bash_tpl() {
    (
        source <(echo "cat <<EOF
$(<"$1")
EOF
"       )
    ) | sed '/^[[:space:]]*#:.*$/d'
}


#
# This is an alternative implementation of N7::local::files::cp() that uses scp
# instead. It first scp the source file to a temporary file and then move it over
# to the destination if the scp was successful. It might be faster and safer for
# large files.
#
N7::local::files::scp() {
    local src=$1 dest=$(N7::q "$2"); shift; shift
    local -A params=()
    local nv; for nv in "$@"; do
        [[ $nv =~ .+= ]] && params[${nv%%=*}]=${nv#*=}
    done

    local tmpdir=$(N7::q "$N7_REMOTE_TMP_DIR")
    local host hosts=$(N7::ssh_ehosts)
    for host in $hosts; do
        N7::send_cmd "tmpdir=$tmpdir mktemp -t .tmp.XXXXXXXXXXX" $host
        #FIXME: tmp file name shows up in stdout...
        N7::send_eot_line $host \$?
    done
    hosts=$(N7::wait_for_task $N7_TASK_IDX $hosts)

    local tmpf pids=()
    local -A tmpfiles=()
    for host in $hosts; do
        tmpf=$(N7::local::tasks::get_stdout $host $N7_TASK_IDX | tail -2 | head -1)
        tmpfiles[$host]="$tmpf"
        scp $N7_SSH_OPTS "$src" "$host:$tmpf" &
        pids+=($host,$!)
    done

    local _sudo=${sudo:+$(N7::get_sudo "$sudo")}

    local host_pid 
    for host_pid in ${pids[*]}; do
        host=${host_pid%,*}
        src=$(N7::q "${tmpfiles[$host]}")
        N7::send_cmd ": N7::local::files::scp $src $dest" $host
        if wait ${host_pid#*,}; then
            N7::send_cmd "
                $_sudo mv $src $dest &&
                sudo="$sudo" N7::remote::files::file $dest $(N7::qm "$@")
            " $host
            N7::send_eot_line $host \$?
        else
            N7::send_eot_line $host 1
        fi
    done

    N7::wait_for_task $N7_TASK_IDX $hosts
    if [[ $N7_EHOSTS != $hosts ]]; then return $?; fi
}


# N7::local::tasks::get_stdout <hostname> <task_index|task_name> [pattern]
#
# Output the stdout of the task with <task_idx> from <hostname> that
# matches the optional regex pattern.
#
N7::local::tasks::get_stdout() {
    local task_idx
    if ! N7::is_num "$2"; then
        task_idx=${N7_TASK_NAME_2_INDEX[$2]}
    else
        task_idx=$2
    fi
    [[ $task_idx -ge 0 ]] &&
    awk 'BEGIN { i = 0 }
    { if ($0 !~ "^'$N7_EOT'") {
        if ($0 ~ /'${3:-.}'/)
          lines[i++] = $0
      } else {
        if ($3 == "'$task_idx'")
          for (e=0; e < i; e++)
            print lines[e];
        i=0;
      } 
    }' "$(N7::ssh_out_file $1)"
}

#
# Output the stderr of the task with <task_idx> from <hostname>
#
eval "$(declare -f N7::local::tasks::get_stdout \
         | sed -e 's/stdout/stderr/
                   s/_out_/_err_/'
       )"


N7::local::ansible::replace_mod() {
    python - <<<"$(cat <<'EOF'
#
# Tested with Ansible 1.4.4
#
# Usage: $0 <module_name> [name=value ...]
#
# If the last argument is a single '-' character then also
# read complex args(ie, YAML) from stdin.
#
# Outputs:
#   First line is the module style: 'new' or not 'new'.
#   The rest is the modified ansible module to be transferred to remote hosts.
#
# Note that if module style is not 'new' then you have to provide the arguments
# as stdin to the module when you execute it, and in this case, I believe,
# complex args is not supported.
#

import sys
import yaml

import ansible.utils
import ansible.errors
from ansible.module_common import ModuleReplacer

replacer = ModuleReplacer(True)

mod_name = sys.argv[1]
mod_src = ansible.utils.module_finder.find_plugin(mod_name)
if not mod_src:
    raise ansible.errors.AnsibleFileNotFound("module %s not found in %s" % (
        mod_name, ansible.utils.plugins.module_finder.print_paths()))

complex_args = {}

# if the last arg is a '-' then read stdin as complex args.
if sys.argv[-1] == '-': 
    complex_args = yaml.load(sys.stdin)
    del sys.argv[-1]

mod_args = ' '.join(sys.argv[2:])

inject = {}
mod_dump, mod_style, shebang = replacer.modify_module(mod_src, complex_args, mod_args, inject)

print mod_style
print mod_dump

EOF
)" "$@"
}


# N7::local::ansible::send_mod <module_name> [name=value ...]
#
# Transfer an ansible module over to the remote hosts.
# The ansible module will be configured with the arguments specified if
# it's a new style module.
# 
N7::local::ansible::send_mod() {
    local data
    data=$(N7::local::ansible::replace_mod "$@") || return $?
    echo "$data" | (
        read mod_style
        tmpf=$N7_REMOTE_RUN_DIR/ansmod_${mod_style}.$(openssl rand -hex 16)
        echo $tmpf
        N7::local::files::cp <(cat) "$tmpf" mode=0755
    )
}


# N7::local::ansible::run_mod <module_name> [name=value ...]
#   
# Transfer and run an ansible module with the specified arguments.
#
# Environment vars that affect the command:
#
#   sudo   - sudo before the operation. 1 to use $N7_SUDO, any other
#            value to use as the command to sudo.
#
N7::local::ansible::run_mod() {
    local tmpf; tmpf=$(N7::local::ansible::send_mod "$@") || return 1
    local mod_style=$(basename "${tmpf%%.*}"); mod_style=${mod_style#ansmod_}

    if [[ $mod_style = new ]]; then
        N7::local::commands::remote "
            ${sudo:+$(N7::get_sudo "$sudo")} $tmpf | tee \$N7_ANSIBLE_OUT
            rm -f $tmpf
            N7::remote::tasks::reset_change
            N7::remote::ansible::check_status
        "
    else
        N7::local::commands::remote "
            ${sudo:+$(N7::get_sudo "$sudo")} $tmpf <<<$(N7::q $*) | tee \$N7_ANSIBLE_OUT
            rm -f $tmpf
            N7::remote::tasks::reset_change
            N7::remote::ansible::check_status
        "
    fi
}






