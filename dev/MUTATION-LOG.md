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
