theory Constants 
imports Main
begin

(*begin constants*)
consts min_leaf_size :: nat
consts max_leaf_size :: nat
consts min_node_keys :: nat
consts max_node_keys :: nat
(*end constants*)


(*begin wf constants*)
definition wellformed_constants :: "bool" where
"wellformed_constants == (
let wf_node_constants =
(1 <= min_node_keys 
&
(max_node_keys = 2 * min_node_keys
| max_node_keys = Suc (2 * min_node_keys))
)
in
let (wf_leaf_constants) =
(1 <= min_leaf_size
& 
(max_leaf_size = 2 * min_leaf_size 
| max_leaf_size = Suc (2 * min_leaf_size))
)
in
wf_node_constants & wf_leaf_constants
)"
(*end wf constants*)

(*
occasionally we need to allow the root to be small, or perhaps
(in delete) a node or leaf to be small
case class Rmbs(is_small:Boolean) // the root is a leaf, with less than min_leaf_size kvs

the problem is that the min size is ideally hidden in the wf
code, not elsewhere; also, elsewhere we don't want to have to
check whether something is a leaf or not etc; so at the call
site, we want to say that something is a small leaf, node etc.
When checking, we need to find a lower bound if something is a
leaf or a node, based on rmbs; note that we only ever consider
"small" nodes/leavesat the "root" (of the tree or subtree); for
all other nodes, we check as normal
*)

(*begin min size type def*)
datatype min_size_t = Small_root_node_or_leaf
  | Small_node
  | Small_leaf


type_synonym ms_t = "min_size_t option"
(*end min size type def*)
end
