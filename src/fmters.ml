open Base
open Common

type config =
  { ocamlformat_path : string option
  ; refmt_path : string option
  ; dune_path : string option
  }

(* How a formatter is run on a file. [File command]: [command] writes its
   result to a file, which is part of the command. [Stdout command]: [command]
   prints its result. *)
type t =
  | File of string
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
  File (sprintf "%s -o %s" command (Stdlib.Filename.quote output))

(* refmt chooses how to parse a file from its extension, which the files
   being merged do not always have. *)
let refmt ~bin ~interface =
  Stdout
    (sprintf "%s --parse=re --interface=%b"
       (Option.value ~default:"refmt" bin)
       interface)

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
  | _, ((".re" | ".rei") as ext), { refmt_path; _ } ->
      Some (fun _ -> refmt ~bin:refmt_path ~interface:(String.equal ext ".rei"))
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
  | File command ->
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
  | File _ ->
      let output = temp_file () in
      run (formatter output) ~echo ~filename |> Result.map ~f:(fun () -> output)
  | Stdout command ->
      let output = temp_file () in
      run_stdout command ~echo ~filename ~output
      |> Result.map ~f:(fun () -> output)

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
