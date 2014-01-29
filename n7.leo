<?xml version="1.0" encoding="utf-8"?>
<!-- Created by Leo (http://leoeditor.com/leo_toc.html) -->
<?xml-stylesheet ekr_test?>
<leo_file xmlns:leo="http://www.leo-editor.org/2011/leo" >
<leo_header file_format="2" tnodes="0" max_tnode_index="0" clone_windows="0"/>
<globals body_outline_ratio="0.5" body_secondary_ratio="0.5">
	<global_window_position top="50" left="50" height="500" width="700"/>
	<global_log_window_position top="0" left="0" height="0" width="0"/>
</globals>
<preferences/>
<find_panel_settings/>
<vnodes>
<v t="jkuan.20140102223152.1607"><vh>@button Set headline from N7::*() { in the body</vh></v>
<v t="jkuan.20140102144155.1729"><vh>@settings</vh>
<v t="jkuan.20140102144155.1730"><vh>@string view-rendered-default-kind = md</vh></v>
<v t="jkuan.20140102223152.1587"><vh>@enabled-plugins</vh></v>
<v t="jkuan.20140107194142.1911"><vh>@bool scripting-at-script-nodes = true</vh></v>
</v>
<v t="jkuan.20140107194142.1912"><vh>@script</vh></v>
<v t="jkuan.20140102142439.1727" a="E"><vh>TODOs</vh>
<v t="jkuan.20140107111208.1901"><vh>ansible module integration</vh></v>
<v t="jkuan.20140107111208.1903"><vh>show colorized output</vh></v>
<v t="jkuan.20140107111208.1902"><vh>show also stderr for tasks with non-zero exit status</vh></v>
</v>
<v t="jkuan.20140115093336.1919" a="E"><vh>N7 built-in functions</vh>
<v t="jkuan.20140101001347.1715" a="E"><vh>&lt;&lt; local built-ins &gt;&gt;</vh>
<v t="jkuan.20140115093336.1920" a="E"><vh>Ansible adapters</vh>
<v t="jkuan.20140109170044.1915"><vh>N7::local::ansible::replace_mod</vh>
<v t="jkuan.20140109170044.1916"><vh>&lt;&lt; ansible module replacer &gt;&gt;</vh></v>
</v>
<v t="jkuan.20140109170044.1917"><vh>N7::local::ansible::send_mod</vh></v>
<v t="jkuan.20140109170044.1918"><vh>N7::local::ansible::run_mod</vh></v>
</v>
<v t="jkuan.20140101001347.1716"><vh>N7::local::utils::trap</vh></v>
<v t="jkuan.20140101001347.1717"><vh>N7::local::commands::remote</vh></v>
<v t="jkuan.20140101001347.1718"><vh>N7::local::commands::send_funcs</vh></v>
<v t="jkuan.20140101001347.1719"><vh>N7::local::commands::send_env</vh></v>
<v t="jkuan.20140101001347.1720"><vh>N7::local::commands::n7</vh></v>
<v t="jkuan.20140101001347.1721"><vh>N7::local::files::cp</vh></v>
<v t="jkuan.20140101001347.1722"><vh>N7::local::files::bash_tpl</vh></v>
<v t="jkuan.20140101001347.1723"><vh>N7::local::files::scp</vh></v>
<v t="jkuan.20140101001347.1724"><vh>N7::local::tasks::get_stdout</vh></v>
<v t="jkuan.20140101001347.1725"><vh>N7::local::tasks::get_stderr</vh></v>
</v>
<v t="jkuan.20140101001347.1713" a="E"><vh>&lt;&lt;remote built-ins&gt;&gt;</vh>
<v t="jkuan.20140101001347.1726"><vh>N7::remote::files::file</vh></v>
<v t="jkuan.20140101001347.1727"><vh>N7::remote::tasks::change_file</vh></v>
<v t="jkuan.20140101001347.1728"><vh>N7::remote::tasks::touch_change</vh></v>
<v t="jkuan.20140115093336.1921"><vh>N7::remote::tasks::reset_change</vh></v>
<v t="jkuan.20140101001347.1729"><vh>N7::remote::tasks::changed</vh></v>
<v t="jkuan.20140109170044.1919"><vh>N7::remote::ansible::check_status</vh></v>
</v>
</v>
<v t="jkuan.20131231170128.1692" a="E"><vh>/</vh>
<v t="jkuan.20140102135512.1728"><vh>@edit README.md</vh></v>
<v t="jkuan.20140106102002.1897" a="E"><vh>tests</vh>
<v t="jkuan.20140107111208.1905"><vh>@file setup.sh</vh></v>
<v t="jkuan.20140106102002.1899"><vh>@file basic.n7</vh></v>
<v t="jkuan.20140107111208.1904"><vh>@file test-n7-cmdline</vh></v>
</v>
<v t="jkuan.20140101001347.1707" a="E"
expanded="jkuan.20140105132438.2228,jkuan.20140101001347.1713,jkuan.20140101001347.1708,jkuan.20140101001347.1715,jkuan.20140115093336.1920,"><vh>@shadow bin/n7</vh></v>
</v>
</vnodes>
<tnodes>
<t tx="jkuan.20131231170128.1692">@color
@language shell

</t>
<t tx="jkuan.20140101001347.1713"># Functions under the N7::remote "namespace can be used both remotely and locally.

@others
</t>
<t tx="jkuan.20140101001347.1715"># Functions under the N7::local "namespace" can only be used locally.

@others

</t>
<t tx="jkuan.20140101001347.1716">#
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
</t>
<t tx="jkuan.20140101001347.1717"># N7::local::commands::remote &lt;cmd&gt;
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
        [ "$no_subshell" ] || N7::send_cmd '(' $host
        N7::send_cmd "$1"                      $host
        [ "$no_subshell" ] || N7::send_cmd ')' $host
        N7::send_eot_line $host
    done
    hosts=$(N7::wait_for_task $N7_TASK_IDX $hosts)
    echo $hosts &gt;"$N7_EHOSTS_FILE"

    [ "$N7_EHOSTS" = "$hosts" ]
    return $?
}
</t>
<t tx="jkuan.20140101001347.1718"># N7::local::commands::send_funcs [func_name1 func_name2 ...]
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
    [ "$failed" ] &amp;&amp; N7::die "Failed locating functions: ${failed[*]}"

    local f hosts=$(N7::ssh_ehosts)
    for f in "${funcs[@]}"; do
        no_subshell=1 N7::local::commands::remote "$f"
    done
    [ "$N7_EHOSTS" = "$hosts" ]
    return $?
}
</t>
<t tx="jkuan.20140101001347.1719"># N7::local::commands::send_env [name1=value1 name2=value2 ...]
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
            N7::send_cmd "export $(N7::q "$name_value") &amp;&amp;" $host
        done
        N7::send_cmd "true" $host
        N7::send_eot_line $host
    done
    hosts=$(N7::wait_for_task $N7_TASK_IDX $hosts)
    echo $hosts &gt;"$N7_EHOSTS_FILE"

    [ "$N7_EHOSTS" = "$hosts" ]
    return $?
}
</t>
<t tx="jkuan.20140101001347.1720"># N7::local::commands::n7 -s &lt;n7script_path&gt; [options] [args]
#
# Run n7 in a subshell with the current effective hosts.
#
# The current effective hosts will be passed to the n7 subprocess, therefore
# you should not specify the -m option.
#
N7::local::commands::n7() {
    echo $N7_EHOSTS | N7_EHOSTS_FILE=$N7_EHOSTS_FILE "$0" -m - "$@"
}
</t>
<t tx="jkuan.20140101001347.1721"># N7::local::files::cp &lt;local_path&gt; &lt;remote_path&gt; [options]
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
#   tplcmd - template command to run to process &lt;local_path&gt; before sending it
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
        [[ $nv =~ .+= ]] &amp;&amp; params[${nv%%=*}]=${nv#*=}
    done
    local tplcmd=${params[tplcmd]}
    local _sudo=${sudo:+$(N7::get_sudo "$sudo")}

    local token=$(openssl rand -hex 8)
    N7::local::commands::remote "echo $token \$($_sudo openssl md5 -r $(N7::q "$dest") 2&gt;/dev/null | cut -d' ' -f1)"

    local host hosts=$(N7::ssh_ehosts)
    local lmd5 rmd5 encoded content

    if [ "$tplcmd" ]; then
        for host in $hosts; do
            content=$(N7_HOST=$host $tplcmd "$src") || return $?
            lmd5=$(openssl md5 -r &lt;&lt;&lt;"$content" | cut -d' ' -f1)
            rmd5=$(N7::local::tasks::get_stdout $host $N7_TASK_IDX $token); rmd5=${rmd5#* }

            # only copy the file if their md5 sums differ
            if [ "$rmd5" != "$lmd5" ]; then
                encoded=$(base64 &lt;&lt;&lt;"$content") || return $?
                N7::send_cmd "unset N7_RC; echo \"$encoded\" | base64 --decode |
                    $_sudo tee $dest &gt;/dev/null &amp;&amp; N7::remote::tasks::touch_change; N7_RC=\$?" $host
            fi
            N7::send_cmd "sudo=$(N7::q "$sudo") N7::remote::files::file $dest $(N7::qm "$@")" $host
            N7::send_eot_line $host '$(( N7_RC | $? ))'
        done
    else
        content=$(&lt;"$src") || return $?
        lmd5=$(openssl md5 -r &lt;&lt;&lt;"$content" | cut -d' ' -f1)
        encoded=$(base64 &lt;&lt;&lt;"$content") || return $?

        for host in $hosts; do
            rmd5=$(N7::local::tasks::get_stdout $host $N7_TASK_IDX $token); rmd5=${rmd5#* }

            # only copy the file if their md5 sums differ
            if [ "$rmd5" != "$lmd5" ]; then
                N7::send_cmd "unset N7_RC; echo \"$encoded\" | base64 --decode |
                    $_sudo tee $dest &gt;/dev/null &amp;&amp; N7::remote::tasks::touch_change; N7_RC=\$?" $host
            fi
            N7::send_cmd "sudo=$(N7::q "$sudo") N7::remote::files::file $dest $(N7::qm "$@")" $host
            N7::send_eot_line $host '$(( N7_RC | $? ))'
        done
    fi

    hosts=$(N7::wait_for_task $N7_TASK_IDX $hosts)
    echo $hosts &gt;"$N7_EHOSTS_FILE"

    [ "$N7_EHOSTS" = "$hosts" ]
    return $?
}
</t>
<t tx="jkuan.20140101001347.1722"># N7::local::files::bash_tpl &lt;bash_template_file_path&gt;
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
@raw
        source &lt;(echo "cat &lt;&lt;EOF
$(&lt;"$1")
EOF
"       )
@end_raw
    ) | sed '/^[[:space:]]*#:.*$/d'
}

</t>
<t tx="jkuan.20140101001347.1723">#
# This is an alternative implementation of N7::local::files::cp() that uses scp
# instead. It first scp the source file to a temporary file and then move it over
# to the destination if the scp was successful. It might be faster and safer for
# large files.
#
N7::local::files::scp() {
    local src=$1 dest=$(N7::q "$2"); shift; shift
    local -A params=()
    local nv; for nv in "$@"; do
        [[ $nv =~ .+= ]] &amp;&amp; params[${nv%%=*}]=${nv#*=}
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
        scp $N7_SSH_OPTS "$src" "$host:$tmpf" &amp;
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
                $_sudo mv $src $dest &amp;&amp;
                sudo="$sudo" N7::remote::files::file $dest $(N7::qm "$@")
            " $host
            N7::send_eot_line $host \$?
        else
            N7::send_eot_line $host 1
        fi
    done

    hosts=$(N7::wait_for_task $N7_TASK_IDX $hosts)
    echo $hosts &gt;"$N7_EHOSTS_FILE"

    [ "$N7_EHOSTS" = "$hosts" ]
    return $?
}
</t>
<t tx="jkuan.20140101001347.1724"># N7::local::tasks::get_stdout &lt;hostname&gt; &lt;task_index&gt; [pattern]
#
# Output the stdout of the task with &lt;task_idx&gt; from &lt;hostname&gt; that
# matches the optional regex pattern.
#
N7::local::tasks::get_stdout() {
    [ "$2" -ge 0 ] &amp;&amp;
    awk 'BEGIN { i = 0 }
    { if ($0 !~ "^'$N7_EOT'") {
        if ($0 ~ /'${3:-.}'/)
          lines[i++] = $0
      } else {
        if ($3 == "'$2'")
          for (e=0; e &lt; i; e++)
            print lines[e];
        i=0;
      } 
    }' "$(N7::ssh_out_file $1)"
}
</t>
<t tx="jkuan.20140101001347.1725">#
# Output the stderr of the task with &lt;task_idx&gt; from &lt;hostname&gt;
#
eval "$(declare -f N7::local::tasks::get_stdout \
         | sed -e 's/stdout/stderr/
                   s/_out_/_err_/'
       )"
</t>
<t tx="jkuan.20140101001347.1726">#
# Set file attributes. Options are:
#
#   owner  - owner name.
#   group  - group name.
#   mode   - file permission mode; only numeric octal digits allowed.
#
# Environment vars that affect the command:
#
#   sudo   - sudo before the operation. 1 to use $N7_SUDO, any other
#            value to use as the command to sudo.
#
# This function can be use both remotely and locally.
#
N7::remote::files::file() {
    local path=$(N7::q "$1")
    declare -A params=()
    local nv
    for nv in "$@"; do
        [[ $nv =~ .+= ]] &amp;&amp; params[${nv%%=*}]=${nv#*=}
    done
    local changed
    changed=$(${sudo:+$(N7::get_sudo "$sudo")} /bin/bash -s -- &lt;&lt;EOF
        owner=$(N7::q "${params[owner]}")
        group=$(N7::q "${params[group]}")
        mode=$(N7::q "${params[mode]}")
        mode=\${mode:-0\$(printf %o \$((0666 - \$(umask))))}
        if [[ \${#mode} = 3 ]]; then mode=0\$mode; fi
        rt=0; chgd=0
        read u g m &lt; &lt;(stat -c "%U %G %a" $path); if [[ \${#m} = 3 ]]; then m=0\$m; fi
        if [[ \$owner ]]; then [[ \$u == \$owner ]] || { chown \$owner $path &amp;&amp; chgd=1; rt=\$((\$? | rt)); }; fi
        if [[ \$group ]]; then [[ \$g == \$group ]] || { chgrp \$group $path &amp;&amp; chgd=1; rt=\$((\$? | rt)); }; fi
        if [[ \$mode  ]]; then [[ \$m == \$mode  ]] || { chmod \$mode  $path &amp;&amp; chgd=1; rt=\$((\$? | rt)); }; fi
        echo \$chgd
        exit \$rt
@raw
EOF
@end_raw
    )
    local rc=$?; if [ "$changed" = 1 ]; then N7::remote::tasks::touch_change; fi
    return $rc
}
</t>
<t tx="jkuan.20140101001347.1727">N7::remote::tasks::change_file() {
    local task_idx=${1:-$N7_TASK_IDX}
    if [ "$N7_HOST" != "localhost" ]; then
        echo "$N7_REMOTE_RUN_DIR/task_$task_idx.change"
    else
        echo "$N7_RUN_DIR/task_$task_idx.change"
    fi
}
</t>
<t tx="jkuan.20140101001347.1728">N7::remote::tasks::touch_change() {
    local change_file=$(N7::remote::tasks::change_file)
    [ -e "$change_file" ] || touch "$change_file"
}
</t>
<t tx="jkuan.20140101001347.1729">N7::remote::tasks::changed() {
    [ -e "$(N7::remote::tasks::change_file $1)" ]
}
</t>
<t tx="jkuan.20140102142439.1727">@language python
</t>
<t tx="jkuan.20140102144155.1729"></t>
<t tx="jkuan.20140102144155.1730"></t>
<t tx="jkuan.20140102223152.1587"></t>
<t tx="jkuan.20140102223152.1607">@language python
@tabwidth -4

for p in c.getSelectedPositions():
    for line in p.b.split("\n"):
        line = line.strip()
        if line.startswith("N7::") and line.endswith("() {"):
            p.h = line[:-4]
            break
        
        
</t>
<t tx="jkuan.20140106102002.1897">@path tests</t>
<t tx="jkuan.20140107111208.1901" annotate="7d71002855087072696f7269747971014b03550a707269736574646174657102550a323031342d30312d30377103752e" lineYOffset="4b032e" icons="5d71007d71012855026f6e71025505766e6f64657103550577686572657104550e6265666f7265486561646c696e6571055507796f666673657471064b005507786f666673657471074b02550466696c657108587c0000002f4170706c69636174696f6e732f4c656f2d342e31312d66696e616c2f7669727475616c2f6c69622f707974686f6e322e372f736974652d7061636b616765732f6c656f2d342e31312e66696e616c5f6275696c645f353032302d7079322e372e6567672f6c656f2f49636f6e732f636c656f2f707269332e706e677109550478706164710a4b01550474797065710b68085508636c656f49636f6e710c550131710d550772656c50617468710e580d000000636c656f2f707269332e706e67710f75612e"></t>
<t tx="jkuan.20140107111208.1902">@killcolor

Or...not. This complicates the output as we'll need to distinguish between outputs coming from stdout and stderr.
The user can redirect stderr to stdout manually in the remote task, or we might provide a command-line option
for doing this to all remote tasks.</t>
<t tx="jkuan.20140107111208.1903"></t>
<t tx="jkuan.20140107194142.1911"></t>
<t tx="jkuan.20140107194142.1912">c.k.simulateCommand('toggle-split-direction')
</t>
<t tx="jkuan.20140109170044.1915">N7::local::ansible::replace_mod() {
    python - &lt;&lt;&lt;"$(cat &lt;&lt;'EOF'
&lt;&lt; ansible module replacer &gt;&gt;
@raw
EOF
@end_raw
)" "$@"
}
</t>
<t tx="jkuan.20140109170044.1916">@language python
@first
#
# Tested with Ansible 1.4.4
#
# Usage: $0 &lt;module_name&gt; [name=value ...]
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

</t>
<t tx="jkuan.20140109170044.1917"># N7::local::ansible::send_mod &lt;module_name&gt; [name=value ...]
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
        N7::local::files::cp &lt;(cat) "$tmpf" mode=0755
    )
}
</t>
<t tx="jkuan.20140109170044.1918"># N7::local::ansible::run_mod &lt;module_name&gt; [name=value ...]
#   
# Transfer and run an ansible module with the specified arguments.
#
# Environment vars that affect the command:
#
#   sudo   - sudo before the operation. 1 to use $N7_SUDO, any other
#            value to use as the command to sudo.

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
            ${sudo:+$(N7::get_sudo "$sudo")} $tmpf &lt;&lt;&lt;$(N7::q $*) | tee \$N7_ANSIBLE_OUT
            rm -f $tmpf
            N7::remote::tasks::reset_change
            N7::remote::ansible::check_status
        "
    fi
}
</t>
<t tx="jkuan.20140109170044.1919"># N7::remote::ansible::check_status
#
# Check the exit status of the last Ansible module run.
# Return 1 if it the run failed; return 0 otherwise.
#
N7::remote::ansible::check_status() {
    local changed
    changed=$(
@raw
     python -c '
import sys, json
#FIXME: handle single line name=value pairs
with open(sys.argv[1]) as f:
    data = json.load(f)
if data.get("changed"):
    print 1
if "failed" in data:
    sys.exit(1)
'    "$N7_ANSIBLE_OUT")
@end_raw
    local rc=$?
    if [ "$changed" = 1 ]; then N7::remote::tasks::touch_change; fi
    return $rc
}
</t>
<t tx="jkuan.20140115093336.1919">@language shell
</t>
<t tx="jkuan.20140115093336.1920">@others</t>
<t tx="jkuan.20140115093336.1921">N7::remote::tasks::reset_change() {
    rm -f "$(N7::remote::tasks::change_file)"
}
</t>
</tnodes>
</leo_file>
