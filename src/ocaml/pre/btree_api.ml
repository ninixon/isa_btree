(* various interfaces ---------------------------------------- *)

module type MONAD = sig

  type 'a m

  val return: 'a -> 'a m
  val bind: 'a m -> ('a -> 'b m) -> 'b m

end


module type KEY_VALUE = sig
  type k [@@deriving yojson]
  type v [@@deriving yojson]
  val key_ord : k -> k -> int
  val equal_value : v -> v -> bool (* only for wf checking *)
end

module type CONSTANTS = sig
  val max_leaf_size : int
  val max_node_keys : int
  val min_leaf_size : int
  val min_node_keys : int
end

module type STORE = sig
  module M : MONAD

  type page 
  type page_ref [@@deriving yojson]

  (*  type store 
  type store_error *)
  (* val dest_Store : store -> page_ref -> page (* FIXME remove *) *)
  (* at the moment this is just a hint to the cache api *)
  val alloc : page -> page_ref M.m
  val page_ref_to_page :  page_ref -> page M.m
  val free : page_ref list -> unit M.m

  val sync: unit M.m  (* the btree routines are oblivious to this, but the store should be aware eg to implement recycling filestore *)
end



module type MAP = sig

  module KV : KEY_VALUE
  module ST : STORE
  module M : MONAD

  open KV
  val insert: k -> v -> unit M.m
  val insert_many: (k*v) list -> unit M.m
  val find: k -> v option M.m
  val delete: k -> unit M.m

end



(* simple interface ---------------------------------------- *)

module Simple = struct

  module type S = sig
    module KV : KEY_VALUE
    module ST : sig 
      include STORE with type page_ref = int and type page = string (* ie immutable bytes *)
      val page_size : int (* bytes per page *)
    end

    (* FIXME include in ST? then don't need Sz; what do we need from S?  *)
    module Pickle_parameters : sig
      open Btree_util
      open M_int32s  (* marshall to int32 *)
      val i : int cnv (* assume m_t has length 1 *)
      val k : KV.k cnv (* FIXME make cnv carry info about #bytes needed *)
      val v : KV.v cnv
      (* val r : ST.page_ref cnv  (* FIXME this is just i ! *) *)
    end
      
  end (* S *)

  (* output type of Simple.Make(S) *)
  module type T = sig
    include MAP
  end
end


(* block device ---------------------------------------- *)

(* what is typically provided by the file system; used to provide the store interface *)
module type BLOCK_DEVICE = sig

  type t
  type r
  type blk

  module M : MONAD

  val read: r -> blk M.m
  val write: r -> blk -> unit M.m
  val sync: unit M.m

end
