N7 - Ad Hoc Task Automation and Orchestration in Bash.
-------------------------------------------------------
**WARNING**
This is a work in progress and is still at very early stage of development.
Things may break, or change. Use at your own risk! Contributions or suggestions
are welcome :) Got questions? Open a GitHub issue or send me an email.

Introduction
-------------

<pre>
$ n7 -h
Usage: n7 [options] [cmd1 cmd2 ...]

Each command, if provided, will be run as a N7 task with default task options.

Options:
  -h          Show this help. 

  -m HOSTS    A list of comma separated hosts. Hosts will be read from
              STDIN(one host per line) if the -m option is not specified.

  -s FILE     Source and execute tasks in FILE after running the commands
              specified on the command line.

  -v LEVEL    Set the verbose level. Defaults to INFO.
              Levels available: DEBUG INFO WARNING ERROR FATAL

  -o          Show task stdout at end of the task from each host.
              Local and command-line task outputs are always shown unless you
              redirect them in the task.

  -k          Keep the run directory after execution. The run directory, which
              is unique to each n7 invocation, stores the runtime files such as
              stdout and stderr files from each remote host, etc.

  -p COUNT    Limit the number of parallel SSH processes to COUNT at a time.
               
</pre>


Features
---------
  - It's just Bash. It should run anywhere with Bash + GNU Coreutils + OpenSSH.

  - Use it as a SSH-in-a-loop for running commands over multiple hosts in
    parallel.

  - Write your tasks as Bash functions, do whatever you want.

  - Give you just enough building blocks and then get out of your way.


What it doesn't do
-------------------
  - It doesn't group hosts into roles and let you refer to groups of hosts via
    pattern matching on role or host names. Such fucntionality can be easily
    wrapped in an external script. Eg, Suppose there's a `hosts` script that
    takes a role name and outputs a list of hostnames with that role. Then 

            hosts api | n7 -v -s ./do-something.n7

    will execute all tasks defined in the N7 script on all api hosts. If you
    need to do some orchestration, then it's easy to write another script that
    calls out to n7 with different sets of hosts at each step.

  - It doesn't provide idempotent tasks. However, you can easily reuse Ansible's
    [modules](http://ansibleworks.com/docs/modules.html) in your N7 local tasks.
    Better integration with Ansible's modules is planned.


Example runs
--------------

<pre>
$ n7 -m example.host.com uptime 'df -H'

2013-12-09T16:14:00-0500|N7|jkuan|INFO Run id=9299_1386623640 -- N7_DIR=/tmp/n7
2013-12-09T16:14:00-0500|N7|jkuan|INFO Running Task #0: .N7::cli_task::0 ...
 16:14:00 up 25 days, 23:52,  0 users,  load average: 0.09, 0.18, 0.18
267f10f4bcdacc613859233b3ef675ef example.host.com 0 0
2013-12-09T16:14:01-0500|N7|jkuan|INFO Running Task #1: .N7::cli_task::1 ...
Filesystem      Size  Used Avail Use% Mounted on
/dev/xvda1      8.5G  4.7G  3.4G  59% /
udev            3.9G   13k  3.9G   1% /dev
tmpfs           1.6G  201k  1.6G   1% /run
none            5.3M     0  5.3M   0% /run/lock
none            4.0G  4.1k  4.0G   1% /run/shm
/dev/xvdb       444G  1.9G  420G   1% /mnt
267f10f4bcdacc613859233b3ef675ef example.host.com 1 0
</pre>


Installation
-------------
N7 is developed against Bash version 4.2, though it should work with any Bash
version >= 4. Additionally, it requires OpenSSH and GNU coreutils, which should
be already installed if you are running Linux.

On Mac, you can install GNU coreutils using Homebrew. However, N7 expects the
tools to be without the g-prefix. Specifically, the dependency on GNU coreutils
applies to the `tail`, `sleep` and probably `grep` utilites.


How it works
-------------
At start up, N7 sources your `.n7` bash script, which defines [tasks](#tasks)
to be executed. Then N7 simply runs `ssh $N7_SSH_OPTS <host>`, with some I/O
redirections, to connect to each host at startup. It then sends commands to
the hosts via named pipes. All remote outputs(to stdout and stderr) are
redirected to local files. To configure how N7 uses SSH, you can set or add
your ssh options to `N7_SSH_OPTS` or you can do it in your ssh config file.

N7 automatically writes an End-Of-Task marker to stdout and stderr on the
remote end at the end of each task, to signal the end of the task and to
delimit the outputs from previous task. An implication of this is that if a
task starts a background process then you need to redirect its stdout or make
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
`localhost`. When defining a task, task specific [options](#task-options) may
be given as shell null commands(`:`) at the beginning of the task before
the first non-null shell command. Comments are allowed. Example:

        .mytask() {
            # These are task options:
            : DESCRIPTION="An example task."
            : TIMEOUT=10; set -e
            pwd
            whoami
            ls -la
            df -H            
        }

By default a task is a local task. Setting `LOCAL` or `REMOTE` will change its
type, and without both it defaults to `N7_DEFAULT_TASK_TYPE`, which can be set
also in your script. 

A task by default runs in a subshell unless the `NO_SUBSHELL` task option is set,
and by default a task that returns a non-zero status is considered a failed task,
unless the `IGNORE_STATUS` task option is set, and N7 will then not execute any
subsequent tasks on the host that failed the task.

A local task has no timeout(ie, `TIMEOUT` has no effects on local tasks), and
therefore has read access to all N7's [functions](#n7-built-in-functions),
global variables, and [environment variables](#n7-environment-variables).

All remote tasks will be automatically defined on remote hosts, but since a remote
task may need to call some helper functions defined in the `.n7` script, we need to
tell N7 to also define those helper functions remotely for us. This can be done in
two ways:

    1. By defining the fucntions in a remote task. Example:
        .init() { REMOTE=1
            helper_1() { echo "my helper func"; }  
            helper_2() { echo "my helper func"; }
        }

    2. By calling the `N7::func::tasks::send_funcs` function from a local task. Example:

        .init() {
            set -e
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
TBD


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
 - ...


N7 Built-In Functions
----------------------
WIP!, check out the source!

 - `N7::func::tasks::send_funcs`
 - `N7::func::tasks::send_env`
 - `N7::func::tasks::get_stdout`
 - `N7::func::tasks::get_stderr`
 - `N7::func::files::cp`
 - `N7::func::files::cp_tpl`
 - `N7::func::files::scp`
 - ...



