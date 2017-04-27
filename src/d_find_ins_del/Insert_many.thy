theory Insert_many
imports Find
begin

(* like Insert, but allows to insert many keys during a single traversal to a leaf *)

datatype ('k,'v,'r) fo (* i_t*) = I1 "'r*('k*'v)s" | I2 "('r*'k*'r) * ('k*'v)s"

type_synonym ('k,'v,'r) d = "('k,'v,'r)fs * ('v * ('k*'v)s)"

type_synonym ('k,'v,'r) u = "('k,'v,'r)fo*('k,'r)rstk"

datatype (dead 'k,dead 'v,dead 'r) ist (* i_state_t*) = 
  I_down "('k,'v,'r)d"
  | I_up "('k,'v,'r)u"
  | I_finished "'r * ('k*'v)s"

definition mk_insert_state :: "'k \<Rightarrow> 'v \<Rightarrow> ('k*'v)s \<Rightarrow> 'r \<Rightarrow> ('k,'v,'r)ist" where
"mk_insert_state k v kvs r = (I_down (mk_find_state k r,(v,kvs)))"


definition dest_i_finished :: "('k,'v,'r) ist \<Rightarrow> ('r * ('k*'v)s) option" where
"dest_i_finished s = (case s of I_finished (r,kvs) \<Rightarrow> Some (r,kvs) | _ \<Rightarrow> None)"

(* defns ------------------------------------ *)

definition step_down :: "('k,'v,'r) ps1 \<Rightarrow> ('k,'v,'r)d \<Rightarrow> ('k,'v,'r) d MM" where
"step_down ps1 d = (
  let (fs,v) = d in
  find_step ps1 fs |> fmap (% d'. (d',v))
)"

(* insert kv, and as many from new as possible subject to lu bound and max size of 2*max_leaf_size; 
kv<new, and new are sorted in order; return the remaining new that were not inserted
*)
definition kvs_insert_2 :: "'k ps0 \<Rightarrow> 'k option \<Rightarrow> ('k*'v) \<Rightarrow> ('k*'v)s \<Rightarrow> ('k*'v)s \<Rightarrow> ('k*'v)s * ('k*'v)s" where
"kvs_insert_2 ps0 u kv new existing = (
  let (cs,k_ord) = (ps0|>cs',ps0|>cmp_k') in
  let step = (% s. 
    let (acc,new') = s in
    case (length acc \<ge> 2 * cs|>max_leaf_size) of
    True \<Rightarrow> None
    | False \<Rightarrow> (
      case new' of
      [] \<Rightarrow> None
      | (k,v)#new'' \<Rightarrow> (
        let test = % k u.
          (* (check_keys (Params.the_kv_ops|>compare_k) None {k} u) *) (* FIXME equality on keys in generated code :( *)
          case u of None \<Rightarrow> True | Some u \<Rightarrow> key_lt k_ord k u
        in
        case test k u of  
        True \<Rightarrow> (Some(kvs_insert k_ord (k,v) acc,new''))
        | False \<Rightarrow> (None))))
  in
  iter_step step (existing,new)
)"

(* how to split a leaf where there are n > max_leaf_size and \<le> 2*max_leaf_size elts?

we want the first leaf ge the second leaf, and 2nd leaf to have at least min_leaf_size

for second leaf, we want n2=min_leaf_size+delta, where delta is minimal such that n1+n2=n and n1 \<le> max_leaf_size

so n2 = min_leaf_size; n1 = n - min_leaf_size
then delta = n1 - max_leaf_size
n2+=delta
n1-=delta

*)

definition split_leaf :: "constants \<Rightarrow> ('k*'v)s \<Rightarrow> ('k*'v)s * 'k * ('k*'v)s" where
"split_leaf cs0 kvs = (
  let n = List.length kvs in
  let n1 = n in
  let n2 = 0 in
  let delta = cs0|>min_leaf_size in
  let n1 = n1 - delta in
  let n2 = n2 + delta in
  let delta = (n1 - cs0|>max_leaf_size) in
  let n1 = n1 - delta in
  let n2 = n2 + delta in
  let (l,r) = split_at n1 kvs in
  let k = (case r of [] \<Rightarrow> impossible1 (STR ''insert_many: split_leaf'') | (k,v)#_ \<Rightarrow> k) in
  (l,k,r)
)"


definition step_bottom :: "('k,'v,'r) ps1 \<Rightarrow> ('k,'v,'r) d \<Rightarrow> ('k,'v,'r) u MM" where
"step_bottom ps1 d = (
  let (cs,k_ord) = (ps1|>cs,ps1|>cmp_k) in
  let (fs,(v,kvs0)) = d in
  case dest_f_finished fs of 
  None \<Rightarrow> impossible1 (STR ''insert, step_bottom'')
  | Some(r0,k,r,kvs,stk) \<Rightarrow> (
    (ps1|>store_free) (r0#(r_stk_to_rs stk)) |> bind 
    (% _.
    let (l,u) = stack_to_lu_of_child stk in
    let (kvs',kvs0') = kvs_insert_2 (ps1|>ps0') u (k,v) kvs0 kvs in
    let fo = (
      case (length kvs' \<le> cs|>max_leaf_size) of
      True \<Rightarrow> (Leaf_frame kvs' |> (ps1|>store_alloc) |> fmap (% r'. I1(r',kvs0')))
      | False \<Rightarrow> (
        let (kvs1,k',kvs2) = split_leaf cs kvs' in
        Leaf_frame kvs1 |> (ps1|>store_alloc) |> bind
        (% r1. Leaf_frame kvs2 |> (ps1|>store_alloc) |> fmap (% r2. I2((r1,k',r2),kvs0')))) )
    in
    fo |> fmap (% fo. (fo,stk))))
)"

definition step_up :: "('k,'v,'r) ps1 \<Rightarrow> ('k,'v,'r) u \<Rightarrow> ('k,'v,'r) u MM" where
"step_up ps1 u = (
  let (cs,k_ord) = (ps1|>cs,ps1|>cmp_k) in
  let (fo,stk) = u in
  case stk of 
  [] \<Rightarrow> impossible1 (STR ''insert, step_up'') (* FIXME what about trace? can't have arb here; or just stutter on I_finished in step? *)
  | x#stk' \<Rightarrow> (
    let ((ks1,rs1),_,(ks2,rs2)) = dest_ts_frame x in
    case fo of
    I1 (r,kvs0) \<Rightarrow> (
      Node_frame(ks1@ks2,rs1@[r]@rs2) |> (ps1|>store_alloc) |> fmap (% r. (I1 (r,kvs0),stk')))
    | I2 ((r1,k,r2),kvs0) \<Rightarrow> (
      let ks' = ks1@[k]@ks2 in
      let rs' = rs1@[r1,r2]@rs2 in
      case (List.length ks' \<le> cs|>max_node_keys) of
      True \<Rightarrow> (
        Node_frame(ks',rs') |> (ps1|>store_alloc) |> fmap (% r. (I1 (r,kvs0),stk')))
      | False \<Rightarrow> (
        let (ks_rs1,k,ks_rs2) = split_node cs (ks',rs') in  (* FIXME move split_node et al to this file *)
        Node_frame(ks_rs1) |> (ps1|>store_alloc) |> bind
        (% r1. Node_frame (ks_rs2) |> (ps1|>store_alloc) |> fmap 
        (% r2. (I2((r1,k,r2),kvs0),stk'))))
    )
  )
)"

definition insert_step :: "('k,'v,'r)ps1 \<Rightarrow> ('k,'v,'r) ist \<Rightarrow> ('k,'v,'r) ist MM" where
"insert_step ps1 s = (
  let (cs,k_ord) = (ps1|>cs,ps1|>cmp_k) in
  case s of 
  I_down d \<Rightarrow> (
    let (fs,(v,kvs0)) = d in
    case (dest_f_finished fs) of 
    None \<Rightarrow> (step_down ps1 d |> fmap (% d. I_down d))
    | Some _ \<Rightarrow> step_bottom ps1 d |> fmap (% u. I_up u))
  | I_up u \<Rightarrow> (
    let (fo,stk) = u in
    case stk of
    [] \<Rightarrow> (
      case fo of 
      I1 (r,kvs0) \<Rightarrow> return (I_finished (r,kvs0))
      | I2((r1,k,r2),kvs0) \<Rightarrow> (
        (* create a new frame *)
        (Node_frame([k],[r1,r2]) |> (ps1|>store_alloc) |> fmap (% r. I_finished (r,kvs0)))))
    | _ \<Rightarrow> (step_up ps1 u |> fmap (% u. I_up u)))
  | I_finished f \<Rightarrow> (return s)  (* stutter *)
)"

end