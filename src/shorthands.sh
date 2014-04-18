n7_ansmod=N7::local::ansible::run_mod

n7_cp=N7::local::files::cp
_n7_cp_tpl() { $n7_cp "$@" tplcmd=N7::local::files::bash_tpl; }
n7_cp_tpl=_n7_cp_tpl

n7_remote=N7::local::commands::remote
n7_remote_output=N7::local::tasks::get_stdout
n7_file=N7::remote::files::file
