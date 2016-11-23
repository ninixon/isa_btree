theory Export_code
imports Find_tree_stack Insert_tree_stack Delete_tree_stack "~~/src/HOL/Library/Code_Target_Numeral"
"~~/src/HOL/Library/Code_Char"
begin


export_code "Code_Numeral.nat_of_integer" "Code_Numeral.int_of_integer" 

(* these initial exports are to force the order of exported code mods; unfortunately isabelle can reorder when there are no dependencies *)
Constants.min_leaf_size 
Prelude.from_to
Key_value_types.key_ord
Key_value.key_lt
Tree.dest_Node
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

in OCaml file "generated/gen_btree.ml"

(*
print_codesetup

print_codeproc
*)
end