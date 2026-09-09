#!/bin/zsh
# Stage C circuit identity: native invariants and independent byte/hash checks.
set -eu
chpwd_functions=()
unfunction chpwd 2>/dev/null || true
ROOT=${0:A:h}/..
unset OPAM_SWITCH_PREFIX
zsh $ROOT/dev/dunecho.sh build
zsh $ROOT/dev/dune.sh runtest test/digest --force
print -- "DIGEST-GATES-OK"
