open Base
open Stdio
open Common

type version =
  | Common
  | Theirs
  | Ours

let string_of_version = function
  | Common -> "common"
  | Theirs -> "theirs"
  | Ours -> "ours"

type rev = Object of string

type versions =
  { common : rev
  ; theirs : rev
  ; ours : rev
  }

let conflict ~filename =
  In_channel.with_file filename ~f:(fun ic ->
      let rec loop n =
        match In_channel.input_line ic with
        | None -> n
        | Some line ->
            if String.is_prefix ~prefix:"<<<<<<<" line
            then loop (Int.succ n)
            else loop n
      in
      loop 0)

(* [git ls-files -u -z] outputs a sequence of
   [<mode> <object> <stage>\t<file>\000]. With [-z], file names are output
   verbatim: they can contain any character but the null one.

   [git ls-files] only lists the files below the current directory: [:/]
   stands for the root of the repository. File names are relative to the
   current directory. *)
let ls ~echo () =
  let ic = open_process_in ~echo "git ls-files -u -z -- :/" in
  let entries =
    In_channel.input_all ic |> String.split ~on:'\000'
    |> List.filter ~f:(fun entry -> not (String.is_empty entry))
    |> List.map ~f:(fun entry ->
        match String.lsplit2 entry ~on:'\t' with
        | None -> failwith "unexpected format"
        | Some (info, file) -> (
            match String.split info ~on:' ' with
            | [ _; id; num ] -> (file, (Int.of_string num, id))
            | _ -> failwith "unexpected format"))
  in
  let map = Map.of_alist_multi (module String) entries in
  Map.map map ~f:(fun l ->
      let l = List.sort l ~compare:(Comparable.lift ~f:fst Int.compare) in
      match l with
      | [ (1, common); (2, ours); (3, theirs) ] ->
          Ok
            { common = Object common
            ; ours = Object ours
            ; theirs = Object theirs
            }
      | _ -> Error "not a 3-way merge")

let show ~echo version versions =
  let obj =
    match version with
    | Ours -> versions.ours
    | Theirs -> versions.theirs
    | Common -> versions.common
  in
  match obj with
  | Object obj -> (
      match
        open_process_in_status ~echo "git show %s" (Stdlib.Filename.quote obj)
      with
      | content, 0 -> content
      | _ ->
          eprintf "Failed to read object %s\n%!" obj;
          Stdlib.exit 1)

(* The name used to refer to a version of [fn], in conflict markers for
   instance. *)
let label fn version =
  let ext = Stdlib.Filename.extension fn in
  let base =
    if String.equal ext "" then fn else Stdlib.Filename.chop_extension fn
  in
  sprintf "%s.%s%s" base (string_of_version version) ext

(* Versions are written to temporary files, outside of the working tree. *)
let create_tmp ~echo fn version versions =
  let content = show ~echo version versions in
  let tmp =
    Stdlib.Filename.temp_file
      (sprintf "merge-fmt-%s-" (string_of_version version))
      (Stdlib.Filename.extension fn)
  in
  Out_channel.write_all tmp ~data:content;
  tmp

(* [git merge-file] exits with the number of conflicts, or with a larger value
   on error. When there are conflicts, the result is still written: it
   contains the conflict markers. On error, [filename] is left untouched. *)
let merge ~echo ~filename ~ours ~common ~theirs =
  let result, code =
    open_process_in_status ~echo "git merge-file -p -L %s -L %s -L %s %s %s %s"
      (Stdlib.Filename.quote (label filename Ours))
      (Stdlib.Filename.quote (label filename Common))
      (Stdlib.Filename.quote (label filename Theirs))
      (Stdlib.Filename.quote ours)
      (Stdlib.Filename.quote common)
      (Stdlib.Filename.quote theirs)
  in
  if code < 0 || code > 127
  then Error ()
  else (
    Out_channel.write_all filename ~data:result;
    if code = 0 then Ok () else Error ())

let git_add ~echo ~filename =
  system ~echo "git add -- %s" (Stdlib.Filename.quote filename)

let fix ~echo ~filename ~versions ~formatter =
  let ours = create_tmp ~echo filename Ours versions in
  let theirs = create_tmp ~echo filename Theirs versions in
  let common = create_tmp ~echo filename Common versions in
  Exn.protect
    ~finally:(fun () -> List.iter [ ours; theirs; common ] ~f:Unix.unlink)
    ~f:(fun () ->
      let format version tmp =
        Fmters.run (formatter tmp) ~echo ~filename:tmp
        |> Result.map_error ~f:(Fn.const (label filename version))
      in
      let x = format Ours ours
      and y = format Theirs theirs
      and z = format Common common in
      match Result.combine_errors_unit [ x; y; z ] with
      | Error l ->
          eprintf "Failed to format %s\n%!" (String.concat ~sep:", " l);
          Error ()
      | Ok () -> merge ~echo ~filename ~ours ~theirs ~common)

let resolve config echo () =
  let all = ls ~echo () in
  if Map.is_empty all
  then (
    eprintf "Nothing to resolve\n%!";
    Stdlib.exit 1);
  Map.iteri all ~f:(fun ~key:filename ~data:versions ->
      match versions with
      | Ok _ when not (Stdlib.Sys.file_exists filename) ->
          eprintf "Ignore %s (missing from the working tree)\n%!" filename
      | Ok versions -> (
          (* The versions are formatted from temporary files: tell the
             formatter which file they are. *)
          match Fmters.find ~config ~filename ~name:(Some filename) with
          | Some formatter ->
              let n1 = conflict ~filename in
              Result.bind (fix ~echo ~filename ~versions ~formatter)
                ~f:(fun () -> git_add ~echo ~filename)
              |> (ignore : (unit, unit) Result.t -> unit);
              let n2 = conflict ~filename in
              if n2 > n1
              then eprintf "Resolved ?? %s\n%!" filename
              else eprintf "Resolved %d/%d %s\n%!" (n1 - n2) n1 filename
          | None -> eprintf "Ignore %s (no formatter register)\n%!" filename)
      | Error reason -> eprintf "Ignore %s (%s)\n%!" filename reason);
  let all = ls ~echo () in
  if Map.is_empty all then Stdlib.exit 0 else Stdlib.exit 1

open Cmdliner

let cmd =
  let doc = "Try to automatically resolve conflicts due to code formatting" in
  ( Term.(const resolve $ Fmters.Flags.t $ Flags.echo $ const ())
  , Cmd.info ~doc "merge-fmt" )
