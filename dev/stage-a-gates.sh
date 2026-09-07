#!/bin/zsh
# dev/stage-a-gates.sh
# The eight gates of the M0 Stage A brief, section 5, in order.  Every
# gate prints one line of evidence, either "SA-Gn PASS <line>" or
# "SA-Gn FAIL <line>" with the last lines of the failing command under
# it.  The script ends with GATES-OK and exit 0, or GATES-FAIL and
# exit 1.
#
# The root comes from this script's own path, so a copy of the repository
# under a scratch directory gates itself.

set -u

chpwd_functions=()
unfunction chpwd 2>/dev/null

ROOT=${0:A:h}/..
WORK=$ROOT/.gatework/gates
rm -rf $WORK
mkdir -p $WORK
ANY_FAIL=0

# --- SA-G1 BUILD ---
zsh $ROOT/dev/dune.sh clean > $WORK/g1.txt 2>&1
zsh $ROOT/dev/dunecho.sh build >> $WORK/g1.txt 2>&1
g1_rc=$?
g1_line=$(rg -N 'OK build: 0 errors, 0 warnings' $WORK/g1.txt | head -1)
if [[ $g1_rc -eq 0 && -n $g1_line ]]; then
  print -r -- "SA-G1 PASS $g1_line"
else
  print -r -- "SA-G1 FAIL build exit $g1_rc"
  tail -20 $WORK/g1.txt
  ANY_FAIL=1
fi

# --- SA-G2 CARRY ---
zsh $ROOT/dev/carry-check.sh > $WORK/g2.txt 2>&1
g2_rc=$?
g2_rows=$(rg -c '^CARRY .* OK$' $WORK/g2.txt || true)
g2_tail=$(rg -N '^CARRY-OK$' $WORK/g2.txt | head -1)
if [[ $g2_rc -eq 0 && -n $g2_tail && ${g2_rows:-0} -ge 1 ]]; then
  print -r -- "SA-G2 PASS $g2_tail with $g2_rows OK rows, exit $g2_rc"
else
  print -r -- "SA-G2 FAIL carry-check exit $g2_rc"
  tail -20 $WORK/g2.txt
  ANY_FAIL=1
fi

# --- SA-G3 R0-COUNT ---
zsh $ROOT/dev/r0-count.sh > $WORK/g3.txt 2>&1
g3_rc=$?
g3_line=$(rg -N '^R0-COUNT OK$' $WORK/g3.txt | head -1)
$ROOT/_build/default/bin/taciturn.exe spec-count > $WORK/g3d.txt 2>&1
g3_a=$(rg -N '^formers 2: ' $WORK/g3d.txt | head -1)
g3_b=$(rg -N '^schema constructors 4: ' $WORK/g3d.txt | head -1)
g3_c=$(rg -N '^shapes declared 5: ' $WORK/g3d.txt | head -1)
if [[ $g3_rc -eq 0 && -n $g3_line && -n $g3_a && -n $g3_b && -n $g3_c ]]; then
  print -r -- "SA-G3 PASS $g3_line with [$g3_a] [$g3_b] [$g3_c]"
else
  print -r -- "SA-G3 FAIL r0-count exit $g3_rc"
  tail -20 $WORK/g3.txt
  ANY_FAIL=1
fi

# --- SA-G4 PARSE ---
g4_fd=$(fd -t f -e tac . $ROOT/test/fixtures | wc -l | tr -d ' ')
$ROOT/_build/default/test/main.exe $ROOT/test/fixtures > $WORK/g4.txt 2>&1
g4_rc=$?
g4_line=$(rg -N -o 'PARSE-OK [0-9]+/[0-9]+' $WORK/g4.txt | head -1)
g4_pair=${g4_line#PARSE-OK }
g4_ok=${g4_pair%%/*}
g4_tot=${g4_pair##*/}
if [[ $g4_rc -eq 0 && -n $g4_line && ${g4_ok:-0} -ge 10 && $g4_ok == $g4_tot && $g4_tot == $g4_fd ]]; then
  print -r -- "SA-G4 PASS $g4_line, fd counts $g4_fd .tac files, exit $g4_rc"
else
  print -r -- "SA-G4 FAIL parse exit $g4_rc, fd counts $g4_fd .tac files"
  tail -20 $WORK/g4.txt
  ANY_FAIL=1
fi

# --- SA-G5 PIN ---
g5_pin=$(cat $ROOT/PIN)
g5_lines=$(awk 'END { print NR }' $ROOT/PIN)
g5_sha=$(git -C $ROOT/vendor/kanon rev-parse HEAD 2>&1)
g5_gm=$(awk 'END { print NR }' $ROOT/.gitmodules)
g5_h=$(rg -c -e '^\[submodule "vendor/kanon"\]$' -e '^\tpath = vendor/kanon$' -e '^\turl = /Users/oobi/Documents/kanon$' $ROOT/.gitmodules || true)
if [[ $g5_pin == c4180626123687858ff83408bab801c6f87e3e71 && $g5_lines -eq 1 && $g5_sha == $g5_pin && $g5_gm -eq 3 && ${g5_h:-0} -eq 3 ]]; then
  print -r -- "SA-G5 PASS PIN $g5_pin on 1 line, vendor/kanon HEAD $g5_sha, .gitmodules 3 of 3 lines matched"
else
  print -r -- "SA-G5 FAIL PIN [$g5_pin] lines $g5_lines, vendor HEAD [$g5_sha], .gitmodules $g5_gm lines, ${g5_h:-0} of 3 matched"
  ANY_FAIL=1
fi

# --- SA-G6 HOUSE ---
# The gate is the literal command of section 5 of the brief:  the section 5
# pattern over ROOT/lib, ROOT/surface, ROOT/bin and ROOT/test with the two
# globs.  Every line the pattern prints is disclosed by the table
# dev/house-exclusions.tsv, one row per line, three tab separated fields
# path, line and text, in the form kanon's dev/house.sh uses for its SD-D18
# buffer site.  A raw hit is disclosed when a row names its path and its
# line and the text of the row equals the current line byte for byte, so an
# edit to a disclosed line drops the exclusion and the hit is reported.  A
# row whose text no longer equals its line is stale and fails the gate, so
# the table cannot outlive the prose it names.  Every disclosed line is doc
# comment prose, a plain comment or a string literal, and a carried file
# admits no delta beyond its header line, so this prose cannot be reworded
# without breaking the CARRY gate (ruling D-B-6).  Every other line of every
# file, comment or code, is scanned as the brief writes it.  The gate passes
# only when no raw hit sits outside the table, no row is stale and the table
# holds at least one row.
banned='raise |failwith|assert |exception |invalid_arg|while |for |ref |mutable |Array|\.\(|List\.nth|List\.hd|List\.tl|Option\.get|\| _ ->'
rg -n "$banned" $ROOT/lib $ROOT/surface $ROOT/bin $ROOT/test \
  --glob '*.ml' --glob '*.mli' > $WORK/g6raw.txt 2>/dev/null
g6_raw=$(awk 'NF { c = c + 1 } END { print c + 0 }' $WORK/g6raw.txt)
g6_files=$(fd -t f -e ml -e mli . $ROOT/lib $ROOT/surface $ROOT/bin $ROOT/test | awk 'END { print NR }')
awk -v r="$ROOT/" '
BEGIN { FS = "\t"; rows = 0; out = 0; stale = 0 }
FNR == NR {
  if (FNR == 1) { next }
  if (NF == 0) { next }
  rows = rows + 1
  k = $1 SUBSEP $2
  paths[$1] = 1
  if (NF == 3) { txt[k] = $3; has[k] = 1 } else { bad[k] = 1 }
  next
}
NF == 0 { next }
{
  p = index($0, ":"); f = substr($0, 1, p - 1); rest = substr($0, p + 1)
  q = index(rest, ":"); ln = substr(rest, 1, q - 1); line = substr(rest, q + 1)
  rel = f
  if (substr(rel, 1, length(r)) == r) { rel = substr(rel, length(r) + 1) }
  k = rel SUBSEP ln
  if (k in has && txt[k] == line) { next }
  out = out + 1
  print "OUTSIDE\t" rel ":" ln
}
END {
  for (p in paths) {
    n = 0
    file = r p
    while ((getline cur < file) > 0) {
      n = n + 1
      k = p SUBSEP n
      if (k in has && txt[k] == cur) { good[k] = 1 }
    }
    close(file)
  }
  for (k in has) { if (!(k in good)) { stale = stale + 1; split(k, a, SUBSEP); print "STALE\t" a[1] ":" a[2] } }
  for (k in bad) { stale = stale + 1; split(k, a, SUBSEP); print "STALE\t" a[1] ":" a[2] }
  print "SUM\t" out "\t" stale "\t" rows
}' $ROOT/dev/house-exclusions.tsv $WORK/g6raw.txt > $WORK/g6.txt
g6_out=$(awk -F'\t' '$1 == "SUM" { print $2 + 0 }' $WORK/g6.txt)
g6_stale=$(awk -F'\t' '$1 == "SUM" { print $3 + 0 }' $WORK/g6.txt)
g6_rows=$(awk -F'\t' '$1 == "SUM" { print $4 + 0 }' $WORK/g6.txt)
g6_first=$(awk -F'\t' '$1 == "OUTSIDE" || $1 == "STALE" { print $2; exit }' $WORK/g6.txt)
if [[ ${g6_out:-1} -eq 0 && ${g6_stale:-1} -eq 0 && ${g6_rows:-0} -ge 1 ]]; then
  print -r -- "SA-G6 PASS house: the section 5 pattern over lib, surface, bin and test prints $g6_raw raw hits over $g6_files ml and mli files, all $g6_raw disclosed by dev/house-exclusions.tsv ($g6_rows rows, exact text), 0 outside, 0 stale rows"
else
  print -r -- "SA-G6 FAIL house: ${g6_out:-0} banned tokens outside the ${g6_rows:-0} disclosed lines, ${g6_stale:-0} stale rows, $g6_raw raw hits, first: $g6_first"
  rg -N -e '^OUTSIDE' -e '^STALE' $WORK/g6.txt | tail -20
  ANY_FAIL=1
fi

# --- SA-G7 LINES ---
g7_q=$(awk 'END { print NR }' $ROOT/lib/quantity.ml)
g7_l=$(awk 'END { print NR }' $ROOT/surface/lexer.ml)
g7_p=$(awk 'END { print NR }' $ROOT/surface/parser.ml)
g7_d=$(awk 'END { print NR }' $ROOT/bin/taciturn.ml)
g7_s=$(awk 'END { print NR }' $ROOT/SPEC.md)
g7_line="quantity.ml $g7_q/90 lexer.ml $g7_l/200 parser.ml $g7_p/600 taciturn.ml $g7_d/150 SPEC.md $g7_s/400"
if [[ $g7_q -le 90 && $g7_l -le 200 && $g7_p -le 600 && $g7_d -le 150 && $g7_s -le 400 ]]; then
  print -r -- "SA-G7 PASS lines $g7_line"
else
  print -r -- "SA-G7 FAIL lines $g7_line"
  ANY_FAIL=1
fi

# --- SA-G8 PROSE ---
em=$'\u2014'
en=$'\u2013'
git -C $ROOT ls-files --cached --others --exclude-standard -- . ':(exclude)vendor' > $WORK/g8files.txt
g8_files=$(awk 'END { print NR }' $WORK/g8files.txt)
awk -v r=$ROOT '{ print r "/" $0 }' $WORK/g8files.txt | tr '\n' '\0' \
  | xargs -0 rg -N -n --no-messages -e $em -e $en -- > $WORK/g8dash.txt 2>/dev/null
g8_dash=$(awk 'END { print NR }' $WORK/g8dash.txt)
rg -N -n '[.?!] [A-Z]' $ROOT/README.md $ROOT/SPEC.md $ROOT/dev/*.md > $WORK/g8sp.txt 2>/dev/null
g8_sp=$(awk 'END { print NR }' $WORK/g8sp.txt)
if [[ $g8_dash -eq 0 && $g8_sp -eq 0 ]]; then
  print -r -- "SA-G8 PASS prose: 0 dash characters over $g8_files tracked and untracked files, 0 one-space sentence breaks in README.md, SPEC.md and dev/*.md"
else
  print -r -- "SA-G8 FAIL prose: $g8_dash dash hits, $g8_sp one-space sentence breaks"
  tail -10 $WORK/g8dash.txt
  tail -10 $WORK/g8sp.txt
  ANY_FAIL=1
fi

rm -rf $WORK
if [[ $ANY_FAIL -eq 0 ]]; then
  print -r -- "GATES-OK"
  exit 0
fi
print -r -- "GATES-FAIL"
exit 1
