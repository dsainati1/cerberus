open Pp
(* open Resultat
 * open TypeErrors *)

module SymSet = Set.Make(Sym)
module SymMap = Map.Make(Sym)
module IdMap = Map.Make(Id)
module CF = Cerb_frontend
module Loc = Locations
module LC = LogicalConstraints
module RE = Resources
module IT = IndexTerms
module BT = BaseTypes
module LS = LogicalSorts
module LRT = LogicalReturnTypes
module RT = ReturnTypes
module LFT = ArgumentTypes.Make(LRT)
module FT = ArgumentTypes.Make(RT)



(* Auxiliaries *)

module ImplMap = 
  Map.Make
    (struct 
      type t = CF.Implementation.implementation_constant
      let compare = CF.Implementation.implementation_constant_compare 
     end)




let impl_lookup (e: 'v ImplMap.t) i =
  match ImplMap.find_opt i e with
  | None ->
     Debug_ocaml.error
       ("Unbound implementation defined constant " ^
          (CF.Implementation.string_of_implementation_constant i))
  | Some v -> v


type closed_stored_predicate_definition =
  { pack_function: IT.t -> LFT.t; 
    unpack_function: IT.t -> LFT.t; 
  }


type struct_decl = 
  { members: (BT.member * (Sctypes.t * BT.t)) list;
    (* sizes: (BT.member * RE.size) list;
     * offsets: (BT.member * Z.t) list;
     * representable: IT.t -> LC.t; *)
    (* closed: RT.t;  *)
    closed_stored: RT.t;
    closed_stored_predicate_definition: 
      closed_stored_predicate_definition
  }

type struct_decls = struct_decl SymMap.t

type resource_predicate = 
  { arguments : LS.t list;
    pack_functions : IT.t -> (LFT.t OneList.t);
    unpack_functions : IT.t -> (LFT.t OneList.t);
  }

type t = 
  { struct_decls : struct_decls; 
    fun_decls : (Loc.t * FT.t) SymMap.t;
    impl_fun_decls : (FT.t) ImplMap.t;
    impl_constants : BT.t ImplMap.t;
    stdlib_funs : SymSet.t;
    resource_predicates : resource_predicate IdMap.t;
  } 

let empty = 
  { struct_decls = SymMap.empty; 
    fun_decls = SymMap.empty;
    impl_fun_decls = ImplMap.empty;
    impl_constants = ImplMap.empty;
    stdlib_funs = SymSet.empty;
    resource_predicates = IdMap.empty;
  }

let get_predicate_def loc global predicate_name = 
  let open Resources in
  match predicate_name with
  | Id id -> IdMap.find_opt id global.resource_predicates
  | Tag tag ->
     match SymMap.find_opt tag global.struct_decls with
     | None -> None
     | Some decl ->
       let pack_functions = 
         fun it -> OneList.Last (decl.closed_stored_predicate_definition.pack_function it)
       in
       let unpack_functions = 
         fun it -> OneList.Last (decl.closed_stored_predicate_definition.unpack_function it)
       in
       Some {arguments = [LS.Base (Struct tag)];
             pack_functions; 
             unpack_functions}

let get_fun_decl global sym = SymMap.find_opt sym global.fun_decls
let get_impl_fun_decl global i = impl_lookup global.impl_fun_decls i
let get_impl_constant global i = impl_lookup global.impl_constants i



let pp_struct_decl (sym,decl) = 
  item ("struct " ^ plain (Sym.pp sym) ^ " (raw)") 
       (Pp.list (fun (m, (ct, bt)) -> 
            typ (Id.pp m) (BT.pp true bt)) decl.members) 
  ^/^
  item ("struct " ^ plain (Sym.pp sym) ^ " (closed stored)") 
       (RT.pp decl.closed_stored)
  ^/^
  item ("struct " ^ plain (Sym.pp sym) ^ " (packing function) at P") 
    (LFT.pp
       (decl.closed_stored_predicate_definition.pack_function
          (IT.S (Sym.fresh_named "P"))))
  ^/^
  item ("struct " ^ plain (Sym.pp sym) ^ " (unpacking function) at P") 
    (LFT.pp
       (decl.closed_stored_predicate_definition.unpack_function
          (IT.S (Sym.fresh_named "struct_pointer"))))

let pp_struct_decls decls = Pp.list pp_struct_decl (SymMap.bindings decls) 

let pp_fun_decl (sym, (_, t)) = item (plain (Sym.pp sym)) (FT.pp t)
let pp_fun_decls decls = flow_map hardline pp_fun_decl (SymMap.bindings decls)

let pp global = 
  pp_struct_decls global.struct_decls ^^ hardline ^^
  pp_fun_decls global.fun_decls


