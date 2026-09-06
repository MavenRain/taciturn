#!/bin/zsh
# Regression cases where prose delimiters used to hide following code.
set -eu
ROOT=${0:A:h}/..
WORK=$(mktemp -d "${TMPDIR:-/tmp}/taciturn-strip.XXXXXXXX")
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/valid.ml" <<'ML'
(* "*)" *) let comment_string = assert false
let quoted_string = {| " |} let after_quoted = assert false
let tagged = {tag| " *) (* |tag} let after_tagged = assert false
let extension = {%foo tag| " |tag} let after_extension = assert false
(* {| *) |} *) let comment_quoted = assert false
(* (* nested *) "*)" *) let nested = assert false
(* '"' *) let comment_character = assert false
let character = '"' let after_character = assert false
let prose = "assert false (* \" *)"
let continued = "assert false \
still prose" let after_continuation = assert false
let param (x : 'a) = x let identifier' = assert false
ML

awk -f "$ROOT/dev/strip-ocaml.awk" "$WORK/valid.ml" > "$WORK/stripped.ml"
hits=$(rg -c 'assert false' "$WORK/stripped.ml")
[[ $hits -eq 10 ]]
awk 'NR == FNR { sizes[FNR] = length($0); rows = FNR; next }
     length($0) != sizes[FNR] { bad = 1 }
     END { exit (bad || FNR != rows) }' "$WORK/valid.ml" "$WORK/stripped.ml"

for source in '(* unfinished' 'let text = "unfinished' 'let text = {| unfinished'; do
  print -r -- "$source" > "$WORK/invalid.ml"
  if awk -f "$ROOT/dev/strip-ocaml.awk" "$WORK/invalid.ml" > "$WORK/output" 2> "$WORK/error"; then
    print -r -- "STRIP-FAIL unfinished input succeeded"
    exit 1
  fi
done
print -r -- "STRIP-OK comment strings, quoted strings, character literals and unfinished input"
