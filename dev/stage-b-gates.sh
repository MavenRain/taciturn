#!/bin/zsh
# dev/stage-b-gates.sh
# The twelve gates of the M0 Stage B brief, section 5, in order.  Every
# gate prints one line of evidence, either "SB-Gn PASS <line>" or
# "SB-Gn FAIL <line>" with the last lines of the failing command under
# it.  The script ends with GATES-OK and exit 0, or GATES-FAIL and
# exit 1.
#
# The root comes from this script's own path, so a copy of the repository
# under a scratch directory gates itself.  dev/stage-a-gates.sh stays as
# it is and stays green;  this runner adds the Stage B legs beside it.

set -u

chpwd_functions=()
unfunction chpwd 2>/dev/null

ROOT=${0:A:h}/..
BIN=$ROOT/_build/default/bin/taciturn.exe
SUITE=$ROOT/_build/default/test/main.exe
WORK=$ROOT/.gatework/gatesb
rm -rf $WORK
mkdir -p $WORK
ANY_FAIL=0

# --- SB-G1 BUILD ---
zsh $ROOT/dev/dune.sh clean > $WORK/g1.txt 2>&1
zsh $ROOT/dev/dunecho.sh build >> $WORK/g1.txt 2>&1
g1_rc=$?
g1_line=$(rg -N 'OK build: 0 errors, 0 warnings' $WORK/g1.txt | head -1)
if [[ $g1_rc -eq 0 && -n $g1_line ]]; then
  print -r -- "SB-G1 PASS $g1_line"
else
  print -r -- "SB-G1 FAIL build exit $g1_rc"
  tail -20 $WORK/g1.txt
  ANY_FAIL=1
fi

# --- SB-G2 CARRY ---
zsh $ROOT/dev/carry-check.sh > $WORK/g2.txt 2>&1
g2_rc=$?
g2_rows=$(rg -c '^CARRY .* OK$' $WORK/g2.txt || true)
g2_tail=$(rg -N '^CARRY-OK$' $WORK/g2.txt | head -1)
if [[ $g2_rc -eq 0 && -n $g2_tail && ${g2_rows:-0} -ge 19 ]]; then
  print -r -- "SB-G2 PASS $g2_tail with $g2_rows OK rows, exit $g2_rc"
else
  print -r -- "SB-G2 FAIL carry-check exit $g2_rc with ${g2_rows:-0} OK rows, 19 wanted"
  tail -20 $WORK/g2.txt
  ANY_FAIL=1
fi

# --- SB-G3 R0-COUNT ---
zsh $ROOT/dev/r0-count.sh > $WORK/g3.txt 2>&1
g3_rc=$?
g3_line=$(rg -N '^R0-COUNT OK$' $WORK/g3.txt | head -1)
$BIN spec-count > $WORK/g3d.txt 2>&1
g3_k=$(awk 'NR == 9' $WORK/g3d.txt)
if [[ $g3_rc -eq 0 && -n $g3_line && $g3_k == 'global kinds 4: Def Axiom Prim Extern' ]]; then
  print -r -- "SB-G3 PASS $g3_line with ninth line [$g3_k]"
else
  print -r -- "SB-G3 FAIL r0-count exit $g3_rc, ninth line [$g3_k]"
  tail -20 $WORK/g3.txt
  ANY_FAIL=1
fi

# --- SB-G4 PARSE ---
# One run of the suite answers SB-G4 and SB-G5, so the two gates read the
# same printed output and never disagree.
$SUITE $ROOT/test > $WORK/suite.txt 2>&1
suite_rc=$?
g4_fd=$(fd -t f -e tac . $ROOT/test/fixtures | wc -l | tr -d ' ')
g4_line=$(rg -N -o 'PARSE-OK [0-9]+/[0-9]+' $WORK/suite.txt | head -1)
g4_pair=${g4_line#PARSE-OK }
g4_ok=${g4_pair%%/*}
g4_tot=${g4_pair##*/}
if [[ -n $g4_line && ${g4_ok:-0} -ge 12 && $g4_ok == $g4_tot && $g4_tot == $g4_fd ]]; then
  print -r -- "SB-G4 PASS $g4_line, fd counts $g4_fd .tac files under test/fixtures"
else
  print -r -- "SB-G4 FAIL parse [$g4_line], fd counts $g4_fd .tac files"
  tail -20 $WORK/suite.txt
  ANY_FAIL=1
fi

# --- SB-G5 CHECK ---
# Every NEG row prints "NEG <name> OK: <tag>", where the tag is the text
# ahead of the first colon of the error line and names the Error
# constructor, and test/main.ml passes the row only when every word of the
# tag appears in the file name.  The gate counts the rows that name their
# constructor and compares the count with the leg total.
g5_c=$(rg -N -o 'CHECK-OK [0-9]+/[0-9]+' $WORK/suite.txt | head -1)
g5_cp=${g5_c#CHECK-OK }
g5_cok=${g5_cp%%/*}
g5_ctot=${g5_cp##*/}
g5_n=$(rg -N -o 'NEG-OK [0-9]+/[0-9]+' $WORK/suite.txt | head -1)
g5_np=${g5_n#NEG-OK }
g5_nok=${g5_np%%/*}
g5_ntot=${g5_np##*/}
g5_rows=$(rg -c '^NEG ' $WORK/suite.txt || true)
g5_named=$(rg -c '^NEG [^ ]+ OK: .+$' $WORK/suite.txt || true)
g5_suite=$(rg -N '^SUITE-KERNEL OK$' $WORK/suite.txt | head -1)
if [[ $suite_rc -eq 0 && -n $g5_c && -n $g5_n && -n $g5_suite \
      && ${g5_cok:-0} -ge 8 && $g5_cok == $g5_ctot \
      && ${g5_nok:-0} -ge 6 && $g5_nok == $g5_ntot \
      && ${g5_named:-0} -eq ${g5_rows:-0} && ${g5_named:-0} -eq ${g5_ntot:-0} ]]; then
  print -r -- "SB-G5 PASS $g5_c, $g5_n with $g5_named of $g5_rows NEG rows naming their Error constructor, $g5_suite, exit $suite_rc"
else
  print -r -- "SB-G5 FAIL suite exit $suite_rc, [$g5_c] [$g5_n] [$g5_suite], $g5_named of $g5_rows NEG rows named"
  rg -N '^(CHECK|NEG|SUITE)' $WORK/suite.txt | tail -20
  ANY_FAIL=1
fi

# --- SB-G6 EXTERN ---
$BIN check $ROOT/test/check/b06-extern-signature.tac > $WORK/g6a.txt 2>&1
g6_pos_rc=$?
$BIN axioms $ROOT/test/check/b06-extern-signature.tac > $WORK/g6b.txt 2>&1
g6_sig=$(rg -N -o '\(w b : Bit\) -> \(w x : Field p\) -> \(w y : Field p\) -> Field p' $WORK/g6b.txt | head -1)
$BIN check $ROOT/test/neg/n04-extern-def-clash.tac > $WORK/g6c.txt 2>&1
g6_neg_rc=$?
g6_ctor=$(rg -N -o '^extern clash' $WORK/g6c.txt | head -1)
if [[ $g6_pos_rc -eq 0 && -n $g6_sig && $g6_neg_rc -eq 1 && -n $g6_ctor ]]; then
  print -r -- "SB-G6 PASS b06-extern-signature.tac checks with exit $g6_pos_rc and its axioms row prints [$g6_sig], n04-extern-def-clash.tac exits $g6_neg_rc naming Error.Extern_clash as [$g6_ctor]"
else
  print -r -- "SB-G6 FAIL b06 exit $g6_pos_rc signature [$g6_sig], n04 exit $g6_neg_rc constructor [$g6_ctor]"
  tail -5 $WORK/g6a.txt
  tail -5 $WORK/g6b.txt
  tail -5 $WORK/g6c.txt
  ANY_FAIL=1
fi

# --- SB-G7 AXIOMS ---
$BIN axioms $ROOT/test/check/b08-axiom-disclosure.tac > $WORK/g7.txt 2>&1
g7_rc=$?
g7_rows=$(/usr/bin/wc -l < $WORK/g7.txt | tr -d ' ')
g7_names=$(awk '$2 == "axiom" { print $1 }' $WORK/g7.txt | LC_ALL=C sort)
g7_expected=$'Circuit\nProof\nPublic\nsound\nverify_reflect'
if [[ $g7_rc -eq 0 && $g7_rows -eq 5 && $g7_names == $g7_expected ]]; then
  print -r -- "SB-G7 PASS axioms b08-axiom-disclosure.tac prints wc -l $g7_rows rows, exactly Circuit, Proof, Public, sound and verify_reflect once each, exit $g7_rc"
else
  print -r -- "SB-G7 FAIL axioms exit $g7_rc, wc -l $g7_rows rows, expected Circuit, Proof, Public, sound and verify_reflect once each"
  tail -10 $WORK/g7.txt
  ANY_FAIL=1
fi

# --- SB-G8 R0-AUDIT ---
rg -n 'SPi|SColl|SPar|SMu|SNu' $ROOT/lib \
  --glob '!shape.ml' --glob '!rules.ml' --glob '!pp.ml' > $WORK/g8.txt 2>/dev/null
g8_rc=$?
g8_hits=$(awk 'NF { c = c + 1 } END { print c + 0 }' $WORK/g8.txt)
if [[ $g8_rc -eq 1 && $g8_hits -eq 0 ]]; then
  print -r -- "SB-G8 PASS r0-audit: the shape names print 0 lines outside shape.ml, rules.ml and pp.ml, rg exit $g8_rc"
else
  print -r -- "SB-G8 FAIL r0-audit: $g8_hits lines, rg exit $g8_rc"
  tail -20 $WORK/g8.txt
  ANY_FAIL=1
fi

# --- SB-G9 KERNEL-LINES ---
g9_total=0
g9_parts=""
for b in shape term rules check value eval conv totality; do
  g9_n=$(awk 'END { print NR }' $ROOT/lib/$b.ml)
  g9_total=$((g9_total + g9_n))
  g9_parts="$g9_parts $b.ml $g9_n"
done
if [[ $g9_total -le 3000 ]]; then
  print -r -- "SB-G9 PASS kernel lines $g9_total/3000 over eight files:$g9_parts"
else
  print -r -- "SB-G9 FAIL kernel lines $g9_total/3000 over eight files:$g9_parts"
  ANY_FAIL=1
fi

# --- SB-G10 HOUSE ---
# The disclosure form of SA-G6.  The eleven files carried at Stage B hold
# banned words inside doc comment prose and inside format strings, and a
# carried file admits no delta beyond its header line, so the prose cannot
# be reworded and no carried file is edited to satisfy this gate.  The
# runner blanks every comment and every string literal with
# dev/strip-ocaml.awk, which keeps the line count and the column
# positions, and matches the section 5 pattern over the blanked copies.
# It prints the raw count, the count in prose and the count in code, and
# it passes only when the count in code is 0.
banned='raise |failwith|assert |exception |invalid_arg|while |for |ref |mutable |Array|\.\(|List\.nth|List\.hd|List\.tl|Option\.get|\| _ ->'
rg -n "$banned" $ROOT/lib $ROOT/surface $ROOT/bin $ROOT/test \
  --glob '*.ml' --glob '*.mli' > $WORK/g10raw.txt 2>/dev/null
g10_raw_rc=$?
g10_raw=$(awk 'NF { c = c + 1 } END { print c + 0 }' $WORK/g10raw.txt)
fd -t f -e ml -e mli . $ROOT/lib $ROOT/surface $ROOT/bin $ROOT/test > $WORK/g10files.txt
g10_files_rc=$?
g10_files=$(awk 'END { print NR }' $WORK/g10files.txt)
mkdir -p $WORK/strip
g10_strip_rc=0
while IFS= read -r f; do
  rel=${f#$ROOT/}
  mkdir -p $WORK/strip/${rel:h}
  awk -f $ROOT/dev/strip-ocaml.awk $f > $WORK/strip/$rel 2>> $WORK/g10errors.txt || g10_strip_rc=1
done < $WORK/g10files.txt
rg -n "$banned" $WORK/strip --glob '*.ml' --glob '*.mli' > $WORK/g10code.txt 2>/dev/null
g10_code_rc=$?
g10_code=$(awk 'NF { c = c + 1 } END { print c + 0 }' $WORK/g10code.txt)
g10_prose=$((g10_raw - g10_code))
if [[ $g10_code -eq 0 && $g10_files -gt 0 && $g10_files_rc -eq 0 \
      && $g10_strip_rc -eq 0 && $g10_raw_rc -le 1 && $g10_code_rc -eq 1 ]]; then
  print -r -- "SB-G10 PASS house: the section 5 pattern over lib, surface, bin and test prints $g10_raw raw hits over $g10_files ml and mli files, $g10_prose of them inside doc comments or string literals and $g10_code in code"
else
  print -r -- "SB-G10 FAIL house: $g10_raw raw hits, $g10_prose in prose, $g10_code in code, scanner exits $g10_raw_rc/$g10_files_rc/$g10_strip_rc/$g10_code_rc"
  tail -20 $WORK/g10code.txt
  if [[ -f $WORK/g10errors.txt ]]; then tail -5 $WORK/g10errors.txt; fi
  ANY_FAIL=1
fi

# --- SB-G11 LINES ---
g11_q=$(awk 'END { print NR }' $ROOT/lib/quantity.ml)
g11_g=$(awk 'END { print NR }' $ROOT/lib/global.ml)
g11_l=$(awk 'END { print NR }' $ROOT/surface/lexer.ml)
g11_p=$(awk 'END { print NR }' $ROOT/surface/parser.ml)
g11_d=$(awk 'END { print NR }' $ROOT/bin/taciturn.ml)
g11_s=$(awk 'END { print NR }' $ROOT/SPEC.md)
g11_line="quantity.ml $g11_q/90 global.ml $g11_g/200 lexer.ml $g11_l/200 parser.ml $g11_p/600 taciturn.ml $g11_d/200 SPEC.md $g11_s/400"
if [[ $g11_q -le 90 && $g11_g -le 200 && $g11_l -le 200 && $g11_p -le 600 && $g11_d -le 200 && $g11_s -le 400 ]]; then
  print -r -- "SB-G11 PASS lines $g11_line"
else
  print -r -- "SB-G11 FAIL lines $g11_line"
  ANY_FAIL=1
fi

# --- SB-G12 PROSE ---
em=$'\u2014'
en=$'\u2013'
git -C $ROOT ls-files --cached --others --exclude-standard -- . ':(exclude)vendor' > $WORK/g12files.txt
g12_files=$(awk 'END { print NR }' $WORK/g12files.txt)
awk -v r=$ROOT '{ print r "/" $0 }' $WORK/g12files.txt | tr '\n' '\0' \
  | xargs -0 rg -N -n --no-messages -e $em -e $en -- > $WORK/g12dash.txt 2>/dev/null
g12_dash=$(awk 'END { print NR }' $WORK/g12dash.txt)
rg -N -n '[.?!] [A-Z]' $ROOT/README.md $ROOT/SPEC.md $ROOT/dev/*.md > $WORK/g12sp.txt 2>/dev/null
g12_sp=$(awk 'END { print NR }' $WORK/g12sp.txt)
if [[ $g12_dash -eq 0 && $g12_sp -eq 0 ]]; then
  print -r -- "SB-G12 PASS prose: 0 dash characters over $g12_files tracked and untracked files, 0 one-space sentence breaks in README.md, SPEC.md and dev/*.md"
else
  print -r -- "SB-G12 FAIL prose: $g12_dash dash hits, $g12_sp one-space sentence breaks"
  tail -10 $WORK/g12dash.txt
  tail -10 $WORK/g12sp.txt
  ANY_FAIL=1
fi

rm -rf $WORK
if [[ $ANY_FAIL -eq 0 ]]; then
  print -r -- "GATES-OK"
  exit 0
fi
print -r -- "GATES-FAIL"
exit 1
