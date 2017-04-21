theory Export_code
imports 
"$SRC/d_find_ins_del/Find"
"$SRC/d_find_ins_del/Delete"
"$SRC/d_find_ins_del/Insert"
"$SRC/d_find_ins_del/Insert_many"
"$SRC/d_find_ins_del/Leaf_stream"
Code_Numeral 
"~~/src/HOL/Library/Code_Target_Numeral"
"~~/src/HOL/Library/Code_Char"
begin


export_code "Code_Numeral.nat_of_integer" "Code_Numeral.int_of_integer" 

Util.from_to
Util.String_error

Key_value.key_lt

(* frame_types *)
Frame.Node_frame



(* params *)
Params.compare_k
Params.constants
Params.MM
store_read
store_alloc
store_free


(* monad *)
Monad.dest_MM fmap  bind

(* store *) 
mk_r2f


(* tree *)
Tree.dest_Node
Tree_stack.dest_ts_frame
Tree_stack.stack_to_lu_of_child
tree_to_leaves 
wellformed_tree


(* find *)
empty_btree
mk_find_state
dest_f_finished
find_step
wellformed_find_state 

(* insert *)
Insert.mk_insert_state
Insert.dest_i_finished
Insert.I1 Insert.I2 Insert.I_down Insert.I_up Insert.I_finished
Insert.insert_step
Insert.wellformed_insert_state

(* insert_many *)
Insert_many.mk_insert_state
Insert_many.dest_i_finished
Insert_many.I1 Insert_many.I2 Insert_many.I_down Insert_many.I_up Insert_many.I_finished
Insert_many.insert_step


(* delete *)
mk_delete_state
dest_d_finished
D_small_leaf D_small_node D_updated_subtree D_down D_up D_finished  
Delete.delete_step
wellformed_delete_state

(* leaf_stream *)
mk_ls_state lss_is_finished dest_LS_leaf lss_step


in OCaml file "/tmp/isa_export.ml"


(*

*)


(* tree stack versions







Tree_stack.dest_core

key_ord

tree_to_leaves wellformed_tree

(* find *)
mk_fts_state step_fts dest_fts_state 
  wellformed_fts wf_fts_trans Find_tree_stack.focus_to_leaves

(* insert *)
Inserting_one Inserting_two
Its_down Its_up
mk_its_state step_its dest_its_state  
  wellformed_its_state wf_its_trans Insert_tree_stack.focus_to_leaves
 
(* delete *)
D_small_leaf D_small_node D_updated_subtree
Dts_down Dts_up Dts_finished  
mk_dts_state step_dts dest_dts_state
  wellformed_dts_state wf_dts_trans Delete_tree_stack.focus_to_leaves

  *)



(*
print_codesetup

print_codeproc
*)
end