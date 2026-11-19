open Base
open Stdio
open Common

let mergetool =
  let setup update_git_config echo merge_fmt_path =
    let merge_fmt_path = Option.value ~default:"merge-fmt" merge_fmt_path in
    let commands =
      [ sprintf
          "git config --local mergetool.mergefmt.cmd '%s mergetool \
           --base=\"$BASE\" --current=\"$LOCAL\" --other=\"$REMOTE\" -o \
           \"$MERGED\" --name=\"$MERGED\"'"
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

let jj_mergetool =
  let setup update_jj_config echo merge_fmt_path =
    let merge_fmt_path = Option.value ~default:"merge-fmt" merge_fmt_path in
    let commands =
      [ sprintf "jj config set --repo merge-tools.merge-fmt.program %s"
          (Stdlib.Filename.quote (sprintf "%S" merge_fmt_path))
      ; "jj config set --repo merge-tools.merge-fmt.merge-args \
         '[\"mergetool\", \"--base=$base\", \"--current=$left\", \
         \"--other=$right\", \"-o\", \"$output\", \"--name=$path\", \
         \"--diff3\"]'"
        (* When there are conflicts, merge-fmt exits with 1 and writes the
           conflict markers to the output. jj only reads them back when they
           contain the base, hence [--diff3] above. *)
      ; "jj config set --repo merge-tools.merge-fmt.merge-conflict-exit-codes \
         '[1]'"
      ]
    in
    List.iter commands ~f:(fun line ->
        if update_jj_config
        then system_respect_exit ~echo "%s" line
        else Out_channel.printf "%s\n%!" line)
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
