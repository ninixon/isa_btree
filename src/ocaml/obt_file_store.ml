(* A simple block store backed by a file. *)

(* FIXME error handlign *)

module Block = struct

  type t = bytes (* 4096 *)

  let size = 4096 (* bytes *)

  (* block ref *)
  type r = int

end

(* a thin layer over Unix. *)
module Simple = struct

  type r = Block.r

  type block = Block.t

  type state = Unix.file_descr

  let failwith x = failwith ("obt_file_store: "^x)

  let block_size = Block.size

  let mk_block : bytes -> block = (
    fun x -> 
      assert(Bytes.length x = block_size);
      x
  )

  let r_to_off r = block_size * r

  let read : state -> r -> block = (
    fun s r -> 
      try Unix.(
          let _ = lseek s (r_to_off r) SEEK_CUR in
          let buf = Bytes.make block_size (Char.chr 0) in (* bytes are mutable *)
          let n = read s buf 0 block_size in
          let _ = assert (n=block_size) in
          buf)
      with _ -> failwith "read"  (* FIXME *)
  )

  let write: state -> r -> block -> unit = (
    fun s r buf -> 
      try Unix.(
          let _ = lseek s (r_to_off r) SEEK_CUR in        
          let n = single_write s buf 0 block_size in
          let _ = assert (n=block_size) in
          ())
      with _ -> failwith "write"  (* FIXME *)
  )

  let create: string -> state = Unix.(
      fun s ->
        openfile s [O_RDWR] 0o640 
    )


end


module File_store (* : Our.Store_t *) = struct

  open Our
  open Simple

  type page_ref = int [@@deriving yojson]
  type page = block
  type store = state
  type store_error = string

  let alloc p s = Unix.(
      try (
        (* go to end, identify corresponding ref, and write *)
        let n = lseek s 0 SEEK_END in
        let _ = assert (n mod block_size = 0) in
        let r = n / block_size in
        let _ = Simple.write s r p in
        (s,Our.Util.Ok(r))    
      )
      with _ -> (s,Our.Util.Error "File_store.alloc")
  )


  let page_ref_to_page : page_ref -> store -> store * (page, store_error) Util.rresult = (
    fun r s ->
      try (
        (s,Util.Ok(read s r))
      )
      with _ -> (s,Util.Error "File_store.page_ref_to_page")
  )

  let dest_Store : store -> page_ref -> page = (
    fun s r -> read s r
  )


  (* FIXME remove; not proper part of interface *)
  let empty_store : unit -> store * page_ref = (fun _ -> failwith "empty_store")

end


(* frame mapping for int int kv *)
module Int_int = struct

  module Store = File_store

  module Key_value_types = struct
    type key = int[@@deriving yojson]
    type value_t = int[@@deriving yojson]
    let key_ord (x:int) y = Pervasives.compare x y
    let equal_value x y = (x=y)
  end

  let block_size = Block.size

  let int_size = 4

  let max_node_keys = block_size / int_size -2
  let max_leaf_size = block_size / int_size -2


  (* format: int node_or_leaf; int number of entries; entries *)

  type pframe =  
      Node_frame of (Key_value_types.key list * Store.page_ref list) |
      Leaf_frame of (Key_value_types.key * Key_value_types.value_t) list[@@deriving yojson]



  (* buf is Bytes *)
  let ints_to_bytes (is:int32 list) buf = Int32.(
      let is = Array.of_list is in
      let l = Array.length is in
      let _ = assert (Bytes.length buf >= 4*l) in
      for i = 0 to l-1 do
        let the_int = is.(i) in
        for j = 0 to 3 do 
          let off = 4*i+j in
          let c = (shift_right the_int (8*j)) |> logand (of_int 255) in
          Bytes.set buf off (Char.chr (to_int c))
        done
      done;
      ()
    )

  let bytes_to_ints buf = Int32.(
      let _ = assert (Bytes.length buf mod 4 = 0) in
      let l = Bytes.length buf / 4 in
      let is = Array.make l (Int32.of_int 0) in
      for i = 0 to l-1 do
        for j = 0 to 3 do
          Int32.(
            let off = 4*i+j in
            let c = (Bytes.get buf off) in
            let d = c|>Char.code|>of_int|>(fun x -> shift_left x(8*j)) in
            is.(i) <- add is.(i) d)
        done
      done;
      Array.to_list is
    )


  let frame_to_page' : pframe -> Store.page = (
    fun p ->
      let is = (
        match p with
          Node_frame(ks,rs) -> ([0;List.length ks]@ks@rs)
        | Leaf_frame(kvs) -> (
            [1;List.length kvs]@(List.map fst kvs)@(List.map snd kvs))
      ) |> List.map Int32.of_int
      in
      let buf = Bytes.create block_size in
      ints_to_bytes is buf;
      buf
    )

  let page_to_frame' : Store.page -> pframe = (
    fun buf -> 
      let is = bytes_to_ints buf|>List.map Int32.to_int in
      match is with
      | 0::l::rest -> (
          let (ks,rs) = rest|>BatList.take (l+l+1)|>BatList.split_at l in
          Node_frame(ks,rs))
      | 1::l::rest -> (
          let (ks,vs) = rest|>BatList.take (2*l) |> BatList.split_at l in
          let kvs = List.combine ks vs in
          Leaf_frame(kvs)
        )
  )

  (* FIXME can remove these once code is trusted *)
  let frame_to_page = fun f -> 
    let p = frame_to_page' f in
    let f' = page_to_frame' p in
    let _ = assert (f' = f) in
    p

  let page_to_frame = fun p -> 
    let f = page_to_frame' p in
    let p' = frame_to_page' f in
    let _ = assert Bytes.(to_string p = to_string p') in
    f



end
