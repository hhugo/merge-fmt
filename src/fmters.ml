open Base
open Common

type config =
  { ocamlformat_path : string option
  ; refmt_path : string option
  ; dune_path : string option
  }

type t =
  | Inplace of string
  | Stdout of string

let transfer ic oc =
  let b = Bytes.create 4096 in
  let rec loop () =
    match Stdlib.input ic b 0 (Bytes.length b) with
    | 0 -> ()
    | l ->
        Stdlib.output oc b 0 l;
        loop ()
  in
  loop ()

let ocamlformat ~bin ~name =
  Inplace
    (sprintf "%s -i %s"
       (Option.value ~default:"ocamlformat" bin)
       (Option.value_map ~default:"" ~f:(fun name -> " --name=" ^ name) name))

let refmt ~bin =
  Inplace (sprintf "%s --inplace" (Option.value ~default:"refmt" bin))

let dune ~bin =
  Stdout (sprintf "%s format-dune-file --" (Option.value ~default:"dune" bin))

let find ~config ~filename ~name =
  let filename = Option.value ~default:filename name in
  match (filename, Caml.Filename.extension filename, config) with
  | _, (".ml" | ".mli"), { ocamlformat_path; _ } ->
      Some (ocamlformat ~bin:ocamlformat_path ~name)
  | _, (".re" | ".rei"), { refmt_path; _ } -> Some (refmt ~bin:refmt_path)
  | ("dune" | "dune-project" | "dune-workspace"), "", { dune_path; _ } ->
      Some (dune ~bin:dune_path)
  | _ -> None

let run t ~echo ~filename =
  match t with
  | Inplace t -> system ~echo "%s %s" t filename
  | Stdout t -> (
      let ic = open_process_in ~echo "%s %s" t filename in
      let tmp_file, oc = Stdlib.Filename.open_temp_file "merge-fmt" "stdout" in
      transfer ic oc;
      Stdlib.close_out oc;
      match Unix.close_process_in ic with
      | WEXITED 0 ->
          Stdlib.Sys.rename tmp_file filename;
          Ok ()
      | WEXITED n ->
          Stdlib.Printf.eprintf ">>> Exit with %d\n" n;
          Error ()
      | WSIGNALED _ | WSTOPPED _ -> Error ())

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
