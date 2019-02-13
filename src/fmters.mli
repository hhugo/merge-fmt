open Base

type config

type t

val ocamlformat : t

val ocp_indent : t

val refmt : t

val find : config:config -> filename:string -> t option

val run : t -> echo:bool -> filename:string -> (unit, unit) Result.t

module Flags : sig
  open Cmdliner

  val t : config Term.t
end
