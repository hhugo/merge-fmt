open! Base
open! Stdio
open! Common
open! Cmdliner

let cmds = [ Merge_cmd.cmd; Setup_cmd.mergetool; Setup_cmd.merge ]

let () = Cmdliner.Term.exit (Cmdliner.Term.eval_choice Resolve_cmd.cmd cmds)
