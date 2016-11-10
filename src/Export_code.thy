theory Export_code
imports Find_tree_stack Insert_tree_stack Delete_tree_stack "~~/src/HOL/Library/Code_Target_Numeral"
begin


export_code "Code_Numeral.nat_of_integer" "Code_Numeral.int_of_integer" 

dest_core

mk_fts_state step_fts dest_fts_state 
  wellformed_fts wf_fts_trans Find_tree_stack.focus_to_leaves

mk_its_state step_its dest_its_state  
  wellformed_its_state wf_its_trans Insert_tree_stack.focus_to_leaves
  
mk_dts_state step_dts
  wellformed_dts_state wf_dts_trans Delete_tree_stack.focus_to_leaves

in OCaml file "ocaml/btree_generated.ml"

end