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
  ; ours : rev }

let conflict ~filename =
  In_channel.with_file filename ~f:(fun ic ->
      let rec loop n =
        match In_channel.input_line ic with
        | None -> n
        | Some line ->
            if String.is_prefix ~prefix:"<<<<<<<" line then loop (Int.succ n) else loop n
      in
      loop 0 )

let ls ~echo () =
  let ic = open_process_in ~echo "git ls-files -u" in
  let rec loop acc =
    match In_channel.input_line ic with
    | None -> acc
    | Some line -> (
      match String.split_on_chars ~on:[' '; '\t'] line with
      | [_; id; num; file] -> loop ((file, (Int.of_string num, id)) :: acc)
      | _ -> failwith "unexpected format" )
  in
  let map = Map.of_alist_multi (module String) (loop []) in
  Map.map map ~f:(fun l ->
      let l = List.sort l ~compare:(Comparable.lift ~f:fst Int.compare) in
      match l with
      | [(1, common); (2, ours); (3, theirs)] ->
          Ok {common = Object common; ours = Object ours; theirs = Object theirs}
      | _ -> Error "not a 3-way merge" )

let show ~echo version versions =
  let obj =
    match version with
    | Ours -> versions.ours
    | Theirs -> versions.theirs
    | Common -> versions.common
  in
  match obj with
  | Object obj -> open_process_in ~echo "git show %s" obj |> In_channel.input_all

let create_tmp ~echo fn version versions =
  let content = show ~echo version versions in
  let ext = Caml.Filename.extension fn and base = Caml.Filename.chop_extension fn in
  let fn' = sprintf "%s.%s%s" base (string_of_version version) ext in
  let oc = Out_channel.create fn' in
  Out_channel.output_string oc content;
  Out_channel.close oc;
  fn'

let merge ~echo ~ours ~common ~theirs ~output =
  system ~echo "git merge-file -p %s %s %s > %s" ours common theirs output

let git_add ~echo ~filename = system ~echo "git add %s" filename

let fix ~echo ~filename ~versions ~formatter =
  let ours = create_tmp ~echo filename Ours versions in
  let theirs = create_tmp ~echo filename Theirs versions in
  let common = create_tmp ~echo filename Common versions in
  let x =
    Fmters.run formatter ~echo ~filename:ours |> Result.map_error ~f:(Fn.const ours)
  and y =
    Fmters.run formatter ~echo ~filename:theirs |> Result.map_error ~f:(Fn.const theirs)
  and z =
    Fmters.run formatter ~echo ~filename:common |> Result.map_error ~f:(Fn.const common)
  in
  match Result.combine_errors_unit [x; y; z] with
  | Error l ->
      eprintf "Failed to format %s\n%!" (String.concat ~sep:", " l);
      Error ()
  | Ok () -> (
    match merge ~echo ~ours ~theirs ~common ~output:filename with
    | Error _ -> Error ()
    | Ok () -> Unix.unlink ours; Unix.unlink theirs; Unix.unlink common; Ok () )

let resolve config echo () =
  let all = ls ~echo () in
  if Map.is_empty all
  then (
    eprintf "Nothing to resolve\n%!";
    Caml.exit 1 );
  Map.iteri all ~f:(fun ~key:filename ~data:versions ->
      match versions with
      | Ok versions -> (
        match Fmters.find ~config ~filename ~name:None with
        | Some formatter ->
            let n1 = conflict ~filename in
            Result.bind (fix ~echo ~filename ~versions ~formatter) ~f:(fun () ->
                git_add ~echo ~filename )
            |> (ignore : (unit, unit) Result.t -> unit);
            let n2 = conflict ~filename in
            eprintf "Resolved %d/%d %s\n%!" (n1 - n2) n1 filename
        | None -> eprintf "Ignore %s (no formatter register)\n%!" filename )
      | Error reason -> eprintf "Ignore %s (%s)\n%!" filename reason );
  let all = ls ~echo () in
  if Map.is_empty all then Caml.exit 0 else Caml.exit 1

open Cmdliner

let cmd =
  let doc = "Try to automatically resolve conflicts due to code formatting" in
  ( Term.(const resolve $ Fmters.Flags.t $ Flags.echo $ const ())
  , Term.info ~doc "merge-fmt" )
