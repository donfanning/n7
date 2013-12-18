.setup() { : REMOTE=1; : NO_SUBSHELL=1
    
    assert_last_stdout() {
        local host output
        for host in $N7_EHOSTS; do
            output=$(N7::local::tasks::get_stdout $host $((N7_TASK_IDX - 1)))
            if [ "$output" != "$1" ]; then
                echo "Failed ${FUNCNAME[1]}(): ${BASH_LINENO[0]}"
                echo "Host: $host"
                echo "Expecting: $1"
                echo "      Got: $output"

            else
                echo "$host: OK"
            fi
        done
    }
    eval "$(declare -f assert_last_stdout | sed -e 's/stdout/stderr/')"


    assert() {
        if [ $? != 0 ]; then
            echo "Failed: ${FUNCNAME[1]}(): ${BASH_LINENO[0]}"
            echo "MSG: $1"
        else
            echo OK
        fi
    }

    assert_eq_str() {
        [ "$1" = "$2" ] && echo OK || {
            echo "Failed: ${FUNCNAME[1]}(): ${BASH_LINENO[0]}"
            echo "$1 != $2"
        }
    }
}
.setup

