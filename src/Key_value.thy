theory Key_value
imports Main
begin

typedecl key
typedecl value_t

(*begin key order operators definition*)
consts key_lt :: "key => key => bool"

definition key_eq :: "key => key => bool" where
  "key_eq k1 k2 == (~ (key_lt k1 k2)) & (~ (key_lt k2 k1))"

definition key_le :: "key => key => bool" where
  "key_le k1 k2 == (key_eq k1 k2) | (key_lt k1 k2)"
(*end key order operators definition*)

definition kv_lt :: "(key * value_t) => (key * value_t) => bool" where
  "kv_lt kv1 kv2 == (key_lt (fst kv1) (fst kv2))"

(*begin check keys definition*)
definition check_keys 
 :: "key option => key list => key option => bool"
where
"check_keys kl ks kr == (
let b1 = (
case kl of None => True 
| Some kl => (! k : set ks. key_le kl k)
)
in
let b2 = (
case kr of None => True 
| Some kr => (! k : set ks. key_lt k kr)
)
in
b1 & b2
)"
(*end check keys definition*)

(*tr: assumes xs are sorted; returns list length if not found*)
(*begin search key to index definition *)
definition search_key_to_index :: "key list => key => nat" where
"search_key_to_index ks k == (
let num_keys = length ks in
let index = List.find (% x. key_lt k (ks!x)) (upt 0 num_keys) in
(case index of None => num_keys
| Some x => x))"
(*end search key to index definition *)
end
