open Base
open Stdio
open Common

(* An argument of a command. Both are passed verbatim to the command, [Q]
   ones are quoted when the command is printed. *)
type arg =
  | A of string
  | Q of string

(* Commands are printed for a POSIX shell. *)
let print_command (prog, args) =
  let quote s =
    "'" ^ String.substr_replace_all s ~pattern:"'" ~with_:"'\\''" ^ "'"
  in
  prog :: List.map args ~f:(function A s -> s | Q s -> quote s)
  |> String.concat ~sep:" "
  |> Out_channel.printf "%s\n%!"

(* Commands are run by the shell of the system, which is not a POSIX one on
   Windows. *)
let run_command ~echo (prog, args) =
  system_respect_exit ~echo "%s"
    (Stdlib.Filename.quote_command prog
       (List.map args ~f:(function A s | Q s -> s)))

let setup_commands ~update ~echo commands =
  List.iter commands ~f:(if update then run_command ~echo else print_command)

let mergetool =
  let setup update_git_config echo merge_fmt_path =
    let merge_fmt_path = Option.value ~default:"merge-fmt" merge_fmt_path in
    setup_commands ~update:update_git_config ~echo
      [ ( "git"
        , [ A "config"
          ; A "--local"
          ; A "mergetool.mergefmt.cmd"
          ; Q
              (sprintf
                 {|%s mergetool --base="$BASE" --current="$LOCAL" --other="$REMOTE" -o "$MERGED" --name="$MERGED"|}
                 merge_fmt_path)
          ] )
      ; ( "git"
        , [ A "config"
          ; A "--local"
          ; A "mergetool.mergefmt.trustExitCode"
          ; A "true"
          ] )
      ]
  in
  let open Cmdliner in
  let merge_fmt_path =
    let doc = "Path of merge-fmt." in
    Arg.(value & opt (some string) None & info [ "merge-fmt-path" ] ~doc)
  in
  let update_git_config =
    let doc =
      "Update the git config of the current repository. Just output commands \
       otherwise."
    in
    Arg.(value & flag & info [ "update" ] ~doc)
  in
  let doc = "Register the [merge-fmt] mergetool in git" in
  let term =
    Term.(const setup $ update_git_config $ Flags.echo $ merge_fmt_path)
  in
  Cmd.v (Cmd.info ~doc "setup-mergetool") term

let merge =
  let setup update_git_config echo merge_fmt_path =
    let merge_fmt_path = Option.value ~default:"merge-fmt" merge_fmt_path in
    let git_config key value =
      ("git", [ A "config"; A "--local"; A key; Q value ])
    in
    setup_commands ~update:update_git_config ~echo
      [ git_config "merge.mergefmt.name" "merge-fmt driver"
      ; git_config "merge.mergefmt.driver"
          (sprintf
             "%s mergetool --base=%%O --current=%%A --other=%%B -o %%A \
              --name=%%P"
             merge_fmt_path)
      ; git_config "merge.tool" "mergefmt"
      ; git_config "merge.default" "mergefmt"
      ]
  in
  let open Cmdliner in
  let merge_fmt_path =
    let doc = "Path of merge-fmt." in
    Arg.(value & opt (some string) None & info [ "merge-fmt-path" ] ~doc)
  in
  let update_git_config =
    let doc =
      "Update the git config of the current repository. Just output commands \
       otherwise."
    in
    Arg.(value & flag & info [ "update" ] ~doc)
  in
  let doc =
    "Register the [merge-fmt] mergetool as the default merge driver in git"
  in
  let term =
    Term.(const setup $ update_git_config $ Flags.echo $ merge_fmt_path)
  in
  Cmd.v (Cmd.info ~doc "setup-merge") term

let jj_mergetool =
  let setup update_jj_config echo merge_fmt_path =
    let merge_fmt_path = Option.value ~default:"merge-fmt" merge_fmt_path in
    let jj_config key value =
      ("jj", [ A "config"; A "set"; A "--repo"; A key; Q value ])
    in
    setup_commands ~update:update_jj_config ~echo
      [ jj_config "merge-tools.merge-fmt.program" (sprintf "%S" merge_fmt_path)
        (* When there are conflicts, merge-fmt exits with 1 and writes the
           conflict markers to the output. jj only reads them back when they
           contain the base, hence [--diff3] below. *)
      ; jj_config "merge-tools.merge-fmt.merge-args"
          {|["mergetool", "--base=$base", "--current=$left", "--other=$right", "-o", "$output", "--name=$path", "--diff3"]|}
      ; jj_config "merge-tools.merge-fmt.merge-conflict-exit-codes" "[1]"
      ]
  in
  let open Cmdliner in
  let merge_fmt_path =
    let doc = "Path of merge-fmt." in
    Arg.(value & opt (some string) None & info [ "merge-fmt-path" ] ~doc)
  in
  let update_jj_config =
    let doc =
      "Update the jj config of the current repository. Just output commands \
       otherwise."
    in
    Arg.(value & flag & info [ "update" ] ~doc)
  in
  let doc = "Register the [merge-fmt] merge tool in jj" in
  let term =
    Term.(const setup $ update_jj_config $ Flags.echo $ merge_fmt_path)
  in
  Cmd.v (Cmd.info ~doc "setup-jj-mergetool") term
