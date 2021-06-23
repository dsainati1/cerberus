module Z = struct
  include Z

  let eq : t -> t -> bool = equal
  let ne : t -> t -> bool = fun z1 z2 -> not (eq z1 z2)
end

(** Representation of addresses and maps over addresses. *)

type addr = Z.t

module AddrM = Map.Make(Z)

(** Allocation identifier and maps over allocation identifiers. *)

type alloc_id = Z.t

module AllocM = Map.Make(Z)

(** Heap representation. *)

type lock_state =
  | WSt
  | RSt of int

type prov =
  | ProvNull
  | ProvAlloc of alloc_id option
  | ProvFnPtr

let prov_to_aid : prov -> alloc_id option = fun prov ->
  match prov with
  | ProvAlloc(id) -> id
  | _             -> None

type loc = prov * addr

let compare_prov : prov -> prov -> int = fun prov1 prov2 ->
  let compare_id id1 id2 =
    match (id1, id2) with
    | (None    , None    ) -> 0
    | (None    , Some(_) ) -> -1
    | (Some(_) , None    ) -> 1
    | (Some(i1), Some(i2)) -> Z.compare i1 i2
  in
  match (prov1, prov2) with
  | (ProvNull      , ProvNull      ) -> 0
  | (ProvNull      , _             ) -> -1
  | (ProvAlloc(_)  , ProvNull      ) -> 1
  | (ProvAlloc(id1), ProvAlloc(id2)) -> compare_id id1 id2
  | (ProvAlloc(_)  , _             ) -> -1
  | (ProvFnPtr     , ProvFnPtr     ) -> 0
  | (ProvFnPtr     , _             ) -> 1

let compare_loc : loc -> loc -> int = fun (prov1, a1) (prov2, a2) ->
  match compare_prov prov1 prov2 with 0 -> Z.compare a1 a2 | i -> i

let pp_prov : out_channel -> prov -> unit = fun oc prov ->
  match prov with
  | ProvNull            -> Printf.fprintf oc "Null"
  | ProvAlloc(None)     -> Printf.fprintf oc "None"
  | ProvAlloc(Some(id)) -> Printf.fprintf oc "%a" Z.output id
  | ProvFnPtr           -> Printf.fprintf oc "FnPtr"

let pp_loc : out_channel -> loc -> unit = fun oc (prov, a) ->
  Printf.fprintf oc "(%a, %a)" pp_prov prov Z.output a;

type mbyte =
  | MByte of int
  | MPtrFrag of loc * int
  | MPoison

type value = mbyte list

type hcell = {
  hc_alloc_id   : alloc_id;
  hc_lock_state : lock_state;
  hc_value      : mbyte;
}

type heap = hcell AddrM.t

(** Allocation map representation. *)

type allocation = {
  al_start : addr;
  al_len   : int;
  al_alive : bool;
}

let al_end : allocation -> addr = fun al ->
  Z.(al.al_start + of_int al.al_len)

let allocation_in_range : allocation -> bool = fun al ->
  let min_alloc_start = Z.one in
  let max_alloc_end   = Z.(shift_left one 64 - Z.of_int 2) in
  Z.(leq min_alloc_start al.al_start && leq (al_end al) max_alloc_end)

type allocs = allocation AllocM.t

type heap_state = {
  hs_heap   : heap;
  hs_allocs : allocs;
}

let initial_heap_state : heap_state = {
  hs_heap   = AddrM.empty;
  hs_allocs = AllocM.empty;
}

(** Full program state. *)

type func = Symbol.sym

type state = {
  st_heap  : heap_state;
  st_fntbl : func AddrM.t;
}

let initial_state : state = {
  st_heap  = initial_heap_state;
  st_fntbl = AddrM.empty;
}

(** Auxiliary functions to validate pointers. *)

let block_alive : heap_state -> loc -> bool = fun hs (prov, _) ->
  match prov_to_aid prov with None -> false | Some(id) ->
  try (AllocM.find id hs.hs_allocs).al_alive
  with Not_found -> false

let heap_state_loc_in_bounds : heap_state -> loc -> int -> bool =
  fun hs (prov, a) n ->
  match prov_to_aid prov with None -> false | Some(id) ->
  try
    let al = AllocM.find id hs.hs_allocs in
    let n = Z.of_int n in
    Z.leq al.al_start a && Z.leq (Z.add a n) (al_end al)
  with Not_found -> false

let valid_ptr : heap_state -> loc -> bool = fun hs l ->
  block_alive hs l && heap_state_loc_in_bounds hs l 0

(** Conversion betweem values and locations. *)

let val_of_loc_n : int -> loc -> value = fun n l ->
  let rec loop acc n =
    if n = 0 then acc else loop (MPtrFrag(l, n) :: acc) (n - 1)
  in
  loop [] n

let val_to_loc_n : int -> value -> loc option = fun n v ->
  match v with
  | MPtrFrag(l,_) :: _ -> if v = val_of_loc_n n l then Some(l) else None
  | _                  -> None

let val_of_loc : loc -> value =
  val_of_loc_n 8

let val_to_loc : value -> loc option =
  val_to_loc_n 8

(** Integer type. *)

type int_type = {
  it_bytes_per_int_log : int;
  it_signed            : bool;
}

let mk_int_type : int -> bool -> int_type = fun log signed ->
  { it_bytes_per_int_log = log; it_signed = signed; }

let i8  = mk_int_type 0 true
let u8  = mk_int_type 0 false
let i16 = mk_int_type 1 true
let u16 = mk_int_type 1 false
let i32 = mk_int_type 2 true
let u32 = mk_int_type 2 false
let i64 = mk_int_type 3 true
let u64 = mk_int_type 3 false

let bytes_per_addr_log : int = 3
let bytes_per_addr : int = 1 lsl bytes_per_addr_log

let intptr_t  : int_type = mk_int_type bytes_per_addr_log true
let uintptr_t : int_type = mk_int_type bytes_per_addr_log false

let size_t    : int_type = uintptr_t
let ssize_t   : int_type = intptr_t
let ptrdiff_t : int_type = intptr_t
let bool_it   : int_type = u8

let bytes_per_int : int_type -> int = fun it ->
  1 lsl it.it_bytes_per_int_log

let bits_per_int : int_type -> int = fun it ->
  bytes_per_int it * 8

let int_modulus : int_type -> Z.t = fun it ->
  Z.shift_left Z.one (bits_per_int it)

let int_half_modulus : int_type -> Z.t = fun it ->
  Z.shift_left Z.one (bits_per_int it - 1)

let min_int : int_type -> Z.t = fun it ->
  if it.it_signed then Z.(neg (int_half_modulus it)) else Z.zero

let max_int : int_type -> Z.t = fun it ->
  Z.((if it.it_signed then int_half_modulus it else int_modulus it) - one)

let in_range : Z.t -> int_type -> bool = fun z it ->
  Z.(leq (min_int it) z && leq z (max_int it))

(** Converison betweem values and integers. *)

let rec val_to_Z_aux : value -> Z.t option = fun v ->
  match v with
  | []               -> Some(Z.zero)
  | MPtrFrag(_) :: _ -> None
  | MPoison     :: _ -> None
  | MByte(b)    :: v ->
  match val_to_Z_aux v with
  | None    -> None
  | Some(z) -> Some(Z.(of_int 256 * z + of_int b))

let val_to_Z : value -> int_type -> Z.t option = fun v it ->
  if List.length v = bytes_per_int it then
    match val_to_Z_aux v with
    | None    -> None
    | Some(z) ->
    if it.it_signed && Z.leq (int_half_modulus it) z then
      Some(Z.(z - int_modulus it))
    else
      Some(z)
  else None

let rec val_of_Z_aux : Z.t -> int -> value = fun z n ->
  match n with 0 -> [] | _ ->
  let (q, r) = Z.div_rem z (Z.of_int 256) in
  MByte(Z.(to_int r)) :: val_of_Z_aux q (n - 1)

let val_of_Z : Z.t -> int_type -> value option = fun z it ->
  if in_range z it then
    let z = Z.(if lt z zero then z + int_modulus it else z) in
    Some(val_of_Z_aux z (bytes_per_int it))
  else None

let val_of_bool : bool -> int_type -> value = fun b it ->
  match val_of_Z (if b then Z.one else Z.zero) it with
  | Some(v) -> v
  | None    -> assert false (* Unreachable. *)

(** Integer representation. *)

type int_repr =
  | IRInt of Z.t
  | IRLoc of loc

let int_repr_to_Z : int_repr -> Z.t = fun i ->
  match i with
  | IRInt(z) -> z
  | IRLoc(l) -> snd l

let int_repr_to_loc : int_repr -> loc = fun i ->
  match i with
  | IRLoc(l) -> l
  | IRInt(z) -> (ProvAlloc(None), z)

let val_of_int_repr : int_repr -> int_type -> value option = fun i it ->
  match i with
  | IRInt(z) -> val_of_Z z it
  | IRLoc(l) ->
      if in_range (snd l) it then Some(val_of_loc_n (bytes_per_int it) l)
      else None

let val_to_int_repr : value -> int_type -> int_repr option = fun v it ->
  match val_to_Z v it with
  | Some(z) -> Some(IRInt(z))
  | None    ->
      match val_to_loc_n (bytes_per_int it) v with
      | None    -> None
      | Some(l) -> if in_range (snd l) uintptr_t then Some(IRLoc(l)) else None

let val_to_Z_weak : value -> int_type -> Z.t option = fun v it ->
  match val_to_int_repr v it with
  | None    -> None
  | Some(i) -> Some(int_repr_to_Z i)

let val_to_loc_weak : value -> int_type -> loc option = fun v it ->
  match val_to_int_repr v it with
  | None    -> None
  | Some(i) -> Some(int_repr_to_loc i)

(** Cast operations between integers and pointers. *)

(* Pointer to pointer cast is a no-op. *)
let pp_cast : value -> value = fun v -> v

let ii_cast : int_type -> int_type -> value -> value option = fun it ot v ->
  match val_to_int_repr v it with
  | None    -> None
  | Some(i) -> val_of_int_repr i ot

let ip_cast : heap_state -> int_repr -> loc = fun hs i ->
  match i with
  | IRLoc(l) -> if block_alive hs l then l else (ProvAlloc(None), snd l)
  | IRInt(z) -> ((if Z.equal z Z.zero then ProvNull else ProvAlloc(None)), z)

let wrapped_ip_cast : heap_state -> int_type -> value -> value option =
  fun hs it v ->
  match val_to_int_repr v it with None -> None | Some(i) ->
  Some(val_of_loc(ip_cast hs i))

let pi_cast : heap_state -> loc -> int_repr option = fun hs l ->
  match l with
  | (ProvNull, a) when Z.equal a Z.zero -> Some(IRInt(Z.zero))
  | _                                   ->
  if block_alive hs l then Some(IRLoc(l)) else None

let wrapped_pi_cast : heap_state -> int_type -> value -> value option =
  fun hs it v ->
  match val_to_loc v with None -> None | Some(l) ->
  match pi_cast hs l with None -> None | Some(i) ->
  val_of_int_repr i it

(** Arithmetic operations. *)

type op_Z = Z.t -> Z.t -> Z.t

let arith_binop : op_Z -> int_type -> value -> value -> value option =
  fun op it v1 v2 ->
  match val_to_Z_weak v1 it with None -> None | Some(z1) ->
  match val_to_Z_weak v2 it with None -> None | Some(z2) ->
  let z = op z1 z2 in
  val_of_Z (if it.it_signed then z else Z.rem z (int_modulus it)) it

let add : int_type -> value -> value -> value option = arith_binop Z.add
let sub : int_type -> value -> value -> value option = arith_binop Z.sub
let mul : int_type -> value -> value -> value option = arith_binop Z.mul

(** Relational operators on integers. *)

type op_bool = Z.t -> Z.t -> bool

let arith_rel : op_bool -> int_type -> value -> value -> value option =
  fun op it v1 v2 ->
  match val_to_Z_weak v1 it with None -> None | Some(z1) ->
  match val_to_Z_weak v2 it with None -> None | Some(z2) ->
  Some(val_of_bool (op z1 z2) i32)

let eq  : int_type -> value -> value -> value option = arith_rel Z.eq
let ne  : int_type -> value -> value -> value option = arith_rel Z.ne
let lt  : int_type -> value -> value -> value option = arith_rel Z.lt
let gt  : int_type -> value -> value -> value option = arith_rel Z.gt
let leq : int_type -> value -> value -> value option = arith_rel Z.leq
let geq : int_type -> value -> value -> value option = arith_rel Z.geq

(** Relational operators on (non-NULL) pointers. *)

let same_alloc_id : loc -> loc -> bool = fun (prov1,_) (prov2,_) ->
  match (prov1, prov2) with
  | (ProvAlloc(Some(id1)), ProvAlloc(Some(id2))) -> Z.equal id1 id2
  | (_                   , _                   ) -> false

let ptr_rel : bool -> op_bool -> heap_state -> loc -> loc -> bool option =
  fun is_eq op hs l1 l2 ->
  if not (valid_ptr hs l1) then None else
  if not (valid_ptr hs l2) then None else
  if not (is_eq || same_alloc_id l1 l2) then None else
  Some(op (snd l1) (snd l2))

let ptr_eq  : heap_state -> loc -> loc -> bool option = ptr_rel true Z.eq
let ptr_ne  : heap_state -> loc -> loc -> bool option = ptr_rel true Z.ne
let ptr_lt  : heap_state -> loc -> loc -> bool option = ptr_rel false Z.lt
let ptr_gt  : heap_state -> loc -> loc -> bool option = ptr_rel false Z.gt
let ptr_leq : heap_state -> loc -> loc -> bool option = ptr_rel false Z.leq
let ptr_geq : heap_state -> loc -> loc -> bool option = ptr_rel false Z.geq

let wrap_ptr_rel : (heap_state -> loc -> loc -> bool option)
                   -> heap_state -> value -> value -> value option =
  fun f hs v1 v2 ->
  match val_to_loc v1 with None -> None | Some(l1) ->
  match val_to_loc v2 with None -> None | Some(l2) ->
  match f hs l1 l2 with None -> None | Some(b) ->
  Some(val_of_bool b i32)

(** Operation to copy the provenance. *)

let copy_alloc_id : heap_state -> int_repr -> loc -> loc option =
  fun hs i l ->
  let l_res = (fst l, int_repr_to_Z i) in
  if not (valid_ptr hs l_res) then None else Some(l_res)

let wrapped_copy_alloc_id : heap_state -> value -> value -> value option =
  fun hs v1 v2 ->
  match val_to_int_repr v1 uintptr_t with None -> None | Some(i) ->
  match val_to_loc v2 with None -> None | Some(l) ->
  match copy_alloc_id hs i l with None -> None | Some(l) ->
  Some(val_of_loc l)

(** Basic operation on the heap. *)

let heap_read : addr -> int -> (hcell -> bool) -> heap -> value option =
  fun a n pred h ->
  let rec loop acc a n =
    match n with
    | 0 -> Some(List.rev acc)
    | _ ->
    try
      let hc = AddrM.find a h in
      if pred hc then loop (hc.hc_value :: acc) (Z.succ a) (n - 1) else None
    with Not_found -> None
  in
  Printf.fprintf stderr "heap_read %a %d\n%!" Z.output a n;
  loop [] a n

let heap_write : addr -> value -> (hcell option -> mbyte -> hcell)
                 -> heap -> heap option =
  fun a v fn h ->
  let rec loop acc a v =
    match v with
    | []     -> Some(acc)
    | b :: v ->
    let hc = fn (try Some(AddrM.find a h) with Not_found -> None) b in
    loop (AddrM.add a hc acc) (Z.succ a) v
  in
  loop h a v 

let heap_free : addr -> int -> heap -> heap = fun a n h ->
  let rec loop acc a n =
    match n with
    | 0 -> acc
    | _ -> loop (AddrM.remove a acc) (Z.succ a) (n - 1)
  in
  loop h a n

let heap_region_is_free : addr -> int -> heap -> bool = fun a n h ->
  let rec loop a n =
    match n with
    | 0 -> true
    | _ -> not (AddrM.mem a h) && loop (Z.succ a) (n - 1)
  in
  loop a n

let heap_alloc : addr -> value -> alloc_id -> heap -> heap = fun a v id h ->
  let rec loop acc a v =
    match v with
    | []     -> acc
    | b :: v ->
        let hc = {hc_alloc_id = id; hc_lock_state = RSt(0); hc_value = b} in
        loop (AddrM.add a hc acc) (Z.succ a) v
  in
  loop h a v

(** Non atomic read/writes. *)

let na_prepare_read : loc -> int -> heap -> heap option = fun l n h ->
  Printf.fprintf stderr "na_prepare_read %a %d _\n%!" pp_loc l n;
  let pred hc =
    match (fst l, hc.hc_lock_state) with
    | (ProvAlloc(Some(id)), RSt(_)) -> id = hc.hc_alloc_id
    | (_                  , _     ) -> false
  in
  match heap_read (snd l) n pred h with
  | None    -> None
  | Some(v) ->
  let fn hco _ =
    (* The case where [hco = None is unreachable. *)
    let hc = match hco with Some(hc) -> hc | None -> assert false in
    match hc.hc_lock_state with
    | RSt(n) -> {hc with hc_lock_state = RSt(n+1)}
    | _      -> assert false (* Unreachable. *)
  in
  heap_write (snd l) v fn h

let na_read : loc -> int -> heap -> (value * heap) option = fun l n h ->
  Printf.fprintf stderr "na_read %a %d _\n%!" pp_loc l n;
  let pred hc =
    match (fst l, hc.hc_lock_state) with
    | (ProvAlloc(Some(id)), RSt(n)) -> n > 0 && id = hc.hc_alloc_id
    | (_                  , _     ) -> false
  in
  match heap_read (snd l) n pred h with
  | None    -> None
  | Some(v) ->
  let fn hco _ =
    (* The case where [hco = None is unreachable. *)
    let hc = match hco with Some(hc) -> hc | None -> assert false in
    match hc.hc_lock_state with
    | RSt(n) -> {hc with hc_lock_state = RSt(n-1)}
    | _      -> assert false (* Unreachable. *)
  in
  match heap_write (snd l) v fn h with
  | None    -> assert false (* Unreachable. *)
  | Some(h) -> Some(v, h)

let na_prepare_write : loc -> value -> heap -> heap option = fun l v h ->
  Printf.fprintf stderr "na_prepare_write %a _ _\n%!" pp_loc l;
  let n = List.length v in
  let pred hc =
    match (fst l, hc.hc_lock_state) with
    | (ProvAlloc(Some(id)), RSt(0)) -> id = hc.hc_alloc_id
    | (_                  , _     ) -> false
  in
  match heap_read (snd l) n pred h with
  | None    -> None
  | Some(v) ->
  let fn hco _ =
    (* The case where [hco = None is unreachable. *)
    let hc = match hco with Some(hc) -> hc | None -> assert false in
    match hc.hc_lock_state with
    | RSt(0) -> {hc with hc_lock_state = WSt}
    | _      -> assert false (* Unreachable. *)
  in
  heap_write (snd l) v fn h

let na_write : loc -> value -> heap -> heap option = fun l v h ->
  Printf.fprintf stderr "na_write %a _ _\n%!" pp_loc l;
  let n = List.length v in
  let pred hc =
    match (fst l, hc.hc_lock_state) with
    | (ProvAlloc(Some(id)), WSt) -> id = hc.hc_alloc_id
    | (_                  , _  ) -> false
  in
  match heap_read (snd l) n pred h with
  | None    -> None
  | Some(_) ->
  let fn hco b =
    (* The case where [hco = None is unreachable. *)
    let hc = match hco with Some(hc) -> hc | None -> assert false in
    match hc.hc_lock_state with
    | WSt -> {hc with hc_lock_state = RSt(0); hc_value = b}
    | _   -> assert false (* Unreachable. *)
  in
  match heap_write (snd l) v fn h with
  | None    -> assert false (* Unreachable. *)
  | Some(h) -> Some(h)

(** Sequentially consistent read/writes. *)

(* Returns an unchanged heap in case of success. *)
let sc_read : loc -> int -> heap -> (value * heap) option = fun l n h ->
  let pred hc =
    match (fst l, hc.hc_lock_state) with
    | (ProvAlloc(Some(id)), RSt(_)) -> id = hc.hc_alloc_id
    | (_                  , _     ) -> false
  in
  match heap_read (snd l) n pred h with
  | None    -> None
  | Some(v) -> Some(v, h)

let sc_write : loc -> value -> heap -> heap option = fun l v h ->
  let n = List.length v in
  let pred hc =
    match (fst l, hc.hc_lock_state) with
    | (ProvAlloc(Some(id)), RSt(0)) -> id = hc.hc_alloc_id
    | (_                  , _     ) -> false
  in
  match heap_read (snd l) n pred h with
  | None    -> None
  | Some(_) ->
  let fn hco b =
    (* The case where [hco = None is unreachable. *)
    let hc = match hco with Some(hc) -> hc | None -> assert false in
    {hc with hc_value = b}
  in
  heap_write (snd l) v fn h

let cas : value -> value -> value -> int_type -> heap
          -> (value * heap) option =
  fun v1 v2 v3 it h ->
  match val_to_loc v1 with None -> None | Some(l1) ->
  match val_to_loc v2 with None -> None | Some(l2) ->
  let rst1_is_0 = ref true in
  let pred1 hc =
    match (fst l1, hc.hc_lock_state) with
    | (ProvAlloc(Some(id)), RSt(n)) -> if n <> 0 then rst1_is_0 := false;
                                       id = hc.hc_alloc_id
    | (_                  , _     ) -> false
  in
  match heap_read (snd l1) (bytes_per_int it) pred1 h with
  | None     -> None
  | Some(vo) ->
  let rst2_is_0 = ref true in
  let pred2 hc =
    match (fst l2, hc.hc_lock_state) with
    | (ProvAlloc(Some(id)), RSt(n)) -> if n <> 0 then rst2_is_0 := false;
                                       id = hc.hc_alloc_id
    | (_                  , _     ) -> false
  in
  match heap_read (snd l2) (bytes_per_int it) pred2 h with
  | None     -> None
  | Some(ve) ->
  match val_to_Z_weak vo it with None -> None | Some(z1) ->
  match val_to_Z_weak ve it with None -> None | Some(z2) ->
  if List.length v3 <> bytes_per_int it then None else
  let success = Z.equal z1 z2 in
  let rv = val_of_bool success bool_it in
  if success then
    if !rst1_is_0 then
      let fn hco b =
        (* The case where [hco = None is unreachable. *)
        let hc = match hco with Some(hc) -> hc | None -> assert false in
        {hc with hc_value = b}
      in
      match heap_write (snd l1) v3 fn h with
      | None    -> None
      | Some(h) -> Some(rv, h)
    else None
  else
    if !rst2_is_0 then
      let fn hco b =
        (* The case where [hco = None is unreachable. *)
        let hc = match hco with Some(hc) -> hc | None -> assert false in
        {hc with hc_value = b}
      in
      match heap_write (snd l2) vo fn h with
      | None    -> None
      | Some(h) -> Some(rv, h)
    else None

(** Allocation and free. *)

let free_block : loc -> int -> heap_state -> heap_state option =
  fun (prov, a) n {hs_heap = h; hs_allocs = m} ->
  (* Check that the location as a corresponding live allocation. *)
  match prov_to_aid prov with None -> None | Some(id) ->
  match AllocM.find_opt id m with None -> None | Some(al) ->
  if not al.al_alive then None else
  (* Check that there is no concurent read or write on the heap. *)
  let pred hc =
    match hc.hc_lock_state with
    | RSt(0) -> id = hc.hc_alloc_id
    | _      -> false
  in
  match heap_read a n pred h with None -> None | _ ->
  (* Unmap the region in the heap, mark the allocation as dead. *)
  Some({
    hs_heap   = heap_free a n h;
    hs_allocs = AllocM.add id {al with al_alive = false} m;
  })

let free_block_wrapper : loc -> heap_state -> heap_state option = fun l hs ->
  match prov_to_aid (fst l) with None -> None | Some(id) ->
  match AllocM.find_opt id hs.hs_allocs with None -> None | Some(al) ->
  free_block l al.al_len hs

(* FIXME find a valid address? *)
let alloc_new_block : loc -> value -> heap_state -> heap_state option =
  fun (prov, a) v {hs_heap = h; hs_allocs = m} ->
  (* Check that the allocation identifier is free, create allocation. *)
  Printf.fprintf stderr "alloc_new_block %a\n%!" Z.output a;
  match prov_to_aid prov with None -> None | Some(id) ->
  match AllocM.find_opt id m with Some(_) -> None | _ ->
  let al = {al_start = a; al_len = List.length v; al_alive = true;} in
  if not (allocation_in_range al) then None else
  (* Check that the heap region is not mapped. *)
  if not (heap_region_is_free a (List.length v) h) then None else
  Some({
    hs_heap   = heap_alloc a v id h;
    hs_allocs = AllocM.add id al m;
  })
