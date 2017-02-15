set -a # export all vars
# set -x # debug

function new_bak() {
    local n=1 
    while [ -f "$1.bak.$n" ]; do ((++n)); done
    echo "$1.bak.$n"
}

root=$(realpath $(dirname $BASH_SOURCE))/../..

 # if using nix, this may not be present
test -f $root/config.sh && source $root/config.sh

PKGS="-package num,yojson,ppx_deriving_yojson,batteries,bos.setup \
  -package ppx_assert,ppx_assert.runtime-lib,sexplib,core,lru-cache,tjr_lib,extunix,core_kernel"

SYNTAX="" # "-syntax camlp4o" # simplify: use for every file
FLGS="-g -thread"

# 8~"pattern-matching is not exhaustive"; 
# 11~"this match case is unused";
# 26~"unused variable s2"
# 40~It is not visible in the current scope, and will not be selected if the type becomes unknown.
WARN="-w @f@p@u@s@40-8-11-26-40"

# these include syntax, so should work on all files; may be overridden in ocamlc.sh
  ocamlc="$DISABLE_BYTE ocamlfind ocamlc   $FLGS $WARN $PKGS $SYNTAX"
ocamlopt="$DISABLE_NTVE ocamlfind ocamlopt $FLGS $WARN $PKGS $SYNTAX"
ocamldep="ocamlfind ocamldep $PKGS"

mk_cma="$DISABLE_BYTE ocamlfind ocamlc $FLGS "
mk_cmxa="$DISABLE_NTVE ocamlfind ocamlopt $FLGS"

# gen_isa.ml 

# mls ----------------------------------------

#btree.ml 

mls=" \
gen_isa.ml \
our.ml \
test.ml pickle.ml btree_api.ml btree_util.ml \
btree.ml \
btree_simple.ml \
ext_in_mem.ml ext_block_device.ml \
ext_int_int_store.ml ext_bytestore.ml ext_string_int.ml"

# test_in_mem.ml  test_ii.ml

cmos="${mls//.ml/.cmo}"
cmxs="${mls//.ml/.cmx}"

natives="test_in_mem.native test_ii.native test_bytestore.native"

bytes="test_in_mem.byte test_ii.byte test_bytestore.byte"





# links ----------------------------------------

function init() {
    link_files=`ls b_from_isa/*.ml c_pre/*.ml d_core/*.ml e_post/*.ml f_test/*.ml`
}

function mk_links() {
    init
    ln -s $link_files .
}


function rm_links() {
    echo "rm_links"
    init
    rm -f _links
    for f in $link_files; do rm -f `basename $f`; done
}


# mlis ----------------------------------------

function mk_mlis() {
    for f in $mls; do $ocamlc -i $f > tmp/${f/.ml/.mli}; done
}
