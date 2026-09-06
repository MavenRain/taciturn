#!/bin/zsh
# dev/differential.sh
# Compares the row-IR emission (rows.exe mimc3, 12 constraints per brief
# section 4) against circom's own r1cs constraint count for mimc3.circom at
# optimization levels O0, O1 and O2.  O0 and O1 keep the linear constraints
# our L1 fold removes, so the pass/fail ratio is taken against O2, circom's
# full linear simplification and the level at which it emits production
# rows; O0 and O1 counts are printed as information only (RATIFICATIONS.md
# D-S0-1).
#
# SA-D7: the root comes from this script's own path, never from a literal,
# so a copy of the repository under a scratch directory gates itself.

set -u

chpwd_functions=()
unfunction chpwd 2>/dev/null

ROOT=${0:A:h}/..

if ! command -v circom >/dev/null 2>&1 || ! command -v snarkjs >/dev/null 2>&1; then
  print -r -- "DIFF PENDING circom or snarkjs not installed"
  exit 3
fi

OUT=$ROOT/spike/out
mkdir -p $OUT/diff-O0 $OUT/diff-O1 $OUT/diff-O2 || exit 3

circom $ROOT/spike/circom/mimc3.circom --r1cs --O0 -o $OUT/diff-O0 >$OUT/diff-O0.log 2>&1
if [ $? -ne 0 ]; then
  print -r -- "DIFF FAIL step=circom-O0"
  tail -n 5 $OUT/diff-O0.log
  exit 1
fi

circom $ROOT/spike/circom/mimc3.circom --r1cs --O1 -o $OUT/diff-O1 >$OUT/diff-O1.log 2>&1
if [ $? -ne 0 ]; then
  print -r -- "DIFF FAIL step=circom-O1"
  tail -n 5 $OUT/diff-O1.log
  exit 1
fi

circom $ROOT/spike/circom/mimc3.circom --r1cs --O2 -o $OUT/diff-O2 >$OUT/diff-O2.log 2>&1
if [ $? -ne 0 ]; then
  print -r -- "DIFF FAIL step=circom-O2"
  tail -n 5 $OUT/diff-O2.log
  exit 1
fi

info0=$(snarkjs r1cs info $OUT/diff-O0/mimc3.r1cs 2>&1)
if [ $? -ne 0 ]; then
  print -r -- "DIFF FAIL step=r1cs-info-O0"
  print -r -- "$info0" | tail -n 5
  exit 1
fi

info1=$(snarkjs r1cs info $OUT/diff-O1/mimc3.r1cs 2>&1)
if [ $? -ne 0 ]; then
  print -r -- "DIFF FAIL step=r1cs-info-O1"
  print -r -- "$info1" | tail -n 5
  exit 1
fi

info2=$(snarkjs r1cs info $OUT/diff-O2/mimc3.r1cs 2>&1)
if [ $? -ne 0 ]; then
  print -r -- "DIFF FAIL step=r1cs-info-O2"
  print -r -- "$info2" | tail -n 5
  exit 1
fi

n0=$(print -r -- "$info0" | sd '\x1b\[[0-9;]*m' '' | rg -o '# of Constraints: [0-9]+' | rg -o '[0-9]+$')
n1=$(print -r -- "$info1" | sd '\x1b\[[0-9;]*m' '' | rg -o '# of Constraints: [0-9]+' | rg -o '[0-9]+$')
n2=$(print -r -- "$info2" | sd '\x1b\[[0-9;]*m' '' | rg -o '# of Constraints: [0-9]+' | rg -o '[0-9]+$')

if [ -z "${n0:-}" ] || [ -z "${n1:-}" ] || [ -z "${n2:-}" ]; then
  print -r -- "DIFF FAIL step=parse-r1cs-info"
  exit 1
fi

if [ ! -x $ROOT/_build/default/spike/rows/rows.exe ]; then
  print -r -- "DIFF FAIL step=rows.exe-missing"
  exit 1
fi

rows_out=$($ROOT/_build/default/spike/rows/rows.exe mimc3 3 5 $OUT/diff-rows 2>&1)
if [ $? -ne 0 ]; then
  print -r -- "DIFF FAIL step=rows.exe"
  print -r -- "$rows_out" | tail -n 5
  exit 1
fi

ours=$(print -r -- "$rows_out" | rg -o 'constraints=[0-9]+' | rg -o '[0-9]+')
if [ -z "${ours:-}" ]; then
  print -r -- "DIFF FAIL step=parse-rows-out"
  exit 1
fi

ratio2=$(print -r -- $(( 1.0 * n2 / ours )))

print -r -- "DIFF ours=$ours circom_O0=$n0 circom_O1=$n1 circom_O2=$n2 ratio_O2=$ratio2"

if (( ratio2 >= 0.8 && ratio2 <= 1.25 )); then
  print -r -- "PASS"
  exit 0
else
  print -r -- "FAIL"
  exit 1
fi
