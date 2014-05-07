N7::q() { printf "%q\n" "$*"; }
N7::qm() {
    local result=$(printf "%q " "$@")
    printf "%s\n" "${result% }"
}
N7::get_sudo() {
    local sudo=${1:-$N7_SUDO}
    if [ "$sudo" = 1 ]; then echo "$N7_SUDO"; else echo "$sudo"; fi
}


# Show the line and line number of the task the exited with a non-zero status.
# Use it in a remote task like this: set -e; trap 'N7::remote::tasks::stack_trace $?' ERR
#
N7::remote::tasks::stack_trace() {
    local traceline=$(i=0; while caller $((i++)); do :; done)
    local topline=$(head -n1 <<<"$traceline")
    local lineinfo=( $topline ) # ie, (lineNo. func_name /src/file)

    # Use this instead of ${lineinfo[2]} since path may contain spaces.
    local srcfile=${topline#* }; srcfile=${srcfile#* }  

    local offset=$(( ${lineinfo[0]} - $(grep -m1 -n ^${lineinfo[1]} "$srcfile" | cut -d: -f1) ))

    echo "Exit $1 from line $offset of task ${lineinfo[1]}:"
    echo "$(sed -n ${lineinfo[0]}p "$srcfile")"
    echo 
    echo "Stack trace -------------:"
    echo "$traceline"

} >&2



# Functions under the N7::remote "namespace can be used both remotely and locally.

#
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
        [[ $nv =~ .+= ]] && params[${nv%%=*}]=${nv#*=}
    done
    local changed
    changed=$(${sudo:+$(N7::get_sudo "$sudo")} /bin/bash -s -- <<EOF
        owner=$(N7::q "${params[owner]}")
        group=$(N7::q "${params[group]}")
        mode=$(N7::q "${params[mode]}")
        mode=\${mode:-0\$(printf %o \$((0666 - \$(umask))))}
        if [[ \${#mode} = 3 ]]; then mode=0\$mode; fi
        rt=0; chgd=0
        read u g m < <(stat -c "%U %G %a" $path); if [[ \${#m} = 3 ]]; then m=0\$m; fi
        if [[ \$owner ]]; then [[ \$u == \$owner ]] || { chown \$owner $path && chgd=1; rt=\$((\$? | rt)); }; fi
        if [[ \$group ]]; then [[ \$g == \$group ]] || { chgrp \$group $path && chgd=1; rt=\$((\$? | rt)); }; fi
        if [[ \$mode  ]]; then [[ \$m == \$mode  ]] || { chmod \$mode  $path && chgd=1; rt=\$((\$? | rt)); }; fi
        echo \$chgd
        exit \$rt
EOF
    )
    local rc=$?; if [ "$changed" = 1 ]; then N7::remote::tasks::touch_change; fi
    return $rc
}


N7::remote::tasks::change_file() {
    local task_idx=${1:-$N7_TASK_IDX}
    if [ "$N7_HOST" != "localhost" ]; then
        echo "$N7_REMOTE_RUN_DIR/task_$task_idx.change"
    else
        echo "$N7_RUN_DIR/task_$task_idx.change"
    fi
}
N7::remote::tasks::touch_change() {
    local change_file=$(N7::remote::tasks::change_file)
    [[ -e $change_file ]] || touch "$change_file"
}
N7::remote::tasks::reset_change() {
    rm -f "$(N7::remote::tasks::change_file)"
}
N7::remote::tasks::changed() {
    [[ -e $(N7::remote::tasks::change_file $1) ]]
}


# N7::remote::ansible::check_status
#
# Check the exit status of the last Ansible module run.
# Return 1 if it the run failed; return 0 otherwise.
#
N7::remote::ansible::check_status() {
    local changed
    changed=$(python -c '
import sys, json
#FIXME: handle single line name=value pairs
with open(sys.argv[1]) as f:
    data = json.load(f)
if data.get("changed"):
    print 1
if "failed" in data:
    sys.exit(1)
'    "$N7_ANSIBLE_OUT"
    )
    local rc=$?
    if [ "$changed" = 1 ]; then N7::remote::tasks::touch_change; fi
    return $rc
}

