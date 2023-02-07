open Base
open Common

type config =
  { ocamlformat_path : string option
  ; refmt_path : string option
  }

type t = string

let ocamlformat ~bin ~name =
  sprintf "%s -i %s"
    (Option.value ~default:"ocamlformat" bin)
    (Option.value_map ~default:"" ~f:(fun name -> " --name=" ^ name) name)

let refmt ~bin = sprintf "%s --inplace" (Option.value ~default:"refmt" bin)

let find ~config ~filename ~name =
  let filename = Option.value ~default:filename name in
  match (Caml.Filename.extension filename, config) with
  | (".ml" | ".mli"), { ocamlformat_path; _ } ->
      Some (ocamlformat ~bin:ocamlformat_path ~name)
  | (".re" | ".rei"), { refmt_path; _ } -> Some (refmt ~bin:refmt_path)
  | _ -> None

let run t ~echo ~filename = system ~echo "%s %s" t filename

module Flags = struct
  open Cmdliner

  let ocamlformat_path =
    let doc = "ocamlformat path" in
    Arg.(value & opt (some string) None & info [ "ocamlformat" ] ~doc)

  let refmt_path =
    let doc = "refmt path" in
    Arg.(value & opt (some string) None & info [ "refmt" ] ~doc)

  let t =
    Term.(
      const (fun ocamlformat_path refmt_path ->
          { ocamlformat_path; refmt_path })
      $ ocamlformat_path $ refmt_path)
end
