open Base

type config
type t
type formatter = string -> t

val find :
  config:config -> filename:string -> name:string option -> formatter option

val run : t -> echo:bool -> filename:string -> (unit, unit) Result.t

val format_to_file :
  formatter -> echo:bool -> filename:string -> (string, unit) Result.t

module Flags : sig
  open Cmdliner

  val t : config Term.t
end
