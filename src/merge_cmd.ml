open Base
open Stdio
open Common

let debug_oc =
  lazy
    (Out_channel.create ~append:true
       (Stdlib.Filename.concat
          (Stdlib.Filename.get_temp_dir_name ())
          "merge-fmt.log"))

let debug fmt =
  if true
  then Printf.ksprintf (fun _ -> ()) fmt
  else Printf.ksprintf (Out_channel.fprintf (Lazy.force debug_oc) "%s") fmt

(* Merge with [git merge-file] and write the result to [output]. It exits
   with the number of conflicts, or with a larger value on error. When there
   are conflicts, the result is still written: it contains the conflict
   markers. On error, there is no result and the output is left untouched. *)
let merge_file ~echo ~diff3 ~labels:(current_label, base_label, other_label)
    ~current ~base ~other ~output =
  let result, code =
    open_process_in_status ~echo
      "git merge-file -p%s -L %s -L %s -L %s %s %s %s"
      (if diff3 then " --diff3" else "")
      (Stdlib.Filename.quote current_label)
      (Stdlib.Filename.quote base_label)
      (Stdlib.Filename.quote other_label)
      (Stdlib.Filename.quote current)
      (Stdlib.Filename.quote base)
      (Stdlib.Filename.quote other)
  in
  if code < 0 || code > 127
  then Stdlib.exit code
  else (
    (match output with
    | None -> Out_channel.output_string stdout result
    | Some o -> (
        try Out_channel.write_all o ~data:result
        with Sys_error msg ->
          eprintf "merge-fmt: cannot write the result: %s\n%!" msg;
          Stdlib.exit 2));
    Stdlib.exit (if code = 0 then 0 else 1))

(* The closest parent directory that is the root of a repository. *)
let rec find_root dir =
  if
    List.exists [ ".jj"; ".git" ] ~f:(fun marker ->
        Stdlib.Sys.file_exists (Stdlib.Filename.concat dir marker))
  then Some dir
  else
    let parent = Stdlib.Filename.dirname dir in
    if String.equal parent dir then None else find_root parent

(* [name] is the path of the merged file in the repository: when relative, it
   is relative to the root of the repository, not to the current directory. *)
let resolve_name name =
  if not (Stdlib.Filename.is_relative name)
  then name
  else
    match find_root (Stdlib.Sys.getcwd ()) with
    | Some root -> Stdlib.Filename.concat root name
    | None -> name

let merge config echo current base other output name diff3 =
  match (current, base, other) with
  | (None | Some ""), _, _ | _, (None | Some ""), _ | _, _, (None | Some "") ->
      Stdlib.exit 1
  | Some current, Some base, Some other -> (
      let display_name = Option.value name ~default:current in
      let name =
        Some (Option.value_map name ~default:current ~f:resolve_name)
      in
      (* The files may be formatted into temporary files: keep the names of
         the original ones in the conflict markers. *)
      let labels = (current, base, other) in
      match Fmters.find ~config ~filename:current ~name with
      | None ->
          debug "Couldn't find a formatter for %s\n%!" current;
          merge_file ~echo ~diff3 ~labels ~current ~base ~other ~output
      | Some formatter -> (
          let format filename =
            Fmters.format_to_file formatter ~echo ~filename
          in
          let x = Result.map_error (format current) ~f:(Fn.const "current")
          and y = Result.map_error (format other) ~f:(Fn.const "other")
          and z = Result.map_error (format base) ~f:(Fn.const "base") in
          match Result.combine_errors [ x; y; z ] with
          | Ok ([ current; other; base ] : string list) ->
              debug "process all three revision successfully\n%!";
              debug "running git merge-file\n%!";
              merge_file ~echo ~diff3 ~labels ~current ~base ~other ~output
          | Ok _ -> assert false
          | Error failed ->
              (* Do what would be done without merge-fmt, rather than failing
                 a merge that might not even conflict. *)
              eprintf
                "merge-fmt: failed to format %s (%s), merging without formatting\n\
                 %!"
                display_name
                (String.concat ~sep:", " failed);
              merge_file ~echo ~diff3 ~labels ~current ~base ~other ~output))

open Cmdliner

let cmd =
  let current =
    let doc = "" in
    Arg.(
      value
      & opt (some file) None
      & info [ "current" ] ~docv:"<current-file>" ~doc)
  in
  let base =
    let doc = "" in
    Arg.(
      value & opt (some file) None & info [ "base" ] ~docv:"<base-file>" ~doc)
  in
  let other =
    let doc = "" in
    Arg.(
      value & opt (some file) None & info [ "other" ] ~docv:"<other-file>" ~doc)
  in
  let output =
    let doc =
      "File the merged result is written to. It is created when it does not \
       exist. Without this option, the result is written to the standard \
       output."
    in
    Arg.(value & opt (some string) None & info [ "o" ] ~docv:"<output-to>" ~doc)
  in
  let result_name =
    let doc =
      "pathname in which the merged result will be stored. When relative, it \
       is relative to the root of the repository."
    in
    Arg.(
      value
      & opt (some string) None
      & info [ "name" ] ~docv:"<result-name>" ~doc)
  in
  let diff3 =
    let doc =
      "Show conflicts in diff3 style: the conflict markers also contain the \
       content of the base."
    in
    Arg.(value & flag & info [ "diff3" ] ~doc)
  in
  let doc = "git mergetool" in
  let term =
    Term.(
      const merge $ Fmters.Flags.t $ Flags.echo $ current $ base $ other
      $ output $ result_name $ diff3)
  in
  Cmd.v (Cmd.info ~doc "mergetool") term
