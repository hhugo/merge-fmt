open Base
open Stdio
open Common

let debug_oc = lazy (Out_channel.create ~append:true "/tmp/merge-fmt.log")

let debug fmt =
  if true
  then Printf.ksprintf (fun _ -> ()) fmt
  else Printf.ksprintf (Out_channel.fprintf (Lazy.force debug_oc) "%s") fmt

let merge config echo current base other output name =
  match (current, base, other) with
  | (None | Some ""), _, _ | _, (None | Some ""), _ | _, _, (None | Some "") ->
      Caml.exit 1
  | Some current, Some base, Some other -> (
      match Fmters.find ~config ~filename:current ~name with
      | None ->
          debug "Couldn't find a formatter for %s\n%!" current;
          system_respect_exit ~echo "git merge-file %s %s %s" current base other
      | Some formatter -> (
          let x =
            Fmters.run formatter ~echo ~filename:current
            |> Result.map_error ~f:(Fn.const "current")
          and y =
            Fmters.run formatter ~echo ~filename:other
            |> Result.map_error ~f:(Fn.const "other")
          and z =
            Fmters.run formatter ~echo ~filename:base
            |> Result.map_error ~f:(Fn.const "base")
          in
          match Result.combine_errors [ x; y; z ] with
          | Error _ -> Caml.exit 1
          | Ok (_ : unit list) ->
              debug "process all three revision successfully\n%!";
              debug "running git merge-file\n%!";
              let result =
                open_process_in_respect_exit ~echo "git merge-file -p %s %s %s"
                  current base other
              in
              (match output with
              | None -> Out_channel.output_string stdout result
              | Some o -> Out_channel.write_all o ~data:result);
              Caml.exit 0))

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
    let doc = "" in
    Arg.(value & opt (some file) None & info [ "o" ] ~docv:"<output-to>" ~doc)
  in
  let result_name =
    let doc = "pathname in which the merged result will be stored" in
    Arg.(
      value & opt (some file) None & info [ "name" ] ~docv:"<result-name>" ~doc)
  in
  let doc = "git mergetool" in
  ( Term.(
      const merge $ Fmters.Flags.t $ Flags.echo $ current $ base $ other
      $ output $ result_name)
  , Term.info ~doc "mergetool" )
