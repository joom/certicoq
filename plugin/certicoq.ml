(**********************************************************************)
(* CertiCoq                                                           *)
(* Copyright (c) 2017                                                 *)
(**********************************************************************)

open Pp
open Printer
open Metacoq_template_plugin.Ast_quoter
open ExceptionMonad
open AstCommon
open Plugin_utils

(** Various Utils *)

let pr_string s = str (Caml_bytestring.caml_string_of_bytestring s)

(* remove duplicates but preserve order, keep the leftmost element *)
let nub (xs : 'a list) : 'a list = 
  List.fold_right (fun x xs -> if List.mem x xs then xs else x :: xs) xs []

let rec coq_nat_of_int x =
  match x with
  | 0 -> Datatypes.O
  | n -> Datatypes.S (coq_nat_of_int (pred n))

let debug_msg (flag : bool) (s : string) =
  if flag then
    Feedback.msg_debug (str s)
  else ()

(* Separate registration of primitive extraction *)

type prim = ((Kernames.kername * Kernames.ident) * bool)
let global_registers = 
  Summary.ref (([], []) : prim list * string list) ~name:"CertiCoq Registration"

let global_registers_name = "certicoq-registration"

let cache_registers (prims, imports) =
  let (prims', imports') = !global_registers in
  global_registers := (prims @ prims', imports @ imports')
let global_registers_input = 
  let open Libobject in 
  declare_object 
    (global_object_nodischarge global_registers_name
    ~cache:(fun r -> cache_registers r)
    ~subst:None) (*(fun (msub, r) -> r)) *)

let register (prims : prim list) (imports : string list) : unit =
  let curlib = Sys.getcwd () in
  let newr = (prims, List.map (Filename.concat curlib) imports) in
  (* Feedback.msg_debug Pp.(str"Prims: " ++ prlist_with_sep spc (fun ((x, y), wt) -> str (string_of_bytestring y)) (fst newr)); *)
  Lib.add_leaf (global_registers_input newr)

let get_global_prims () = fst !global_registers
let get_global_includes () = snd !global_registers

(** Compilation Command Arguments *)

type command_args =
 | BYPASS_QED
 | CPS
 | TIME
 | TIMEANF
 | OPT of int
 | DEBUG
 | ARGS of int
 | ANFCONFIG of int (* To measure different ANF configurations *)
 | BUILDDIR of string (* Directory name to be prepended to the file name *)
 | EXT of string (* Filename extension to be appended to the file name *)
 | DEV of int    (* For development purposes *)
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

let default_options : options =
  { bypass_qed = false;
    cps       = false;
    time      = false;
    time_anf  = false;
    olevel    = 1;
    debug     = false;
    args      = 5;
    anf_conf  = 0;
    build_dir = ".";
    filename  = "";
    ext       = "";
    dev       = 0;
    prefix    = "";
    prims     = [];
  }

let check_build_dir d =
  if d = "" then "." else
  let isdir = 
    try Unix.((stat d).st_kind = S_DIR)
    with Unix.Unix_error (Unix.ENOENT, _, _) ->
      CErrors.user_err ~hdr:"pipeline" 
        Pp.(str "Could not compile: build directory " ++ str d ++ str " not found.")
  in
  if not isdir then 
    CErrors.user_err ~hdr:"pipeline"
      Pp.(str "Could not compile: " ++ str d ++ str " is not a directory.")
  else d

let make_options (l : command_args list) (pr : ((Kernames.kername * Kernames.ident) * bool) list) (fname : string) : options =
  let rec aux (o : options) l =
    match l with
    | [] -> o
    | BYPASS_QED :: xs -> aux {o with bypass_qed = true} xs
    | CPS      :: xs -> aux {o with cps = true} xs
    | TIME     :: xs -> aux {o with time = true} xs
    | TIMEANF  :: xs -> aux {o with time_anf = true} xs
    | OPT n    :: xs -> aux {o with olevel = n} xs
    | DEBUG    :: xs -> aux {o with debug = true} xs
    | ARGS n   :: xs -> aux {o with args = n} xs
    | ANFCONFIG n :: xs -> aux {o with anf_conf = n} xs
    | BUILDDIR s  :: xs ->
      let s = check_build_dir s in
      aux {o with build_dir = s} xs
    | EXT s    :: xs -> aux {o with ext = s} xs
    | DEV n    :: xs -> aux {o with dev = n} xs
    | PREFIX s :: xs -> aux {o with prefix = s} xs
    | FILENAME s :: xs -> aux {o with filename = s} xs
  in
  let opts = { default_options with filename = fname } in
  let o = aux opts l in
  {o with prims = pr}

let make_pipeline_options (opts : options) =
  let cps    = opts.cps in
  let args = coq_nat_of_int opts.args in
  let olevel = coq_nat_of_int opts.olevel in
  let timing = opts.time in
  let timing_anf = opts.time_anf in
  let debug  = opts.debug in
  let anfc = coq_nat_of_int opts.anf_conf in
  let dev = coq_nat_of_int opts.dev in
  let prefix = bytestring_of_string opts.prefix in
  let prims = get_global_prims () @ opts.prims in
  (* Feedback.msg_debug Pp.(str"Prims: " ++ prlist_with_sep spc (fun ((x, y), wt) -> str (string_of_bytestring y)) prims); *)
  Pipeline.make_opts cps args anfc olevel timing timing_anf debug dev prefix prims

(** Main Compilation Functions *)

(* Get fully qualified name of a constant *)
let get_name (gr : Names.GlobRef.t) : string =
  match gr with
  | Names.GlobRef.ConstRef c -> Names.KerName.to_string (Names.Constant.canonical c)
  | _ -> CErrors.user_err ~hdr:"template-coq" (Printer.pr_global gr ++ str " is not a constant definition")


(* Quote Coq term *)
let quote opts gr =
  let debug = opts.debug in
  let bypass = opts.bypass_qed in
  let env = Global.env () in
  let sigma = Evd.from_env env in
  let sigma, c = Evd.fresh_global env sigma gr in
  debug_msg debug "Quoting";
  let time = Unix.gettimeofday() in
  let term = Metacoq_template_plugin.Ast_quoter.quote_term_rec ~bypass env (EConstr.to_constr sigma c) in
  let time = (Unix.gettimeofday() -. time) in
  debug_msg debug (Printf.sprintf "Finished quoting in %f s.. compiling to L7." time);
  term

(* Compile Quoted term with CertiCoq *)

module type CompilerInterface = sig
  type name_env
  val compile : Pipeline_utils.coq_Options -> Ast0.Env.program -> ((name_env * Clight.program) * Clight.program) CompM.error * Bytestring.String.t
  val printProg : Clight.program -> name_env -> string -> string list -> unit

  val generate_glue : Pipeline_utils.coq_Options -> Ast0.Env.global_declarations -> 
    (((name_env * Clight.program) * Clight.program) * Bytestring.String.t list) CompM.error
  
  val generate_ffi :
    Pipeline_utils.coq_Options -> Ast0.Env.program -> (((name_env * Clight.program) * Clight.program) * Bytestring.String.t list) CompM.error
  
end

module MLCompiler : CompilerInterface with 
  type name_env = BasicAst.name Cps.M.t
  = struct
  type name_env = BasicAst.name Cps.M.t
  let compile = Pipeline.compile
  let printProg prog names (dest : string) (import : string list) =
    PrintClight.print_dest_names_imports prog (Cps.M.elements names) dest import

  let generate_glue = Glue.generate_glue
  let generate_ffi = Ffi.generate_ffi
end


module CompileFunctor (CI : CompilerInterface) = struct

  let make_fname opts str =
    Filename.concat opts.build_dir str

  let compile opts term imports =
    let debug = opts.debug in
    let options = make_pipeline_options opts in
    let imports = get_global_includes () @ imports in
    let p = CI.compile options term in
    match p with
    | (CompM.Ret ((nenv, header), prg), dbg) ->
      debug_msg debug "Finished compiling, printing to file.";
      let time = Unix.gettimeofday() in
      let fname = opts.filename in
      let suff = opts.ext in
      let cstr = make_fname opts (fname ^ suff ^ ".c") in
      let hstr = make_fname opts (fname ^ suff ^ ".h") in
      CI.printProg prg nenv cstr imports;
      CI.printProg header nenv hstr [];

      (* let cstr = Metacoq_template_plugin.Tm_util.string_to_list (Names.KerName.to_string (Names.Constant.canonical const) ^ suff ^ ".c") in
      * let hstr = Metacoq_template_plugin.Tm_util.string_to_list (Names.KerName.to_string (Names.Constant.canonical const) ^ suff ^ ".h") in
      * Pipeline.printProg (nenv,prg) cstr;
      * Pipeline.printProg (nenv,header) hstr; *)
      let time = (Unix.gettimeofday() -. time) in
      debug_msg debug (Printf.sprintf "Printed to file %s in %f s.." cstr time);
      debug_msg debug "Pipeline debug:";
      debug_msg debug (string_of_bytestring dbg)
    | (CompM.Err s, dbg) ->
      debug_msg debug "Pipeline debug:";
      debug_msg debug (string_of_bytestring dbg);
      CErrors.user_err ~hdr:"pipeline" (str "Could not compile: " ++ (pr_string s) ++ str "\n")


  (* Generate glue code for the compiled program *)
  let generate_glue (standalone : bool) opts globs =
    if standalone && opts.filename = "" then
      CErrors.user_err ~hdr:"glue-code" (str "You need to provide a file name with the -file option.")
    else
    let debug = opts.debug in
    let options = make_pipeline_options opts in

    let time = Unix.gettimeofday() in
    (match CI.generate_glue options globs with
    | CompM.Ret (((nenv, header), prg), logs) ->
      let time = (Unix.gettimeofday() -. time) in
      debug_msg debug (Printf.sprintf "Generated glue code in %f s.." time);
      (match logs with [] -> () | _ ->
        debug_msg debug (Printf.sprintf "Logs:\n%s" (String.concat "\n" (List.map string_of_bytestring logs))));
      let time = Unix.gettimeofday() in
      let suff = opts.ext in
      let fname = opts.filename in
      let cstr = if standalone then fname ^ ".c" else "glue." ^ fname ^ suff ^ ".c" in
      let hstr = if standalone then fname ^ ".h" else "glue." ^ fname ^ suff ^ ".h" in
      let cstr = make_fname opts cstr in
      let hstr = make_fname opts hstr in
      CI.printProg prg nenv cstr [];
      CI.printProg header nenv hstr [];

      let time = (Unix.gettimeofday() -. time) in
      debug_msg debug (Printf.sprintf "Printed glue code to file %s in %f s.." cstr time)
    | CompM.Err s ->
      CErrors.user_err ~hdr:"glue-code" (str "Could not generate glue code: " ++ pr_string s))


  let compile_with_glue (opts : options) (gr : Names.GlobRef.t) (imports : string list) : unit =
    let term = quote opts gr in
    compile opts (Obj.magic term) imports;
    generate_glue false opts (Ast0.Env.declarations (fst (Obj.magic term)))

  let compile_only opts gr imports =
    let term = quote opts gr in
    compile opts (Obj.magic term) imports

  let generate_glue_only opts gr =
    let term = quote opts gr in
    generate_glue true opts (Ast0.Env.declarations (fst (Obj.magic term)))
    
  let compiler_executable debug = 
    let whichcmd = Unix.open_process_in "which gcc || which clang-11" in
    let result = 
      try Stdlib.input_line whichcmd 
      with End_of_file -> ""
    in
    let status = Unix.close_process_in whichcmd in
    match status with
    | Unix.WEXITED 0 -> 
      if debug then Feedback.msg_debug Pp.(str "Compiler is " ++ str result);
      result
    | _ -> failwith "Compiler not found"

  type line = 
    | EOF
    | Info of string
    | Error of string

  let read_line stdout stderr =
    try Info (input_line stdout)
    with End_of_file -> 
      try Error (input_line stderr)
      with End_of_file -> EOF
  
  let run_program debug prog =
    let (stdout, stdin, stderr) = Unix.open_process_full ("./" ^ prog) (Unix.environment ()) in
    let continue = ref true in
    while !continue do 
      match read_line stdout stderr with
      | EOF -> debug_msg debug ("Program terminated"); continue := false
      | Info s -> Feedback.msg_notice Pp.(str prog ++ str": " ++ str s)
      | Error s -> Feedback.msg_warning Pp.(str prog ++ str": " ++ str s)
    done

  let runtime_dir () = 
    let open Boot in
    let env = Env.init () in
    Path.relative (Path.relative (Path.relative (Env.user_contrib env) "CertiCoq") "Plugin") "runtime"

  let make_rt_file na =
    Boot.Env.Path.(to_string (relative (runtime_dir ()) na))

  let compile_C opts gr imports =
    let () = compile_with_glue opts gr imports in
    let imports = get_global_includes () @ imports in
    let debug = opts.debug in
    let fname = opts.filename in
    let suff = opts.ext in
    let name = make_fname opts (fname ^ suff) in
    let compiler = compiler_executable debug in
    let rt_dir = runtime_dir () in
    let cmd =
        Printf.sprintf "%s -Wno-everything -g -I %s -I %s -c -o %s %s" 
          compiler opts.build_dir (Boot.Env.Path.to_string rt_dir) (name ^ ".o") (name ^ ".c") 
    in
    let importso =
      let oname s = 
        assert (CString.is_suffix ".h" s);
        String.sub s 0 (String.length s - 2) ^ ".o"
      in 
      let l = make_rt_file "certicoq_run_main.o" :: List.map oname imports in
      String.concat " " l
    in
    let gc_stack_o = make_rt_file "gc_stack.o" in
    debug_msg debug (Printf.sprintf "Executing command: %s" cmd);
    match Unix.system cmd with
    | Unix.WEXITED 0 -> 
      let linkcmd =
        Printf.sprintf "%s -Wno-everything -g -L %s -L %s -o %s %s %s %s" 
          compiler opts.build_dir (Boot.Env.Path.to_string rt_dir) name gc_stack_o (name ^ ".o") importso
      in
      debug_msg debug (Printf.sprintf "Executing command: %s" linkcmd);
      (match Unix.system linkcmd with
      | Unix.WEXITED 0 ->
          debug_msg debug (Printf.sprintf "Compilation ran fine, running %s" name);
          run_program debug name
      | Unix.WEXITED n -> CErrors.user_err Pp.(str"Compiler exited with code " ++ int n ++ str" while running " ++ str linkcmd)
      | Unix.WSIGNALED n | Unix.WSTOPPED n -> CErrors.user_err Pp.(str"Compiler was signaled with code " ++ int n))
    | Unix.WEXITED n -> CErrors.user_err Pp.(str"Compiler exited with code " ++ int n ++ str" while running " ++ str cmd)
    | Unix.WSIGNALED n | Unix.WSTOPPED n -> CErrors.user_err Pp.(str"Compiler was signaled with code " ++ int n  ++ str" while running " ++ str cmd)
  
  let print_to_file (s : string) (file : string) =
    let f = open_out file in
    Printf.fprintf f "%s\n" s;
    close_out f

  let show_ir opts gr =
    let term = quote opts gr in
    let debug = opts.debug in
    let options = make_pipeline_options opts in
    let p = Pipeline.show_IR options (Obj.magic term) in
    match p with
    | (CompM.Ret prg, dbg) ->
      debug_msg debug "Finished compiling, printing to file.";
      let time = Unix.gettimeofday() in
      let suff = opts.ext in
      let fname = opts.filename in
      let file = fname ^ suff ^ ".ir" in
      print_to_file (string_of_bytestring prg) file;
      let time = (Unix.gettimeofday() -. time) in
      debug_msg debug (Printf.sprintf "Printed to file %s in %f s.." file time);
      debug_msg debug "Pipeline debug:";
      debug_msg debug (string_of_bytestring dbg)
    | (CompM.Err s, dbg) ->
      debug_msg debug "Pipeline debug:";
      debug_msg debug (string_of_bytestring dbg);
      CErrors.user_err ~hdr:"show-ir" (str "Could not compile: " ++ (pr_string s) ++ str "\n")


  (* Quote Coq inductive type *)
  let quote_ind opts gr : Metacoq_template_plugin.Ast_quoter.quoted_program * string =
    let debug = opts.debug in
    let env = Global.env () in
    let sigma = Evd.from_env env in
    let sigma, c = Evd.fresh_global env sigma gr in
    let name = match gr with
      | Names.GlobRef.IndRef i -> 
          let (mut, _) = i in
          Names.KerName.to_string (Names.MutInd.canonical mut)
      | _ -> CErrors.user_err ~hdr:"template-coq"
        (Printer.pr_global gr ++ str " is not an inductive type") in
    debug_msg debug "Quoting";
    let time = Unix.gettimeofday() in
    let term = quote_term_rec ~bypass:true env (EConstr.to_constr sigma c) in
    let time = (Unix.gettimeofday() -. time) in
    debug_msg debug (Printf.sprintf "Finished quoting in %f s.." time);
    (term, name)

  let ffi_command opts gr =
    let (term, name) = quote_ind opts gr in
    let debug = opts.debug in
    let options = make_pipeline_options opts in

    let time = Unix.gettimeofday() in
    (match CI.generate_ffi options (Obj.magic term) with
    | CompM.Ret (((nenv, header), prg), logs) ->
      let time = (Unix.gettimeofday() -. time) in
      debug_msg debug (Printf.sprintf "Generated FFI glue code in %f s.." time);
      (match logs with [] -> () | _ ->
        debug_msg debug (Printf.sprintf "Logs:\n%s" (String.concat "\n" (List.map string_of_bytestring logs))));
      let time = Unix.gettimeofday() in
      let suff = opts.ext in
      let cstr = ("ffi." ^ name ^ suff ^ ".c") in
      let hstr = ("ffi." ^ name ^ suff ^ ".h") in
      CI.printProg prg nenv cstr [];
      CI.printProg header nenv hstr [];

      let time = (Unix.gettimeofday() -. time) in
      debug_msg debug (Printf.sprintf "Printed FFI glue code to file in %f s.." time)
    | CompM.Err s ->
      CErrors.user_err ~hdr:"ffi-glue-code" (str "Could not generate FFI glue code: " ++ pr_string s))

  let glue_command opts grs =
    let terms = grs |> List.rev
                |> List.map (fun gr -> Metacoq_template_plugin.Ast0.Env.declarations (fst (quote opts gr))) 
                |> List.concat |> nub in
    generate_glue true opts (Obj.magic terms)

end

module MLCompile = CompileFunctor (MLCompiler)
include MLCompile