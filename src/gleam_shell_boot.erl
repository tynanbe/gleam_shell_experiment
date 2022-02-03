-module(gleam_shell_boot).

-export([start/0]).

start() -> user_drv:start(['tty_sl -c -e', {gleam@shell, start, []}]).
