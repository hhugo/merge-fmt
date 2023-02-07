open Base
open Stdio
open Common

let mergetool =
  let setup update_git_config echo merge_fmt_path =
    let merge_fmt_path = Option.value ~default:"merge-fmt" merge_fmt_path in
    let commands =
      [ sprintf
          "git config --local mergetool.mergefmt.cmd '%s mergetool \
           --base=$BASE --current=$LOCAL --other=$REMOTE -o $MERGED'"
          merge_fmt_path
      ; "git config --local mergetool.mergefmt.trustExitCode true"
      ]
    in
    List.iter commands ~f:(fun line ->
        if update_git_config
        then system_respect_exit ~echo "%s" line
        else Out_channel.printf "%s\n%!" line)
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
    let commands =
      [ sprintf "git config --local merge.mergefmt.name 'merge-fmt driver'"
      ; sprintf
          "git config --local merge.mergefmt.driver '%s mergetool --base=%%O \
           --current=%%A --other=%%B -o %%A --name=%%P'"
          merge_fmt_path
      ; sprintf "git config --local merge.tool 'mergefmt'"
      ; sprintf "git config --local merge.default 'mergefmt'"
      ]
    in
    List.iter commands ~f:(fun line ->
        if update_git_config
        then system_respect_exit ~echo "%s" line
        else Out_channel.printf "%s\n%!" line)
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
