# gleam_shell_experiment

A Gleam project exploring one method of creating a shell, or REPL, for Gleam's Erlang target.

## Quick start

```sh
gleam run   # Run the project
gleam test  # Run the tests
gleam shell # Run an Erlang shell

# run the experiment
> git clone https://github.com/tynanbe/gleam_shell_experiment.git
> cd gleam_shell_experiment
> gleam build
> ESCRIPT_NAME="gleam shell" \
  erl \
    -pa \
      "build/dev/erlang/gleam_shell_experiment/ebin" \
      "build/dev/erlang/gleam_otp/ebin" \
      "build/dev/erlang/gleam_erlang/ebin" \
      "build/dev/erlang/gleam_stdlib/ebin" \
      "." \
    -stdlib shell_strings false \
    -noshell \
    -noinput \
    -s gleam_shell_boot
```
