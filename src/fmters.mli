open Base

type config

type t

val find : config:config -> filename:string -> name:string option -> t option

val run : t -> echo:bool -> filename:string -> (unit, unit) Result.t

module Flags : sig
  open Cmdliner

  val t : config Term.t
end
