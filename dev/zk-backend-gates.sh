#!/bin/zsh
# Stage C backend slice: scoped tests and optional external validation.
# Pass a prepared ptau path to add PLONK setup, prove and verify.
set -eu
chpwd_functions=()
unfunction chpwd 2>/dev/null || true
ROOT=${0:A:h}/..
export PATH=/Users/oobi/.opam/zxcaml-p1/bin:$PATH
unset OPAM_SWITCH_PREFIX
if (( $# > 1 )); then
  print -u2 -- "usage: zsh dev/zk-backend-gates.sh [PREPARED_PTAU]"
  exit 64
fi
PTAU=${1:-}
if [[ -n $PTAU && ! -f $PTAU ]]; then
  print -u2 -- "BACKEND-PLONK FAIL cannot read ptau"
  exit 64
fi
zsh $ROOT/dev/dunecho.sh build
zsh $ROOT/dev/dune.sh runtest test/zk --force
if ! command -v snarkjs >/dev/null 2>&1; then
  print -- "BACKEND-SNARKJS PENDING snarkjs not installed"
  exit 3
fi
mkdir -p $ROOT/.gatework
WORK=$(mktemp -d $ROOT/.gatework/backend.XXXXXX)
trap 'rm -rf -- "$WORK"' EXIT
PROBE=$ROOT/_build/default/test/zk/probe.exe
step() {
  if "$@" > $WORK/step.log 2>&1; then return 0; fi
  print -u2 -- "BACKEND-SNARKJS FAIL $1 $2"
  tail -n 8 $WORK/step.log >&2
  exit 1
}
step $PROBE mul 6 7 $WORK/mul
step $PROBE mimc3 3 5 $WORK/mimc3
step $PROBE inv 0 $WORK/inverse-zero
step $PROBE inv 7 $WORK/inverse-seven
step $PROBE eq 7 7 $WORK/equal
step $PROBE eq 7 8 $WORK/unequal
step $PROBE select 0 8 3 $WORK/select-zero
step $PROBE select 1 8 3 $WORK/select-one
for circuit in mul mimc3 inverse-zero inverse-seven equal unequal select-zero select-one; do
  step snarkjs wtns check $WORK/$circuit.r1cs $WORK/$circuit.wtns
done
print -- "BACKEND-SNARKJS PASS 8 witnesses"
if [[ -n $PTAU ]]; then
  for circuit in mul mimc3; do
    step snarkjs plonk setup $WORK/$circuit.r1cs $PTAU $WORK/$circuit.zkey
    step snarkjs plonk prove $WORK/$circuit.zkey $WORK/$circuit.wtns \
      $WORK/$circuit.proof.json $WORK/$circuit.public.json
    step snarkjs zkey export verificationkey $WORK/$circuit.zkey $WORK/$circuit.vkey.json
    step snarkjs plonk verify $WORK/$circuit.vkey.json $WORK/$circuit.public.json $WORK/$circuit.proof.json
  done
  print -- "BACKEND-PLONK PASS mul mimc3"
else
  print -- "BACKEND-PLONK NOT-RUN no ptau argument"
fi
print -- "BACKEND-GATES-OK"
