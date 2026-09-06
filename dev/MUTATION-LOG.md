# taciturn M0 mutation log

## 2026-09-06 Stage 0

Every mutant ran on its own `rsync -a --exclude _build --exclude .git` copy of
the repository under the judge scratch directory.
/Users/oobi/Documents/taciturn was never mutated.  Each copy gates itself,
because every runner derives its root from its own path.

| id | file | the edit | killed by | verdict |
| --- | --- | --- | --- | --- |
| S0-M1 | spike/rows/main.ml line 11 | `let round_constants = [ 1; 2; 3 ]` to `let round_constants = [ 1; 3; 3 ]`, the round constant c_1 from 2 to 3 | `READER FAIL reason=circuit-mismatch`, exit 1 | KILLED |
| S0-M2 | spike/rows/lower.ml line 26 | `Int.compare w1 w2` to `Int.compare w2 w1`, so every linear combination is emitted in descending wire order | `READER FAIL reason=r1cs-c0-A-sort`, exit 1, on the mimc3 vehicle;  the mutated tree's own `dev/spike-gates.sh` prints `S0-G4 FAIL` and `GATES-FAIL` | KILLED |
| S0-M3 | spike/gclink/gclink.mjs line 57 | the symbolic `pre.inv` gains `preRows += 1;` and `rows += 1;`, so the row-free namespace appends a row | `symbolic run(6) = 2n rows = 3 pre_calls = 1 pre_rows = 1` and exit 1 | KILLED |

### S0-M1 evidence

The mutated copy builds clean (`OK build: 0 errors, 0 warnings`) and prints
`ROWS mimc3 constraints=12 wires=15 pub_out=1 pub_in=1 priv=1 out=8321316981933125412446494722391563915347636565562452458934987360037605058661`,
a different h from the section 2 vector.  The reader carries its own copy of
the round constants, recomputes h from x and k, and prints
`READER FAIL reason=circuit-mismatch` with exit 1.  The reader is therefore
not reading the builder's constants.

### S0-M2 evidence

The mutated copy builds clean.  On the vehicle the brief names,
`rows.exe mul 6 7`, the reader still prints
`READER OK constraints=1 wires=4 out=42` and exits 0, so the mutant escapes
that vehicle.  The cause is in the artifact, not in the reader: the judge
parsed mul.r1cs from its bytes and the single constraint has term counts
A=1, B=1, C=1, so no linear combination in the mul circuit holds two terms
and no wire order is observable.  On the mimc3 vehicle of the same mutated
tree, whose 12 constraints hold combinations of up to 3 terms, the reader
prints `READER FAIL reason=r1cs-c0-A-sort` and exits 1, and the mutated
tree's own `zsh dev/spike-gates.sh` prints
`S0-G4 FAIL reader: READER FAIL reason=r1cs-c0-A-sort | READER FAIL reason=r1cs-c0-A-sort`
followed by `GATES-FAIL`.  The mutant is killed by the Stage 0 suite, and
finding J1 of the build log records that the brief's mul vehicle is too weak
to carry this mutant on its own.

### S0-M3 evidence

The unmutated gclink.mjs prints
`symbolic run(6) = 1n rows = 2 pre_calls = 1 pre_rows = 0` and exits 0.  The
mutated copy prints `symbolic run(6) = 2n rows = 3 pre_calls = 1 pre_rows = 1`
and exits 1, because the shape check at gclink.mjs line 95 pins
`rows = 2 pre_calls = 1 pre_rows = 0`.  The pre_rows figure is no longer 0,
which is the kill condition of the brief section 6.  The R-Q2 claim that
pre.* is row free is therefore load bearing and tested.

## M0 Stage A

Every mutant ran on its own `rsync -a --exclude _build` copy of the
repository under the judge scratch directory
`/private/tmp/claude-501/-Users-oobi-Documents-claude13/151e76ab-903f-4528-ab32-69095cab22c6/scratchpad/stageA/mN`.
/Users/oobi/Documents/taciturn was never mutated and nothing was deleted
there.  Each copy carries vendor/kanon and gates itself, because every
runner derives its root from its own path.

| id | file | the edit | killed by | verdict |
| --- | --- | --- | --- | --- |
| SA-M1 | lib/quantity.ml line 36 | the mul arm `W, One -> W` to `W, One -> One` | the MARK line of the SA-G4 parse test, `test/main.exe` at test/main.ml:89, printing `MARK a11-w-times-one 1` where the unmutated tree prints `MARK a11-w-times-one w` | KILLED |
| SA-M2 | lib/level.ml, one appended line | `(* SA-M2 mutation: one appended line *)` appended | SA-G2, `dev/carry-check.sh` printing `CARRY lib/level.ml diff=6 expected=4 header=OK FAIL` then `CARRY-FAIL` with exit 1, and the copy's own gate runner printing `SA-G2 FAIL carry-check exit 1` then `GATES-FAIL` with exit 1 | KILLED |
| SA-M3 | surface/lexer.ml line 128 | ` ("w", KWMark);` removed from the keyword table, so the lexer reads `w` as a name | SA-G4, `test/main.exe` printing `PARSE a11-w-times-one FAIL: line 4, column 71: expected a binder name and ':', found identifier w` then `PARSE-FAIL 9/12` with exit 1, and the copy's own gate runner printing `SA-G4 FAIL parse exit 1, fd counts 12 .tac files` then `GATES-FAIL` with exit 1 | KILLED |

### SA-M1 evidence

The print path is the one the Builder reported: `test/main.ml:89` prints
`MARK NAME QUANTITY` for every fixture, where the quantity is the fold of
every binder mark of the file under `Quantity.mul` from the unit `One`.
The a11-w-times-one.tac fixture declares
`zk def commit : (w s : Field p) -> (1 r : Field p) -> Field p := fun (w s : Field p) (1 r : Field p) => add s r`,
so its marks are W, One, W, One and its product is `w` in the unmutated
tree.  The mutated copy builds clean, `SA-G1 PASS OK build: 0 errors, 0
warnings`, and its own gate runner still prints `GATES-OK`, because
`PARSE-OK 12/12` does not read a quantity.  The kill is the printed
quantity the brief section 6 names: the mutated copy prints
`MARK a11-w-times-one 1` and the unmutated tree prints
`MARK a11-w-times-one w`.  The mul table therefore has a printed reader,
and the gate table alone would not have caught this arm.

### SA-M2 evidence

`zsh SCRATCH/m2/dev/carry-check.sh` printed the FAIL row above with exit 1,
the other seven rows staying OK, then `CARRY-FAIL`.  The copy's own
`dev/stage-a-gates.sh` printed `SA-G2 FAIL carry-check exit 1` and
`GATES-FAIL` and exited 1.  A silent edit to a carried file is caught.

### SA-M3 evidence

With ` ("w", KWMark);` gone from the keyword table, `ident_kind` returns
`Ident "w"` and the three fixtures that hold a `w` binder fail: a10-marks-all
at line 4 column 91, a11-w-times-one at line 4 column 71 and a12-zk-def at
line 3 column 52, each printing
`FAIL: ... expected a binder name and ':', found identifier w`.  The run
printed `PARSE-FAIL 9/12` and exited 1, and the copy's gate runner printed
`SA-G4 FAIL parse exit 1, fd counts 12 .tac files` then `GATES-FAIL`.  The
copy still built clean, `SA-G1 PASS OK build: 0 errors, 0 warnings`, so the
kill comes from the parse test and not from the compiler.
