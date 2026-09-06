#!/bin/zsh
# dev/roundtrip.sh
# Full snarkjs PLONK round trip over the two Stage 0 circuits (x*y=z and
# MiMC-3) plus a shared bn128 powers-of-tau ceremony.  PENDING at Stage 0:
# snarkjs is not installed and this session never installs it (brief
# section 2).  Command spellings are taken verbatim from
# taciturn-dossier-toolchain.md section 3, never from memory.
#
# SA-D7: the root comes from this script's own path, never from a literal,
# so a copy of the repository under a scratch directory gates itself.

set -u

chpwd_functions=()
unfunction chpwd 2>/dev/null

ROOT=${0:A:h}/..

if ! command -v snarkjs >/dev/null 2>&1; then
  print -r -- "ROUNDTRIP PENDING snarkjs not installed"
  exit 3
fi

OUT=$ROOT/spike/out
mkdir -p $OUT || exit 3

fail() {
  print -r -- "ROUNDTRIP FAIL step=$1"
  print -r -- "$2" | tail -n 5
  exit 1
}

step_new=$(snarkjs powersoftau new bn128 8 $OUT/pot8_0000.ptau -v 2>&1)
[ $? -eq 0 ] || fail "powersoftau-new" "$step_new"

step_contribute=$(snarkjs powersoftau contribute $OUT/pot8_0000.ptau $OUT/pot8_0001.ptau --name="stage0" -e="taciturn-stage-0" -v 2>&1)
[ $? -eq 0 ] || fail "powersoftau-contribute" "$step_contribute"

step_prepare=$(snarkjs powersoftau prepare phase2 $OUT/pot8_0001.ptau $OUT/pot8_final.ptau -v 2>&1)
[ $? -eq 0 ] || fail "powersoftau-prepare-phase2" "$step_prepare"

if [ ! -x $ROOT/_build/default/spike/rows/rows.exe ]; then
  fail "rows.exe-missing" "rows.exe not built"
fi

# mul: x=6, y=7, z=42 (section 5 S0-G3 vector)
step_mul_rows=$($ROOT/_build/default/spike/rows/rows.exe mul 6 7 $OUT/mul 2>&1)
[ $? -eq 0 ] || fail "rows-mul" "$step_mul_rows"

# mimc3: x=3, k=5 (section 2 first test vector)
step_mimc3_rows=$($ROOT/_build/default/spike/rows/rows.exe mimc3 3 5 $OUT/mimc3 2>&1)
[ $? -eq 0 ] || fail "rows-mimc3" "$step_mimc3_rows"

for circuit in mul mimc3; do
  step_info=$(snarkjs r1cs info $OUT/$circuit.r1cs 2>&1)
  [ $? -eq 0 ] || fail "r1cs-info-$circuit" "$step_info"

  step_wcheck=$(snarkjs wtns check $OUT/$circuit.r1cs $OUT/$circuit.wtns 2>&1)
  [ $? -eq 0 ] || fail "wtns-check-$circuit" "$step_wcheck"

  step_setup=$(snarkjs plonk setup $OUT/$circuit.r1cs $OUT/pot8_final.ptau $OUT/${circuit}_final.zkey 2>&1)
  [ $? -eq 0 ] || fail "plonk-setup-$circuit" "$step_setup"

  step_prove=$(snarkjs plonk prove $OUT/${circuit}_final.zkey $OUT/$circuit.wtns $OUT/${circuit}_proof.json $OUT/${circuit}_public.json 2>&1)
  [ $? -eq 0 ] || fail "plonk-prove-$circuit" "$step_prove"

  step_vkey=$(snarkjs zkey export verificationkey $OUT/${circuit}_final.zkey $OUT/${circuit}_verification_key.json 2>&1)
  [ $? -eq 0 ] || fail "zkey-export-verificationkey-$circuit" "$step_vkey"

  step_verify=$(snarkjs plonk verify $OUT/${circuit}_verification_key.json $OUT/${circuit}_public.json $OUT/${circuit}_proof.json 2>&1)
  [ $? -eq 0 ] || fail "plonk-verify-$circuit" "$step_verify"
done

print -r -- "ROUNDTRIP PASS mul mimc3"
exit 0
