-module(gleam_shell_ffi).

-export([command/3]).

command(Command, Args, Dir) ->
    CommandChars = erlang:binary_to_list(Command),
    Executable = os:find_executable(CommandChars),
    PortSettings = [{args, Args}, {cd, Dir}, eof, exit_status, hide, in, stderr_to_stdout, stream],
    Port = open_port({spawn_executable, Executable}, PortSettings),
    {ExitCode, Output} = get_data(Port, []),
    case ExitCode of
        0 ->
            {ok, Output};
        _ ->
            {error, {ExitCode, Output}}
    end.

get_data(Port, SoFar) ->
    receive
    {Port, {data, Bytes}} ->
        get_data(Port, [SoFar | Bytes]);
    {Port, eof} ->
        Port ! {self(), close},
        receive
        {Port, closed} ->
            true
        end,
        receive
        {'EXIT',  Port,  _} ->
            ok
        % force context switch
        after 1 ->
            ok
        end,
        ExitCode =
            receive
            {Port, {exit_status, Code}} ->
                Code
        end,
        {ExitCode, lists:flatten(SoFar)}
    end.
