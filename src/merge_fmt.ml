open! Base
open! Stdio
open! Common
open! Cmdliner

let cmds =
  Cmd.group ~default:(fst Resolve_cmd.cmd) (snd Resolve_cmd.cmd)
    [ Merge_cmd.cmd
    ; Setup_cmd.mergetool
    ; Setup_cmd.merge
    ; Setup_cmd.jj_mergetool
    ]

let () =
  (* Like git, do not translate line endings on Windows: the merged file may
     be written to the standard output. *)
  Stdlib.set_binary_mode_out Stdlib.stdout true;
  Stdlib.set_binary_mode_out Stdlib.stderr true;
  Stdlib.exit (Cmdliner.Cmd.eval cmds)
