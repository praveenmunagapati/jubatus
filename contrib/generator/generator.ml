
open Util

let make_mprpc_decl (retval,n,argv,decs,_,_) =
  "// " ^ (String.concat ", " decs) ^ "\n"
  ^ "MPRPC_PROC(" ^ n ^ "),\tresult<" ^ (Stree.to_string retval) ^ ">("
  ^ (String.concat ", " ("string" :: (List.map Stree.to_string argv))) ^ ");\n";;

let gen_mprpc_decl name prototypes =
  let get_name (_,n,_,_,_,_) = n in
  let names = List.map get_name prototypes in
  "MPRPC_GEN(1, " ^ (String.concat ", " (name :: names)) ^ "); ";;

 (* temporary error: to be fixed  *)
exception Multiple_argument_for_rpc
exception Multiple_decorator
exception Multiple_class

class jubatus_module outdir_i name_i namespace_i typedefs_i structdefs_i classdefs_i =
object (self)
  val outdir = outdir_i
  val name = name_i
  val namespace = namespace_i
  val typedefs = typedefs_i
  val structdefs = structdefs_i
  val classdefs = classdefs_i
  val mutable output = stdout

  val idlfile  = name_i ^ ".idl"
  val server_c = name_i ^ "_impl.cpp"
  val keeper_c = name_i ^ "_keeper.cpp"

  method check_classdefs =
    let check_classdef classdef =
      let Stree.ClassDef(_,prototypes,_) = classdef in
      let check_prototype p = 
	let (_, _, argvs, decorators, _) = p in
	if not (List.length argvs = 1) then raise Multiple_argument_for_rpc
	else if not (List.length decorators = 1) then raise Multiple_decorator
	else ()
      in
      List.iter check_prototype prototypes;
    in
    if not (List.length classdefs = 1) then raise Multiple_class
    else List.iter check_classdef classdefs;

  method generate_idl =
    print_endline ("==" ^ idlfile ^ "==");
    output <<< "# this idl is automatically generated. do not edit. ";
    List.iter (fun t -> output <<< Idl_template.make_typedef t) typedefs;
    List.iter (fun m -> output <<< Idl_template.make_message m) structdefs;
    List.iter (fun c -> output <<< Idl_template.make_service c) classdefs;
    
  method generate_impl =
    print_endline ("==" ^ server_c ^ "==");
    output <<< "// this program is automatically generated. do not edit. ";
(*    output <<< include_dq ["server.hpp"; "../common/cmdline.h"]; *)
    let namespaces = [namespace; "server"] in
    output <<< make_ns_begin namespaces;
    List.iter (fun c -> output <<< Server_template.make_class c) classdefs;
    output <<< make_ns_end namespaces;
    output <<< Server_template.make_main classdefs;

  method generate_keeper =
    print_endline ("==" ^ keeper_c ^ "==");
    output <<< "// this program is automatically generated. do not edit. ";
    output <<< Keeper_template.make_file_begin name;
    output <<< Keeper_template.make_main classdefs;
    output <<< Keeper_template.make_file_end name;

  method generate =
    self#check_classdefs;
(*    print_endline "------------- generated code:";
    output <- stdout; *)

    output <- open_out (String.concat "/" [outdir; idlfile]);
    self#generate_idl;
    output <- open_out (String.concat "/" [outdir; server_c]);
    self#generate_impl;
    output <- open_out (String.concat "/" [outdir; keeper_c]);
    self#generate_keeper;

end;;
