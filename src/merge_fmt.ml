open! Base
open! Stdio
open! Common
open! Cmdliner

let cmds =
  Cmd.group ~default:(fst Resolve_cmd.cmd) (snd Resolve_cmd.cmd)
    [ Merge_cmd.cmd; Setup_cmd.mergetool; Setup_cmd.merge ]

let () = Stdlib.exit (Cmdliner.Cmd.eval cmds)
