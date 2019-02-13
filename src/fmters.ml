open Base
open Common

type config =
  { ocamlformat_path : string option
  ; refmt_path : string option }

type t = string

let ocamlformat ~bin =
  sprintf
    "%s -i --disable-outside-detected-project"
    (Option.value ~default:"ocamlformat" bin)

let ocp_indent ~bin = sprintf "%s -i" (Option.value ~default:"ocp-indent" bin)

let refmt ~bin = sprintf "%s --inplace" (Option.value ~default:"refmt" bin)

let find ~config ~filename =
  match Caml.Filename.extension filename, config with
  | (".ml" | ".mli"), {ocamlformat_path; _} -> Some (ocamlformat ~bin:ocamlformat_path)
  | (".re" | ".rei"), {refmt_path; _} -> Some (refmt ~bin:refmt_path)
  | _ -> None

let ocamlformat = ocamlformat ~bin:None

let ocp_indent = ocp_indent ~bin:None

let refmt = refmt ~bin:None

let run t ~echo ~filename = system ~echo "%s %s" t filename

module Flags = struct
  open Cmdliner

  let ocamlformat_path =
    let doc = "ocamlformat path" in
    Arg.(value & opt (some string) None & info ["ocamlformat"] ~doc)

  let refmt_path =
    let doc = "refmt path" in
    Arg.(value & opt (some string) None & info ["refmt"] ~doc)

  let t =
    Term.(
      pure (fun ocamlformat_path refmt_path -> {ocamlformat_path; refmt_path})
      $ ocamlformat_path
      $ refmt_path)
end
