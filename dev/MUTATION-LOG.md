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

## M0 Stage B

Six mutants, two of them, SB-M5 and SB-M6, added under D-B-6 after the Judge, one scratch copy per mutant under
/Users/oobi/Documents/taciturn-m0/scratch/stageB-restart, each copy made with
`rsync -a --exclude _build`, built through its own dev/dunecho.sh and gated
through its own test/main.exe or its own dev/carry-check.sh, because every
runner derives its root from its own path.  ROOT was never mutated and every
copy is left on disk.

| id | file | the edit | killed by | verdict |
| --- | --- | --- | --- | --- |
| SB-M1 | m1/lib/check.ml line 81, the SB-M1 site | the arm `(Quantity.One \| Quantity.Many), Quantity.W -> false` of `readable` to `-> true`, so a W marked binder reads at a One stamped point | `test/main.exe` printing `NEG n01-quantity-w-at-one-stamped FAIL: the file checks` then `NEG-FAIL 4/7` and `SUITE-KERNEL FAIL` with exit 1 | KILLED |
| SB-M2 | m2/lib/link.ml line 70, the SB-M2 site | the body of `point_mark` to `None`, so x_sig is not consulted at a call | `test/main.exe` printing `NEG n05-quantity-w-into-output FAIL: the file checks` then `NEG-FAIL 6/7` and `SUITE-KERNEL FAIL` with exit 1 | KILLED |
| SB-M3 | m3/lib/check.ml line 229, the SB-M3 site | the arm `() when String.equal n Link.declassifier -> Ok ()` of `declassify` to a name that never matches, so prove is an ordinary head | `test/main.exe` printing `CHECK b03-prove-declassifies FAIL: quantity: the extern prove takes a witness argument and is not the declassifier prove, so its result may not be read at a runtime mode` then `CHECK-FAIL 7/8` and `SUITE-KERNEL FAIL` with exit 1 | KILLED |
| SB-M4 | m4/lib/check.ml, one appended line | `(* SB-M4 mutant:  one appended line *)` appended, so the file is 377 lines | `dev/carry-check.sh` printing `CARRY lib/check.ml diff=283 expected=282 header=OK FAIL` then `CARRY-FAIL` with exit 1 | KILLED |
| SB-M5 | m5/lib/conv.ml, one appended line | `let _sb_m5_mutant = Array.length [\|\|]` appended as code, so a banned token of the section 5 pattern sits outside every row of dev/house-exclusions.tsv | `dev/stage-a-gates.sh` printing `SA-G6 FAIL house: 1 banned tokens outside the 41 disclosed lines, 0 stale rows, 42 raw hits, first: lib/conv.ml:418` then `GATES-FAIL` with exit 1 | KILLED |
| SB-M6 | m6/lib/error.ml line 7, one trailing space | one space appended to the disclosed line 7, so the text of its row no longer equals the line | `dev/stage-a-gates.sh` printing `SA-G6 FAIL house: 1 banned tokens outside the 41 disclosed lines, 1 stale rows, 41 raw hits, first: lib/error.ml:7` then `GATES-FAIL` with exit 1 | KILLED |

### SB-M1 evidence

The copy built clean, `OK build: 0 errors, 0 warnings`, so the kill comes from
the suite and not from the compiler.  With the twelfth pair of `readable`
turned, n01 no longer refuses:  `NEG n01-quantity-w-at-one-stamped FAIL: the
file checks`.  The other six negatives still refuse and `CHECK-OK 8/8` still
prints, so the mutant moves one line and one line alone.  The run printed
`NEG-FAIL 4/7` and `SUITE-KERNEL FAIL` and exited 1.

### SB-M2 evidence

The copy built clean, `OK build: 0 errors, 0 warnings`.  With `point_mark`
answering `None`, the mark of an argument position comes from the binder mark
the file wrote and no longer from the ledger, so the W argument that the
signature stamps at an output position is accepted:  `NEG
n05-quantity-w-into-output FAIL: the file checks`.  The run printed
`NEG-FAIL 6/7` and `SUITE-KERNEL FAIL` and exited 1.  n03, the arity negative,
still refuses, which shows that the arity check and the per argument mark are
two claims and that this mutant moves only the second one.

### SB-M3 evidence

The copy built clean, `OK build: 0 errors, 0 warnings`.  With the one named
case gone, prove is an ordinary head that takes a witness argument, so its own
positive fixture stops checking and the refusal quotes the rule:  `CHECK
b03-prove-declassifies FAIL: quantity: the extern prove takes a witness
argument and is not the declassifier prove, so its result may not be read at a
runtime mode`.  The run printed `CHECK-FAIL 7/8`, `NEG-OK 7/7` and
`SUITE-KERNEL FAIL` and exited 1.

### SB-M4 evidence

The copy holds one appended comment line in lib/check.ml, so `wc -l` prints
377 where ROOT prints 376.  The copy's own dev/carry-check.sh recomputed the
row against the pin and printed `CARRY lib/check.ml diff=283 expected=282
header=OK FAIL` and then `CARRY-FAIL`, and it exited 1.  The header check
still passed, which shows that the row size and the header line are two
separate claims of the carry gate and that the drift was caught by the count.

### SB-M5 evidence

SB-M5 and SB-M6 are the two mutants of the D-B-6 fix, beyond the four of the
brief section 6, and they aim at the SA-G6 exclusion table
dev/house-exclusions.tsv and not at the kernel.  The copy holds one appended
line of code in lib/conv.ml, `let _sb_m5_mutant = Array.length [||]`, which is
neither a comment nor a string, so the pattern prints 42 raw hits where ROOT
prints 41 and the added one is disclosed by no row:  `SA-G6 FAIL house: 1
banned tokens outside the 41 disclosed lines, 0 stale rows, 42 raw hits, first:
lib/conv.ml:418`, and the copy's own dev/stage-a-gates.sh ended `GATES-FAIL`
with exit 1.  SA-G2 also failed with `CARRY-FAIL`, because lib/conv.ml is a
carried file and the appended line is a delta, which shows that the two gates
read the same edit through two separate claims.

### SB-M6 evidence

The copy holds one trailing space on lib/error.ml line 7, a line the table
discloses.  The line still matches the pattern, so the raw count stays 41, but
the text of the row no longer equals the line, so the row is stale and the hit
is no longer disclosed:  `SA-G6 FAIL house: 1 banned tokens outside the 41
disclosed lines, 1 stale rows, 41 raw hits, first: lib/error.ml:7`, and the
copy's own dev/stage-a-gates.sh ended `GATES-FAIL` with exit 1.  This is the
pin of the ruling:  a table row cannot outlive the prose it names.  ROOT ran
its own dev/stage-a-gates.sh after both mutants and printed GATES-OK, so
neither copy touched it.

## Stage 0 reader hardening, 2026-09-06

`dev/reader-tests.mjs` constructs a valid multiplication artifact independently
of the OCaml writer, then changes one binary property per negative case.
All 47 checks pass with the fixed reader.  The baseline at 259de6d passes
20/47, including three valid controls and seventeen existing rejection checks.

| Mutation family | Baseline evidence | Fixed result |
| --- | --- | --- |
| Private witness plus p | READER OK, exit 0 | wtns-field-range |
| Constraint coefficient plus p | READER OK, exit 0 | r1cs-c0-A-field-range |
| Interface count exceeds wire count | READER OK, exit 0 | r1cs-interface-count |
| Label outside label count or duplicate label | READER OK, exit 0 | label-range or label-duplicate |
| Extra bytes inside either header | READER OK, exit 0 | header-size |
| Duplicate section in either container | READER OK, exit 0 | section-duplicate |
| Trailing bytes in either container | READER OK, exit 0 | trailing-bytes |
| Magic byte with the high bit set | READER OK, exit 0 | r1cs-magic |
| Header declares no public output | READER OK, exit 0 | r1cs-pub-out |
| Truncation, huge section size, invalid wire or LC count | Rejected incidentally | Explicit bounds rejection |

The thirteen false acceptances above all exit 1 after the fix.  The other
fourteen baseline failures reflect diagnostic improvements, not additional
false acceptances.  Valid controls include reordered sections and an unknown
but correctly framed extension section.  Existing negatives cover altered
witnesses, the constant wire, zero coefficients, and unsorted or duplicate
wire ids.  S0-G5 requires the complete suite to pass.

A scratch runner deletes each of 17 rejection lines of the reader in turn and
runs the suite against the copy.  All 17 mutants are killed, the raw magic
compare and the public output rule included.
