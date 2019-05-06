open Base
open Stdio

let sprintf = Printf.sprintf

let open_process_in ~echo fmt =
  Printf.ksprintf
    (fun s ->
      if echo then eprintf "+ %s\n%!" s;
      Unix.open_process_in s )
    fmt

let open_process_in_respect_exit ~echo fmt =
  Printf.ksprintf
    (fun s ->
      if echo then eprintf "+ %s\n%!" s;
      let ic = Unix.open_process_in s in
      let contents = In_channel.input_all ic in
      match Unix.close_process_in ic with
      | WEXITED 0 -> contents
      | WEXITED n -> Caml.exit n
      | WSIGNALED _ | WSTOPPED _ -> Caml.exit 1 )
    fmt

let system ~echo fmt =
  Printf.ksprintf
    (fun s ->
      if echo then eprintf "+ %s\n%!" s;
      match Unix.system s with WEXITED 0 -> Ok () | _ -> Error () )
    fmt

let system_respect_exit ~echo fmt =
  Printf.ksprintf
    (fun s ->
      if echo then eprintf "+ %s\n%!" s;
      match Unix.system s with
      | WEXITED 0 -> ()
      | WEXITED n -> Caml.exit n
      | WSIGNALED _ | WSTOPPED _ -> Caml.exit 1 )
    fmt

module Flags = struct
  open Cmdliner

  let echo =
    let doc = "Echo all commands." in
    Arg.(value & flag & info [ "echo" ] ~doc)
end
