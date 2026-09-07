#!/bin/zsh
# dev/spike-gates.sh
# Runs every gate of stage-0-brief.md section 5, in order, one line per gate:
# "S0-Gn PASS ...", "S0-Gn FAIL ..." or "S0-Gn PENDING ...".  A missing
# artifact from a builder that has not finished prints FAIL for that gate and
# the run continues; PENDING never fails the run.  Prints GATES-OK and exits
# 0 when no gate is FAIL, else GATES-FAIL and exits 1.
#
# SA-D7: the root comes from this script's own path, never from a literal,
# so a copy of the repository under a scratch directory gates itself.

set -u

chpwd_functions=()
unfunction chpwd 2>/dev/null

ROOT=${0:A:h}/..
OUT=$ROOT/spike/out
ROWS=$ROOT/_build/default/spike/rows/rows.exe
READER=$ROOT/spike/rows/reader.mjs
GCLINK=$ROOT/spike/gclink/gclink.mjs

mkdir -p $OUT || exit 3

typeset -i ANY_FAIL=0

# --- S0-G1 BUILD ---
g1_out=$({ zsh $ROOT/dev/dunecho.sh build && zsh $ROOT/dev/dunecho.sh test; } 2>&1)
g1_status=$?
if [ $g1_status -eq 0 ]; then
  print -r -- "S0-G1 PASS exit=0"
else
  print -r -- "S0-G1 FAIL exit=$g1_status"
  print -r -- "$g1_out" | tail -n 5
  ANY_FAIL=1
fi

# --- S0-G2 HOUSE ---
ml_files=($ROOT/spike/rows/*.ml(N))
if [ ${#ml_files[@]} -eq 0 ]; then
  print -r -- "S0-G2 FAIL no .ml files found under spike/rows/"
  ANY_FAIL=1
else
  banned='\braise\b|\bfailwith\b|\bassert\b|\binvalid_arg\b|\bwhile\b|\bfor\b|\bref\b|\bmutable\b|\bArray\.|\.\(|List\.nth|List\.hd|List\.tl|Option\.get'
  hits=$(rg -n "$banned" $ml_files 2>&1)
  wild_hits=$(rg -n '^\s*\|\s*_\s*->' $ml_files 2>&1)
  # SA-D8: the house rule bans a wildcard arm on a variant type, not on an
  # array pattern (Sys.argv dispatch is `[| ... |]`, never a sum type).  For
  # each wildcard-arm hit, walk up from the hit line to the nearest
  # enclosing "match" line and check that block for an array-literal
  # pattern; if found, the match is over an array, not a variant, and the
  # wildcard arm is exempt.
  wild=""
  if [ -n "$wild_hits" ]; then
    while IFS= read -r hit; do
      [ -z "$hit" ] && continue
      hfile=${hit%%:*}
      rest=${hit#*:}
      hline=${rest%%:*}
      lines=("${(@f)$(<$hfile)}")
      s=$hline
      while [ $s -gt 1 ] && [[ "${lines[$s]}" != *'match '* ]]; do
        s=$((s - 1))
      done
      is_array_match=0
      for ((i = s; i <= hline; i++)); do
        [[ "${lines[$i]}" == *'[|'* ]] && is_array_match=1
      done
      if [ $is_array_match -eq 0 ]; then
        wild="$wild
$hit"
      fi
    done <<< "$wild_hits"
  fi
  if [ -n "$hits" ] || [ -n "$wild" ]; then
    print -r -- "S0-G2 FAIL banned form or wildcard arm on a variant type present"
    print -r -- "$hits
$wild" | tail -n 5
    ANY_FAIL=1
  else
    print -r -- "S0-G2 PASS no banned forms, no wildcard arm on a variant type"
  fi
fi

# --- S0-G3 ROWS-MUL ---
if [ ! -x $ROWS ]; then
  print -r -- "S0-G3 FAIL rows.exe missing"
  ANY_FAIL=1
else
  mul_out=$($ROWS mul 6 7 $OUT/mul 2>&1)
  mul_status=$?
  if [ $mul_status -eq 0 ] && [[ "$mul_out" == *"constraints=1"* ]] && [[ "$mul_out" == *"out=42"* ]] \
     && [ -f $OUT/mul.r1cs ] && [ -f $OUT/mul.wtns ]; then
    if [ -f $READER ]; then
      r_out=$(node $READER $OUT/mul.r1cs $OUT/mul.wtns mul 6 7 2>&1)
      if [[ "$r_out" == "READER OK"* ]]; then
        print -r -- "S0-G3 PASS $mul_out | $r_out"
      else
        print -r -- "S0-G3 FAIL reader: $r_out"
        ANY_FAIL=1
      fi
    else
      print -r -- "S0-G3 FAIL reader.mjs missing"
      ANY_FAIL=1
    fi
  else
    print -r -- "S0-G3 FAIL exit=$mul_status $mul_out"
    ANY_FAIL=1
  fi
fi

# --- S0-G4 ROWS-MIMC ---
h1="15183264145800795984152266960707291554837359903848949088059893297015753845292"
h2="241606605612651390000000"
if [ ! -x $ROWS ]; then
  print -r -- "S0-G4 FAIL rows.exe missing"
  ANY_FAIL=1
else
  m1_out=$($ROWS mimc3 3 5 $OUT/mimc3_3_5 2>&1)
  m1_status=$?
  m2_out=$($ROWS mimc3 0 0 $OUT/mimc3_0_0 2>&1)
  m2_status=$?
  ok=1
  if [ $m1_status -ne 0 ] || [[ "$m1_out" != *"constraints=12"* ]] || [[ "$m1_out" != *"out=$h1"* ]]; then
    ok=0
  fi
  if [ $m2_status -ne 0 ] || [[ "$m2_out" != *"constraints=12"* ]] || [[ "$m2_out" != *"out=$h2"* ]]; then
    ok=0
  fi
  if [ $ok -eq 1 ] && [ -f $READER ]; then
    r1=$(node $READER $OUT/mimc3_3_5.r1cs $OUT/mimc3_3_5.wtns mimc3 3 5 2>&1)
    r2=$(node $READER $OUT/mimc3_0_0.r1cs $OUT/mimc3_0_0.wtns mimc3 0 0 2>&1)
    if [[ "$r1" == "READER OK"* ]] && [[ "$r2" == "READER OK"* ]]; then
      print -r -- "S0-G4 PASS $m1_out | $m2_out | $r1 | $r2"
    else
      print -r -- "S0-G4 FAIL reader: $r1 | $r2"
      ANY_FAIL=1
    fi
  elif [ $ok -eq 1 ]; then
    print -r -- "S0-G4 FAIL reader.mjs missing"
    ANY_FAIL=1
  else
    print -r -- "S0-G4 FAIL m1_status=$m1_status m2_status=$m2_status $m1_out | $m2_out"
    ANY_FAIL=1
  fi
fi

# --- S0-G5 READER-NEG ---
reader_tests=$(node $ROOT/dev/reader-tests.mjs 2>&1)
reader_tests_status=$?
if [ ! -f $READER ] || [ ! -f $OUT/mimc3_3_5.r1cs ] || [ ! -f $OUT/mimc3_3_5.wtns ]; then
  print -r -- "S0-G5 FAIL missing reader.mjs or mimc3_3_5 pair (needs S0-G4 artifacts) tests=${reader_tests##*$'\n'}"
  ANY_FAIL=1
else
  mut_note=$(/opt/homebrew/bin/python3 -P $ROOT/dev/spike-gates-mutate.py "$OUT/mimc3_3_5.r1cs" "$OUT/mimc3_3_5.wtns" "$OUT/mimc3_3_5.mut.r1cs" "$OUT/mimc3_3_5.mut.wtns" 2>&1)
  mut_status=$?
  if [ $mut_status -ne 0 ]; then
    print -r -- "S0-G5 FAIL mutate helper: $mut_note"
    ANY_FAIL=1
  else
    neg_wtns=$(node $READER $OUT/mimc3_3_5.r1cs $OUT/mimc3_3_5.mut.wtns mimc3 3 5 2>&1)
    neg_wtns_status=$?
    neg_r1cs=$(node $READER $OUT/mimc3_3_5.mut.r1cs $OUT/mimc3_3_5.wtns mimc3 3 5 2>&1)
    neg_r1cs_status=$?
    if [ $neg_wtns_status -eq 1 ] && [[ "$neg_wtns" == "READER FAIL"* ]] \
       && [ $neg_r1cs_status -eq 1 ] && [[ "$neg_r1cs" == "READER FAIL"* ]] \
       && [ $reader_tests_status -eq 0 ] && [[ "$reader_tests" == "READER-TESTS OK "* ]]; then
      print -r -- "S0-G5 PASS wtns-flip=$neg_wtns | r1cs-swap=$neg_r1cs | $reader_tests"
    else
      print -r -- "S0-G5 FAIL wtns=$neg_wtns (exit=$neg_wtns_status) r1cs=$neg_r1cs (exit=$neg_r1cs_status) tests=${reader_tests##*$'\n'}"
      print -r -- "$reader_tests"
      ANY_FAIL=1
    fi
  fi
fi

# --- S0-G6 GCLINK ---
if [ ! -f $GCLINK ]; then
  print -r -- "S0-G6 FAIL gclink.mjs missing"
  ANY_FAIL=1
else
  g6_out=$(node $GCLINK 2>&1)
  g6_status=$?
  shape_ok=1
  [[ "$g6_out" == *"imports:"* ]] || shape_ok=0
  [[ "$g6_out" == *"native run(6) = 1n"* ]] || shape_ok=0
  [[ "$g6_out" == *"symbolic run(6) = "* ]] || shape_ok=0
  [[ "$g6_out" == *"missing-pre LinkError = true"* ]] || shape_ok=0
  if [ $g6_status -eq 0 ] && [ $shape_ok -eq 1 ]; then
    if [ -f $ROOT/spike/gclink/gclink.wat ] && [ -f $ROOT/spike/gclink/gclink.wasm ]; then
      /opt/homebrew/bin/wasm-opt -all $ROOT/spike/gclink/gclink.wat -o $OUT/gclink-reassembled.wasm 2>$OUT/gclink-reassemble.log
      if [ $? -eq 0 ]; then
        sum1=$(shasum -a 256 $ROOT/spike/gclink/gclink.wasm | awk '{print $1}')
        sum2=$(shasum -a 256 $OUT/gclink-reassembled.wasm | awk '{print $1}')
        if [ "$sum1" = "$sum2" ]; then
          print -r -- "S0-G6 PASS sha256=$sum1"
        else
          print -r -- "S0-G6 FAIL reassembly mismatch sha256 $sum1 != $sum2"
          ANY_FAIL=1
        fi
      else
        print -r -- "S0-G6 FAIL wasm-opt reassembly error"
        tail -n 5 $OUT/gclink-reassemble.log
        ANY_FAIL=1
      fi
    else
      print -r -- "S0-G6 FAIL gclink.wat or gclink.wasm missing"
      ANY_FAIL=1
    fi
  else
    print -r -- "S0-G6 FAIL exit=$g6_status $g6_out"
    ANY_FAIL=1
  fi
fi

# --- S0-G7 ROUNDTRIP ---
g7_out=$(zsh $ROOT/dev/roundtrip.sh 2>&1)
g7_status=$?
if [ $g7_status -eq 3 ] && [[ "$g7_out" == "ROUNDTRIP PENDING"* ]]; then
  print -r -- "S0-G7 PENDING $g7_out"
elif [ $g7_status -eq 0 ] && [[ "$g7_out" == "ROUNDTRIP PASS"* ]]; then
  print -r -- "S0-G7 PASS $g7_out"
else
  print -r -- "S0-G7 FAIL exit=$g7_status $g7_out"
  ANY_FAIL=1
fi

# --- S0-G8 DIFF ---
g8_out=$(zsh $ROOT/dev/differential.sh 2>&1)
g8_status=$?
if [ $g8_status -eq 3 ] && [[ "$g8_out" == "DIFF PENDING"* ]]; then
  print -r -- "S0-G8 PENDING $g8_out"
elif [ $g8_status -eq 0 ]; then
  print -r -- "S0-G8 PASS $g8_out"
else
  print -r -- "S0-G8 FAIL exit=$g8_status $g8_out"
  ANY_FAIL=1
fi

# --- S0-G9 LINES ---
fp_lines=0
[ -f $ROOT/spike/rows/fp.ml ] && fp_lines=$(wc -l < $ROOT/spike/rows/fp.ml | tr -d ' ')
rows_ml_total=0
if [ ${#ml_files[@]} -gt 0 ]; then
  rows_ml_total=$(wc -l $ml_files | tail -n 1 | awk '{print $1}')
fi
reader_lines=0
[ -f $READER ] && reader_lines=$(wc -l < $READER | tr -d ' ')
gclink_lines=0
[ -f $GCLINK ] && gclink_lines=$(wc -l < $GCLINK | tr -d ' ')
print -r -- "S0-G9-WC fp.ml=$fp_lines rows_total=$rows_ml_total reader.mjs=$reader_lines gclink.mjs=$gclink_lines"
if [ -f $ROOT/spike/rows/fp.ml ] && [ $fp_lines -le 250 ] \
   && [ ${#ml_files[@]} -gt 0 ] && [ $rows_ml_total -le 700 ] \
   && [ -f $READER ] && [ $reader_lines -le 250 ] \
   && [ -f $GCLINK ] && [ $gclink_lines -le 120 ]; then
  print -r -- "S0-G9 PASS fp.ml=$fp_lines rows_total=$rows_ml_total reader.mjs=$reader_lines gclink.mjs=$gclink_lines"
else
  print -r -- "S0-G9 FAIL over budget or missing file (see S0-G9-WC line)"
  ANY_FAIL=1
fi

# --- S0-G10 PROSE ---
tracked=$(rg --files -g '!_build' -g '!.git' -g '!spike/out' $ROOT)
dash_hits=$(print -r -- "$tracked" | while read -r f; do rg -n '[\x{2014}\x{2013}]' "$f" 2>/dev/null; done)
md_files=($ROOT/README.md(N) $ROOT/dev/*.md(N))
spacing_hits=$(rg -n '[.?!] [A-Z]' $md_files 2>/dev/null)
if [ -z "$dash_hits" ] && [ -z "$spacing_hits" ]; then
  print -r -- "S0-G10 PASS no em-dash, no en-dash, sentence spacing ok"
else
  print -r -- "S0-G10 FAIL"
  print -r -- "$dash_hits
$spacing_hits" | tail -n 5
  ANY_FAIL=1
fi

# --- S0-G11 BENCH ---
g11_out=$(zsh $ROOT/dev/bench.sh true /usr/bin/true 2>&1)
g11_status=$?
median=$(print -r -- "$g11_out" | rg -o 'median_ms=[0-9.]+' | rg -o '[0-9.]+')
if [ $g11_status -eq 0 ] && [ -n "${median:-}" ] && (( median < 20.0 )); then
  print -r -- "S0-G11 PASS $g11_out"
else
  print -r -- "S0-G11 FAIL exit=$g11_status $g11_out"
  ANY_FAIL=1
fi

if [ $ANY_FAIL -eq 0 ]; then
  print -r -- "GATES-OK"
  exit 0
else
  print -r -- "GATES-FAIL"
  exit 1
fi
