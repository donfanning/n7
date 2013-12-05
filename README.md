N7 - Ad Hoc Task Automation and Orchestration in Bash.
-------------------------------------------------------

Requires OpenSSH and GNU coreutils.

At start up, N7 sources your `.n7` bash script, which defines [tasks](#Tasks)
to be executed. Then N7 simply runs `ssh $N7_SSH_OPTS <host>`, with some I/O
redirections, to connect to each host at startup. It then sends commands to
the hosts via named pipes. All remote outputs(to stdout and stderr) are
redirected to local files. To configure how N7 uses SSH, you can set or add
your ssh options to `N7_SSH_OPTS` or you can do it in your ssh config file.

N7 automatically writes, to stdout, an End-Of-Task marker on the remote
end at the end of each task, to signal the end of the task and to delimit
the outputs from previous task. An implication of this is that if a task
starts a background process then you need to redirect its stdout or make
sure it doesn't write to the stdout; otherwise, it could interfere with the
next task, causing it to be timed out.

Moreover, N7 assumes there will be no user interactions. This means:

    1. You can ssh into your host without needing to enter a password.

    2. Your remote tasks won't be reading from SSH's stdin.

       In fact, N7 redirects stdin to /dev/null for any remote task
       running in a subshell. However, since N7 also allows a task to run
       directly in the login shell, in which the stdin is connected
       to SSH's stdin for reading command from N7, reading from stdin
       will interfere with the communication between N7 and SSH.


Tasks
------
A task is defined as a bash function whose name starts with the `.`(dot)
prefix. Example:

        .hello() { echo "hello"; }

A task may be executed remotely on all hosts in parallel or locally on
`localhost`. When defining a task, task specific [options](#Task Options) may
be given as shell null commands(`:`) at the beginning of the task before
the first non-null shell command. Comments are allowed. Example:

        .mytask() {
            # These are task options:
            : DESCRIPTION="An example task."
            : TIMEOUT=10
            pwd
            whoami
            ls -la
            df -H            
        }

By default a task is a remote task unless the `LOCAL` task option is set.
A remote task by default runs in a subshell on each remote host unless the
`NO_SUBSHELL` task option is set, and by default a task that exits with a
non-zero status is considered a failed task, unless the `IGNORE_STATUS` task
option is set, and N7 will then not execute any subsequent tasks on the host
that failed the task.

A local task has no timeout and is always executed in a subshell of the N7
process(ie, `TIMEOUT` and `NO_SUBSHELL` have no effects on local tasks), and
therefore has read access to all N7's [environment variables](#N7 Environment Variables)
and can call N7's [built-in](#N7 Built-In Functions) functions. 

All tasks will be automatically defined on remote hosts, but since a remote task
may need to call some helper functions defined in the `.n7` script, we need to
tell N7 to also define those helper functions remotely for us. This can be done
by calling the `N7::func::tasks::send_funcs` function from a local task. Example:

        .init() {
            : LOCAL=1
            N7::func::tasks::send_funcs helper_1 helper_2
        }
        .my_task() {
            helper_1
            echo "working..."
            helper_2
        }
        helper_1() { echo "my helper func"; }
        helper_2() { echo "my helper func"; }



Task Options
-------------
<table>
<tr><th align=left valign=top>DESCRIPTION</th><td>describe what the task does.</td></tr>
<tr><th align=left valign=top>TIMEOUT</th><td>timeout in seconds for the remote task.</td></tr>
<tr><th align=left valign=top>NO_SUBSHELL</th>
    <td>set it to run the remote task directly in the N7 login shell.</td></tr>
<tr><th align=left valign=top>LOCAL</th>
    <td>set it to run the task locally; otherwise a task is a remote task by default.</td></tr>
<tr><th align=left valign=top>IGNORE_STATUS</th>
    <td>set it to run the remaining tasks even if the task exited with a non-zero exit status. </td></tr>
</table>


N7 Environment Variables
-------------------------
WIP!, check out the source!

 - `N7_DIR`
 - `N7_SCRIPT`
 - `N7_HOSTS`
 - `N7_EHOSTS`
 - `N7_SSH_OPTS`
 - `N7_RUN_DIR`
 - `N7_TASK_TIMEOUT`


N7 Built-In Functions
----------------------
WIP!, check out the source!

 - `N7::func::tasks::send_funcs`
 - `N7::func::tasks::send_env_vars`
 - `N7::func::tasks::get_stdout`
 - `N7::func::tasks::get_stderr`
 - `N7::func::files::scp`




