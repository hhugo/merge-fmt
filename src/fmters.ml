open Base
open Common

type config =
  { ocamlformat_path : string option
  ; refmt_path : string option
  ; dune_path : string option
  }

type file =
  | Copy
  | Inplace

type t =
  | File of file * string
  | Stdout of string

type formatter = string -> t

let ocamlformat ~bin ~name ~output =
  let command =
    sprintf "%s %s"
      (Option.value ~default:"ocamlformat" bin)
      (Option.value_map ~default:""
         ~f:(fun name -> " --name=" ^ Stdlib.Filename.quote name)
         name)
  in
  File (Copy, sprintf "%s -o %s" command (Stdlib.Filename.quote output))

let refmt ~bin =
  File (Inplace, sprintf "%s --inplace" (Option.value ~default:"refmt" bin))

let dune ~bin =
  Stdout (sprintf "%s format-dune-file --" (Option.value ~default:"dune" bin))

let find ~config ~filename ~name =
  let filename = Option.value ~default:filename name in
  match
    ( Stdlib.Filename.basename filename
    , Stdlib.Filename.extension filename
    , config )
  with
  | _, (".ml" | ".mli"), { ocamlformat_path; _ } ->
      Some (fun output -> ocamlformat ~bin:ocamlformat_path ~name ~output)
  | _, (".re" | ".rei"), { refmt_path; _ } ->
      Some (fun _ -> refmt ~bin:refmt_path)
  | ("dune" | "dune-project" | "dune-workspace"), "", { dune_path; _ } ->
      Some (fun _ -> dune ~bin:dune_path)
  | _ -> None

(* Run a formatter that prints its result, and write it to [output]. This
   can be [filename] itself: it is only written once the formatter is done,
   and only when it succeeds. *)
let run_stdout command ~echo ~filename ~output =
  let ic =
    open_process_in ~echo "%s %s" command (Stdlib.Filename.quote filename)
  in
  let result = Stdio.In_channel.input_all ic in
  match Unix.close_process_in ic with
  | WEXITED 0 ->
      Stdio.Out_channel.write_all output ~data:result;
      Ok ()
  | WEXITED n ->
      Stdlib.Printf.eprintf ">>> Exit with %d\n" n;
      Error ()
  | WSIGNALED _ | WSTOPPED _ -> Error ()

let run t ~echo ~filename =
  match t with
  | File (_, command) ->
      system ~echo "%s %s" command (Stdlib.Filename.quote filename)
  | Stdout command -> run_stdout command ~echo ~filename ~output:filename

let format_to_file (formatter : formatter) ~echo ~filename =
  let temp_file () =
    let output =
      Stdlib.Filename.temp_file "merge-fmt-"
        (Stdlib.Filename.extension filename)
    in
    Stdlib.at_exit (fun () -> Stdlib.Sys.remove output);
    output
  in
  match formatter filename with
  | File (Copy, _) ->
      let output = temp_file () in
      run (formatter output) ~echo ~filename |> Result.map ~f:(fun () -> output)
  | Stdout command ->
      let output = temp_file () in
      run_stdout command ~echo ~filename ~output
      |> Result.map ~f:(fun () -> output)
  | File (Inplace, _) as t ->
      run t ~echo ~filename |> Result.map ~f:(fun () -> filename)

module Flags = struct
  open Cmdliner

  let ocamlformat_path =
    let doc = "ocamlformat path" in
    Arg.(value & opt (some string) None & info [ "ocamlformat" ] ~doc)

  let refmt_path =
    let doc = "refmt path" in
    Arg.(value & opt (some string) None & info [ "refmt" ] ~doc)

  let dune_path =
    let doc = "dune path" in
    Arg.(value & opt (some string) None & info [ "dune" ] ~doc)

  let t =
    Term.(
      const (fun ocamlformat_path refmt_path dune_path ->
          { ocamlformat_path; refmt_path; dune_path })
      $ ocamlformat_path $ refmt_path $ dune_path)
end
