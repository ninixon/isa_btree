(* Things related to block devices *)

(* FIXME put everything in monads, so that we can easily compose things *)

(* FIXME make a config modules, which contains basic config params - default blocksize; how many bytes to store an int etc *)

open Sexplib.Std (* for ppx_assert *)


(* basic type for in-mem block, and on-disk block ref -------------------- *)

(* FIXME move to config? *)
module Defaults = struct

  (* page of block? at this level we prefer block; in mem we use page *)
  type block = Btree_api.Simple.page 

  let page_size = 4096 (* bytes *)

  (* block ref *)
  type block_ref = Btree_api.Simple.page_ref[@@deriving yojson]

  (* to make an empty block before writing to disk *)
  let empty () = String.make page_size (Char.chr 0) 

end

(* a block device backed by a file ---------------------------------------- *)

module Blkdev_on_fd (* : BLOCK_DEVICE *) = struct
  open Btree_api

  type fd = Unix.file_descr

  type t = fd
  type r = Defaults.block_ref
  type blk = Defaults.block

  type 'a m = ('a,t) Sem.m
               
  let block_size = Defaults.page_size

  let string_to_blk: string -> (blk,string) result = (
    fun x -> 
      let l = String.length x in
      let c = Pervasives.compare l block_size in
      match c with
      | 0 -> Ok x
      | _ when c < 0 -> Ok (x^(String.make (block_size - l) (Char.chr 0)))
      | _ -> Error (__LOC__ ^ "string too large: " ^ x)
  )

  let safely = Sem.safely
  let return = Sem.return
  let bind = Sem.bind

  let get_fd : unit -> fd m = fun () -> (fun s -> (s,Ok s))

  let read : r -> blk m = (
      fun r -> 
        safely __LOC__ (
          get_fd ()
          |> bind Unix.(fun fd ->
              ignore (lseek fd (r * block_size) SEEK_SET);
              let buf = Bytes.make block_size (Char.chr 0) in 
              let n = read fd buf 0 block_size in
              assert (n=block_size);
              return buf)))


  let write: r -> blk -> unit m = (
    fun r buf -> 
      safely __LOC__ (
        get_fd ()
        |> bind Unix.(fun fd ->
          ignore (lseek fd (r * block_size) SEEK_SET);
          let n = single_write fd buf 0 block_size in
          assert (n=block_size);
          return ())))


  let sync : unit -> unit m = ExtUnixSpecific.(fun () -> 
      safely __LOC__ (
        get_fd () |> bind (fun fd -> ExtUnixSpecific.fsync fd; return ())))
      
(*
  let open_file: string -> fd = Unix.(
      fun s -> openfile s [O_RDWR] 0o640 )
*)

end

let _ = (module Blkdev_on_fd : Btree_api.BLOCK_DEVICE)



(* a store backed by a file ---------------------------------------- *)

(* we target Btree_api.Simple.STORE *)

module Filestore = struct
  open Btree_api

  include Btree_api.Simple

  type store = { 
    fd: Blkdev_on_fd.fd; 
    free_ref: page_ref;
  }  

  let page_size = Defaults.page_size

  open Blkdev_on_fd

  type 'a m = ('a,store) Sem.m

  let fd_to_empty_store: fd -> store = (fun fd -> {fd;free_ref=0})

  let return = Sem.return

  let inc_free: int -> unit m = (
    fun n s -> ({s with free_ref=s.free_ref+n},Ok ()))

  let get_free: unit -> int m = (fun () s -> (s,Ok s.free_ref))

  (* alloc without write; free block can then be used to write data
     outside the btree *)
  let alloc_block: unit -> page_ref m = (fun () ->
    get_free () |> bind (fun r -> inc_free 1 |> bind (fun () -> return r)))

  let lens = Lens.{from=(fun s -> (s.fd,s)); to_=(fun (fd,s) -> {s with fd=fd})}

  let alloc: page -> page_ref m = (
    fun p -> 
      alloc_block ()
      |> bind (
        fun r -> 
          Sem.with_lens lens (Blkdev_on_fd.write r p)
          |> bind (fun () -> return r)))

  let free: page_ref list -> unit m = (fun ps -> Sem.return ())

  let page_ref_to_page: page_ref -> page m = (
    fun r -> Sem.with_lens lens (Blkdev_on_fd.read r))
  
  let dest_Store : store -> page_ref -> page = (
    fun s -> 
      let run = Sem.unsafe_run (ref s) in
      fun r -> run (page_ref_to_page r))

  let sync: unit -> unit m = (fun () -> 
      Blkdev_on_fd.sync () 
      |> Sem.with_lens lens)

  let write: r -> blk -> unit m = (fun r blk ->
      Blkdev_on_fd.write r blk
      |> Sem.with_lens lens)

end

let _ = (module Filestore : Btree_api.STORE)

let _ = (module Filestore : Btree_api.Simple.STORE)




(* recycling filestore -------------------------------------------------------- *)

(* a filestore which caches page writes and recycles page refs *)

(* we maintain a set of blocks that have been allocated and not freed
   since last sync (ie which need to be written), and a set of page
   refs that have been allocated since last sync and freed without
   being synced (ie which don't need to go to store at all) *)

(* FIXME worth checking no alloc/free misuse? *)


module Set_r = Btree_util.Set_int


module Cache = Map.Make(
  struct 
    type t = Filestore.page_ref
    let compare: t -> t -> int = Pervasives.compare
  end)


module Recycling_filestore = struct
  open Btree_api

  type page_ref = Filestore.page_ref [@@deriving yojson]
  type page = Filestore.page
  let page_size = Filestore.page_size  

  type store = { 
    fs: Filestore.store; 
    cache: page Cache.t;  (* a cache of pages which need to be written *)
    freed_not_synced: Set_r.t  (* really this is "don't write to store on sync" *)
    (* could be a list - we don't free something that has already been freed *)
  }

  type 'a m = ('a,store) Sem.m


  let from_filestore = 
    fun fs -> {fs; cache=Cache.empty;freed_not_synced=Set_r.empty}

  let lens = 
    Lens.({from=(fun s -> (s.fs,s)); to_=(fun (fs,s) -> {s with fs=fs})})
(*
  let lift: 'a Filestore.m -> 'a m = (
    fun m1 -> fun s ->
      m1 |> Sem.run s.fs 
      |> (fun (s',res) -> ({s with fs=s'},res)))
*)

  let alloc_block: unit -> page_ref m = 
    fun () -> Filestore.alloc_block () |> Sem.with_lens lens

  let get_freed_not_synced: store -> page_ref option = (
    fun s -> 
      match (Set_r.is_empty s.freed_not_synced) with
      | true -> None
      | false -> 
        s.freed_not_synced 
        |> Set_r.min_elt 
        |> (fun r -> Some r))
  
  (* FIXME following should use the monad from filestore *)
  let alloc : page -> page_ref m = (
    fun p -> 
    fun s -> 
      match get_freed_not_synced s with
      | None -> Filestore.(
          let free_ref = s.fs.free_ref in
          let s' = { 
            s with
            fs={s.fs with free_ref = free_ref+1};
            cache=Cache.add free_ref p s.cache }
          in
          (s',Ok free_ref))
      | Some r -> (
          (* just return a ref we allocated previously *)
          let s' = {
            s with 
            freed_not_synced=(Set_r.remove r s.freed_not_synced);
            cache=(Cache.add r p s.cache) } 
          in
          (s',Ok r)))

  let free : page_ref list -> unit m = (
    fun ps -> 
    fun s -> 
      let s' = {
        s with
        freed_not_synced=(
          Set_r.union s.freed_not_synced (Set_r.of_list ps)) }
      in
      (s', Ok()))

  let page_ref_to_page: page_ref -> page m = (
    fun r -> 
    fun s -> 
      (* consult cache first *)
      (try Some(Cache.find r s.cache) with Not_found -> None) 
      |> (function
          | Some p -> (s,Ok p)
          | None -> (
              (Filestore.page_ref_to_page r) 
              |> Sem.with_lens lens
              |> Sem.run s)))


  let dest_Store : store -> page_ref -> page = (
    fun s r -> 
      try (Cache.find r s.cache) with Not_found -> Filestore.dest_Store s.fs r)

  (* FIXME at the moment this doesn't write anything to store - that
     happens on a sync, when the cache is written out *)

  let get_freed_not_synced: unit -> Set_r.t m = (fun () s -> (s,Ok s.freed_not_synced))

  let get_cache_bindings: unit -> (page_ref * page) list m = (
    fun () s -> (s,Ok (Cache.bindings s.cache)))

  let clear_cache: unit -> unit m = (
    fun () s -> ({s with cache=Cache.empty},Ok()))

  (* FIXME this should also flush the store cache of course using its
     sync *)
  let rec sync: unit -> unit m = (fun () ->
      get_cache_bindings () |> Sem.bind
        (fun es -> 
           get_freed_not_synced () |> Sem.bind
             (fun f_not_s -> 
                let rec loop es = (
                  match es with 
                  | [] -> (Sem.return ())
                  | (r,p)::es -> (
                      match (Set_r.mem r f_not_s) with 
                      | true -> loop es (* don't sync if freed *)
                      | false -> (
                          (Filestore.(write r p) |> Sem.with_lens lens)
                          |> Sem.bind (fun () -> loop es))))
                in
                loop es |> Sem.bind 
                  (fun () -> clear_cache ()) |> Sem.bind
                  (* make sure we sync these writes to disk *)
                  (fun () -> Filestore.(sync ()) |> Sem.with_lens lens)
             )))

end


let _ = (module Recycling_filestore : Btree_api.STORE)

let _ = (module Recycling_filestore : Btree_api.Simple.STORE)




(* raw block device like /dev/sda1 ---------------------------------------- *)


(* reimpl of blkdev_on_fd *)

(*
module Raw_block_device = struct

  open Btree_api

  let block_size = Defaults.page_size

  module BLK_ = Blkdev_on_fd

  type blk = BLK_.blk

  (* 'a cc is a client request that expects a response of type 'a *)
  type _ cc =   (* client *)
    | Read : int -> blk cc
    | Write: int * blk -> unit cc
    | Sync: unit cc


  (* a sequence of computations returning 'b *)
  type 'b bind_t = 
    | Return: 'b -> 'b bind_t
    | Bind: ('a cc * ('a -> 'b bind_t)) -> 'b bind_t

  let bind f m = Bind(m,f)

  type t = {
    path: string;
    fd: Unix.file_descr;
    free: int (* free block *)
  }

  type 'a ss = ('a * t) (* server value of type 'a *)
      
  open Rresult

  (* lift client computation to server *)
  let rec lift: ('a -> 'b cc) -> ('a ss -> 'b cc ss) = (fun f ->
      fun (a,t) -> (f a, t))

  (* service a client request on the server *)
  let rec step: type g. g cc ss -> g ss = (fun (gm,t) ->
      match gm with
      | Read i -> (
          BLK_.read i |> Sem.run t.fd
          |> (fun (fd',Ok blk) -> (blk,t)))
      | Write (i,blk) -> (
          BLK_.write i blk |> Sem.run t.fd 
          |> (fun (fd',Ok ()) -> ((),t)))
      | Sync -> (
          ExtUnixSpecific.fsync t.fd;
          (),t)
    )

  (* evaluate a sequence of client requests using the server *)
  let rec eval: type b. b bind_t ss -> b ss = (fun (bnd,t) ->
      match bnd with
      | Return b -> (b,t)
      | Bind (am,a_bm) -> (
          step (am,t) 
          |> (fun (a,t') -> (a_bm a) |> (fun b -> eval (b,t')))))

end
*)



  (* FIXME really we should read the free ref from block 0
  let fd_to_nonempty_store: fd -> (store,string) result = (
    fun fd -> 
      let len = Unix.(lseek fd 0 SEEK_END) in     
      assert (len mod page_size = 0);
      let free_ref = len / page_size in
      {fd;free_ref})
*)

  (*
  let existing_file_to_new_store: string -> store = (fun s ->
      let fd = Blkdev_on_fd.open_file s in
      (* now need to write the initial frame *)
      let free_ref = 0 in
      {fd; free_ref})      
   *)

  (*
  let existing_file_to_new_store: string -> store = (fun fn ->
      Filestore.existing_file_to_new_store fn |> (fun fs ->
          {fs; cache=Cache.empty; freed_not_synced=Set_r.empty} ))
*)
    
