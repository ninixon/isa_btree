theory Tree_stack 
imports Tree 
begin

(* FIXME needs more documentation *)

(* some of these defns could be parametric, but polytypes were getting
a bit clunky, and the defns aren't exposed to the user so we don't
need polymorphism *)



(* node_stack, a stack of frames -------------------------------------------------- *)

(* FIXME rename to stack *)
type_synonym ('k,'a) node_stack = "('k,'a) split_node list"   

(* map a function over the non-'k component *)
definition stack_map :: "('a \<Rightarrow> 'b) \<Rightarrow> ('k,'a) node_stack \<Rightarrow> ('k,'b) node_stack" where
"stack_map f stk = (
  stk |> List.map (split_node_map f))"

definition stack_equal :: "('k,'a) node_stack \<Rightarrow> ('k,'a) node_stack \<Rightarrow> bool" where
"stack_equal s1 s2 = failwith (STR ''FIXME patch'')"


(* tree_stack --------------------- *)

(* a tree_stack has 'a = ('k,'v)tree *)
type_synonym ('k,'v) tree_stack = "('k,('k,'v)tree) node_stack"



(* stack_to_lu_of_child (get bounds of focus) ----------------------- *)

(* get the bound surrounding the focus *)
(* FIXME again this is derived from search_key_to_index etc *)
primrec stack_to_lu_of_child :: "('k,'a) node_stack \<Rightarrow> 'k option * 'k option" where
"stack_to_lu_of_child [] = (None,None)"
| "stack_to_lu_of_child (x#stk') = (
    let (l',u') = stack_to_lu_of_child stk' in
    let (ks1,ks2) = (x|>f_ks1,x|>f_ks2) in    
    let l = (if ks1 \<noteq> [] then Some(ks1|>List.last) else l') in
    let u = (if ks2 \<noteq> [] then Some(ks2|>List.hd) else u') in
    (l,u))"



(* tree_to_stack, stack_to_tree, no_focus --------------------------- *)

(* the n argument ensures the stack has length n; we assume we only call this with n\<le>height t *)
(* FIXME why is focus returned separately? *)
primrec tree_to_stack :: 
  "'k ord \<Rightarrow> 'k \<Rightarrow> ('k,'v)tree \<Rightarrow> nat \<Rightarrow> (('k,'v)tree * ('k,'v)tree_stack)" 
where
"tree_to_stack ord k t 0 = (t,[])"
| "tree_to_stack ord k t (Suc n) = (
    let (fo,stk) = tree_to_stack ord k t n in
    case fo of 
    Leaf kvs \<Rightarrow> (failwith (STR ''tree_to_stack''))
    | Node(ks,ts) \<Rightarrow> (
      let ((ks1,ts1),t',(ks2,ts2)) = split_ks_rs ord k (ks,ts) in
      let frm = \<lparr>f_ks1=ks1,f_ts1=ts1,f_t=t',f_ks2=ks2,f_ts2=ts2\<rparr> in
      (t',frm#stk) ))"

(* when converting a stack to a tree we may provide a new focus *)
fun stack_to_tree :: "('k,'v)tree \<Rightarrow> ('k,'v)tree_stack \<Rightarrow> ('k,'v)tree" where
"stack_to_tree fo ts = (
  case ts of 
  [] \<Rightarrow> fo
  | x#ts' \<Rightarrow> (
    let (ks1,ts1,_,ks2,ts2) = (x|>f_ks1,x|>f_ts1,(),x|>f_ks2,x|>f_ts2) in
    let fo' = Node(ks1@ks2,ts1@[fo]@ts2) in
    stack_to_tree fo' ts' ))"

(* remove "focus"; NOTE 'a option is always None FIXME so why not use unit? *)
definition no_focus :: "('k,'a) node_stack \<Rightarrow> ('k,'a option) node_stack" where
"no_focus stk = (
  stk |> stack_map Some |> (% stk. 
  case stk of [] \<Rightarrow> [] | frm#stk' \<Rightarrow> (frm\<lparr>f_t:=None \<rparr>)#stk'))"



(* add_new_stk_frame; r_stk_to_rs ----------------------------------- *)

definition add_new_stack_frame :: 
  "'k ord => 'k \<Rightarrow> ('k list * 'a list) \<Rightarrow> ('k,'a) node_stack \<Rightarrow> (('k,'a) node_stack * 'a)" 
where
"add_new_stack_frame cmp k ks_rs stk = (
  let (ks,rs) = ks_rs in
  let ((ks1,rs1),r',(ks2,rs2)) = split_ks_rs cmp k (ks,rs) in
  (* let (l,u) = stack_to_lu_of_child stk in *)
  let frm' = \<lparr>f_ks1=ks1,f_ts1=rs1,f_t=r', f_ks2=ks2,f_ts2=rs2 \<rparr> in
  (frm'#stk,r') )"  (* FIXME why return r' explicitly? why not get from f_t? *)


definition r_stk_to_rs :: "('k,'r) node_stack \<Rightarrow> 'r list" where 
"r_stk_to_rs xs = (xs|>List.map f_t)"

end