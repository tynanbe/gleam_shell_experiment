//// TODO:
//// "$HOME/.gleam/gleam_shell/build/dev/erlang/gleam_shell/ebin"
//// gleam shell runs gleam new when not in project ???
//// gleam build && ESCRIPT_NAME="gleam shell" erl -pa "build/dev/erlang/gleam_shell_experiment/ebin" "build/dev/erlang/gleam_otp/ebin" "build/dev/erlang/gleam_erlang/ebin" "build/dev/erlang/gleeunit/ebin" "build/dev/erlang/gleam_stdlib/ebin" "." -stdlib shell_strings false -noshell -noinput -s "gleam_shell_boot"
//// boot gleam@@main ???
//// code:purge(gleam_shell_experiment) -> Bool
//// code:load_file(gleam_shell_experiment) -> Module(Atom) | Error(NotPurged)
//// gleam@io:debug("one"), nil. and remove nil

import gleam/erlang
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{Some}
import gleam/otp/actor
import gleam/otp/process.{Pid, Sender}
import gleam/otp/supervisor
import gleam/result
import gleam/string
import gleam/string_builder.{StringBuilder}

pub const pink = #(255, 175, 243)

type Interface {
  Interface(channel: Sender(Message))
}

type Session {
  Session(channel: Sender(Message), head: StringBuilder, foot: StringBuilder)
}

type Message {
  Compile(channel: Sender(Message))
  Compilation(result: Result(String, #(Int, String)))
  Input(channel: Sender(Message), line: String)
  Output(result: Result(String, String))
}

pub type ShellError {
  ShellError
}

pub fn main() {
  let compiler_actor =
    supervisor.worker(fn(_argument) {
      actor.Spec(
        init: fn() {
          let #(_channel, inbox) = process.new_channel()
          actor.Ready(state: Nil, receiver: Some(inbox))
        },
        init_timeout: 60_000,
        loop: fn(message, compiler) {
          case message {
            Compile(channel: channel) -> {
              command(run: "gleam", with: ["check"], in: ".")
              |> Compilation
              |> process.send(channel, _)
              compiler
            }
            _ -> compiler
          }
          |> actor.Continue
        },
      )
      |> actor.start_spec
    })
    |> supervisor.returning(fn(_argument, compiler_channel) { compiler_channel })

  let session_actor =
    supervisor.worker(fn(compiler_channel) {
      actor.Spec(
        init: fn() {
          let #(channel, inbox) = process.new_channel()
          Session(
            channel: channel,
            head: string_builder.from_string(""),
            foot: string_builder.from_string(""),
          )
          |> actor.Ready(receiver: Some(inbox))
        },
        init_timeout: 60_000,
        loop: fn(message, session: Session) {
          case message {
            Input(channel: channel, line: line) -> {
              // TODO: write to module
              let compilation_result =
                fn(channel) { Compile(channel: channel) }
                |> process.try_call(compiler_channel, _, 300_000)
              case compilation_result {
                Ok(Compilation(_)) -> {
                  line
                  |> Ok
                  |> Output
                  |> process.send(channel, _)
                  Session(
                    ..session,
                    foot: string_builder.append(to: session.foot, suffix: line),
                  )
                }
                _ -> {
                  // TODO: handle error
                  line
                  |> Ok
                  |> Output
                  |> process.send(channel, _)
                  session
                }
              }
            }
            _ -> session
          }
          |> actor.Continue
        },
      )
      |> actor.start_spec
    })
    |> supervisor.returning(fn(_argument, session_channel) { session_channel })

  let interface_actor =
    supervisor.worker(fn(session_channel) {
      actor.Spec(
        init: fn() {
          let #(channel, inbox) = process.new_channel()
          Interface(channel: channel)
          |> actor.Ready(receiver: Some(inbox))
        },
        init_timeout: 60_000,
        loop: fn(message, interface: Interface) {
          case message {
            Output(Ok(line)) ->
              case line == "\n" {
                False -> io.print(line)
                True -> Nil
              }
            Output(Error(error)) -> io.print(error)
            _ -> Nil
          }
          let line =
            "> "
            |> erlang.get_line
            |> result.unwrap(or: "\n")
          Input(channel: interface.channel, line: line)
          |> process.send(session_channel, _)
          actor.Continue(interface)
        },
      )
      |> actor.start_spec
    })
    |> supervisor.returning(fn(_argument, interface_channel) {
      "gleam 0.20.0-dev"
      |> string.replace(each: "gleam", with: color("Gleam", rgb: pink))
      |> string.append(suffix: color(
        "  (^C twice to quit)\n",
        rgb: #(158, 158, 158),
      ))
      |> Ok
      |> Output
      |> process.send(interface_channel, _)
    })

  supervisor.Spec(
    argument: Nil,
    frequency_period: 1,
    max_frequency: 5,
    init: fn(children) {
      children
      |> supervisor.add(compiler_actor)
      |> supervisor.add(session_actor)
      |> supervisor.add(interface_actor)
    },
  )
  |> supervisor.start_spec

  erlang.sleep_forever()
}

pub fn color(string: String, rgb color: #(Int, Int, Int)) -> String {
  let prepare = fn(int) {
    case int {
      int if int < 0 -> 0
      int if int > 255 -> 255
      _ -> int
    }
    |> int.to_string
  }

  let #(red, green, blue) = color

  string.concat([
    "\e[38;2;",
    prepare(red),
    ";",
    prepare(green),
    ";",
    prepare(blue),
    "m",
    string,
    "\e[0m",
  ])
}

pub fn start() {
  spawn(main)
}

external fn spawn(fn() -> a) -> Pid =
  "erlang" "spawn"

external fn command(
  run: String,
  with: List(String),
  in: String,
) -> Result(String, #(Int, String)) =
  "gleam_shell_ffi" "command"
