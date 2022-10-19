type command_args =
 | BYPASS_QED
 | CPS
 | TIME
 | TIMEANF
 | OPT of int
 | DEBUG
 | ARGS of int 
 | ANFCONFIG of int (* The number of fvs passed as params and the original params shall not exceed this number *)
 | BUILDDIR of string
 | EXT of string (* Filename extension to be appended to the file name *)
 | DEV of int
 | PREFIX of string (* Prefix to add to the generated FFI fns, avoids clashes with C fns *)
 | FILENAME of string (* Name of the generated file *)

type options =
  { bypass_qed : bool;
    cps       : bool;
    time      : bool;
    time_anf  : bool;
    olevel    : int;
    debug     : bool;
    args      : int;
    anf_conf  : int;
    build_dir : string;
    filename  : string;
    ext       : string;
    dev       : int;
    prefix    : string;
    prims     : ((Kernames.kername * Kernames.ident) * bool) list;
  }

type prim = ((Kernames.kername * Kernames.ident) * bool)

val default_options : options
val make_options : command_args list -> prim list -> string -> options

(* Register primitive operations and associated include file *)
val register : prim list -> string list -> unit

val get_name : Names.GlobRef.t -> string

module type CompilerInterface = sig
  type name_env
  val compile : Pipeline_utils.coq_Options -> Ast0.Env.program -> ((name_env * Clight.program) * Clight.program) CompM.error * Bytestring.String.t
  val printProg : Clight.program -> name_env -> string -> string list -> unit

  val generate_glue : Pipeline_utils.coq_Options -> Ast0.Env.global_declarations -> 
    (((name_env * Clight.program) * Clight.program) * Bytestring.String.t list) CompM.error
  
end

module CompileFunctor (CI : CompilerInterface) : sig
  val compile_with_glue : options -> Names.GlobRef.t -> string list -> unit
  val compile_only : options -> Names.GlobRef.t -> string list -> unit
  val generate_glue_only : options -> Names.GlobRef.t -> unit
  val compile_C : options -> Names.GlobRef.t -> string list -> unit
  val show_ir : options -> Names.GlobRef.t -> unit
  val glue_command : options -> Names.GlobRef.t list -> unit
end

val compile_with_glue : options -> Names.GlobRef.t -> string list -> unit
val compile_only : options -> Names.GlobRef.t -> string list -> unit
val generate_glue_only : options -> Names.GlobRef.t -> unit
val compile_C : options -> Names.GlobRef.t -> string list -> unit
val show_ir : options -> Names.GlobRef.t -> unit
val glue_command : options -> Names.GlobRef.t list -> unit
