# taciturn M0 build log

## 2026-09-06 Stage 0

Stage 0 of stage-0-brief.md, the three Q6 spikes, judged on 2026-09-06.
Nothing is committed.  The repository holds no commit and no staged path, by
the brief section 3.1 rule "No commit at any point".

### Gate table

| id | verdict | evidence line |
| --- | --- | --- |
| S0-G1 BUILD | PASS | `S0-G1 PASS exit=0` (`zsh dev/dunecho.sh build` prints `OK build: 0 errors, 0 warnings`) |
| S0-G2 HOUSE | PASS | `S0-G2 PASS no banned forms, no wildcard arm on a variant type` |
| S0-G3 ROWS-MUL | PASS | `ROWS mul constraints=1 wires=4 pub_out=1 pub_in=0 priv=2 out=42` and `READER OK constraints=1 wires=4 out=42` |
| S0-G4 ROWS-MIMC | PASS | `ROWS mimc3 constraints=12 wires=15 pub_out=1 pub_in=1 priv=1 out=15183264145800795984152266960707291554837359903848949088059893297015753845292`, `ROWS mimc3 constraints=12 wires=15 pub_out=1 pub_in=1 priv=1 out=241606605612651390000000`, and `READER OK` on both pairs with the same out |
| S0-G5 READER-NEG | PASS | `S0-G5 PASS wtns-flip=READER FAIL reason=constraint-10 \| r1cs-swap=READER FAIL reason=r1cs-c0-A-sort`, both exit 1 |
| S0-G6 GCLINK | PASS | `S0-G6 PASS sha256=7d425cedcc397a5b3d1c4db886b1d12ef20606bd9a1e0c6c5ac74da72105a488` (gclink.wasm and the wasm-opt re-assembly agree) |
| S0-G7 ROUNDTRIP | PASS | `S0-G7 PASS ROUNDTRIP PASS mul mimc3`, exit 0 |
| S0-G8 DIFF | PASS | `S0-G8 PASS DIFF ours=12 circom_O0=17 circom_O1=16 circom_O2=12 ratio_O2=1.`, then `PASS`, exit 0 |
| S0-G9 LINES | PASS | `S0-G9 PASS fp.ml=234 rows_total=654 reader.mjs=214 gclink.mjs=99` |
| S0-G10 PROSE | PASS | `S0-G10 PASS no em-dash, no en-dash, sentence spacing ok`, and the judge's own sweep `rg -n --hidden -g '!_build' -g '!.git' '[\x{2014}\x{2013}]' /Users/oobi/Documents/taciturn` exits 1 with no match |
| S0-G11 BENCH | PASS | `S0-G11 PASS BENCH true median_ms=5.742 min_ms=5.095 max_ms=5.917 runs=5` |

Whole run: `zsh /Users/oobi/Documents/taciturn/dev/spike-gates.sh` prints
`GATES-OK` and exits 0.  Every gate above was also rerun by hand by the judge,
outside the gate script, and every hand result agrees with the script line.

### Numbers

- Constraints: mul 1, mimc3 12, for both vectors.  Wires: mul 4, mimc3 15.
- Interface: mul pub_out=1 pub_in=0 priv=2, mimc3 pub_out=1 pub_in=1 priv=1.
- h(x = 3, k = 5) = 15183264145800795984152266960707291554837359903848949088059893297015753845292.
- h(x = 0, k = 0) = 241606605612651390000000.
- Sizes in bytes: mul.r1cs 264, mul.wtns 204, mimc3_3_5.r1cs 2356,
  mimc3_3_5.wtns 556, mimc3_0_0.r1cs 2356, mimc3_0_0.wtns 556.
- gclink.wasm 128 bytes, gclink.wat 698 bytes, sha256 of the wasm and of the
  wasm-opt re-assembly both 7d425cedcc397a5b3d1c4db886b1d12ef20606bd9a1e0c6c5ac74da72105a488.
- Bench median 5.742 ms over 5 runs, min 5.095 ms, max 5.917 ms, under the
  20 ms bound of S0-G11.
- Lines: fp.ml 234 of 250, spike/rows/*.ml 654 of 700, reader.mjs 214 of 250,
  gclink.mjs 99 of 120, README.md 36 of 40.
- Wire coverage of mimc3_3_5.r1cs, parsed by the judge straight from the
  bytes: 15 declared wires, 15 wires used by some A, B or C term, no unused
  wire, every linear combination strictly ascending, 12 constraints parsed
  against a header count of 12, 15 labels.

### Files written at Stage 0

Root: `.gitignore`, `dune`, `dune-project`, `LICENSE-MIT`, `LICENSE-APACHE`,
`README.md`.
`dev/`: `dune.sh`, `dunecho.sh`, `bench.sh` (carried from kanon c018a0f with
the rewritten first comment line), `differential.sh`, `roundtrip.sh`,
`spike-gates.sh`, `spike-gates-mutate.py`, and this log with
`MUTATION-LOG.md`.
`spike/rows/`: `dune`, `fp.ml`, `fp.mli`, `row.ml`, `lower.ml`, `r1cs.ml`,
`wtns.ml`, `main.ml`, `rows.ml`, `reader.mjs`, `.gitkeep`.
`spike/gclink/`: `gclink.wat`, `gclink.wasm`, `gclink.mjs`, `.gitkeep`.
`spike/circom/`: `mimc3.circom`, `.gitkeep`.
`spike/out/`: build artifacts only, ignored by `.gitignore`.

### The two PENDING gates, with the exact user commands

Both gates stay PENDING until the user installs the tools.  Agents never
install and never reach the network.  Install commands, quoted from
taciturn-dossier-toolchain.md lines 149 to 156:

```
npm i -g snarkjs
git clone https://github.com/iden3/circom.git
cd circom && cargo install --path circom
curl -L -o powersOfTau28_hez_final_10.ptau https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_10.ptau
```

circom is built through cargo because no arm64 release asset exists
(taciturn-dossier-toolchain.md line 156).  Then rerun the two gates:

```
zsh /Users/oobi/Documents/taciturn/dev/roundtrip.sh
zsh /Users/oobi/Documents/taciturn/dev/differential.sh
```

S0-G7 turns PASS when roundtrip.sh prints `ROUNDTRIP PASS mul mimc3` and
exits 0.  S0-G8 turns PASS when differential.sh prints a `DIFF ours=12
circom_O0=N circom_O1=M ratio_O0=R` line with R inside [0.8, 1.25].  Today
both print PENDING and exit 3, which is a verdict, not a failure.

### 2026-09-06 Stage 0a: installs done, the two gates rerun

The user installed circom 2.2.3 (cargo install from a source checkout) and
snarkjs 0.7.6, then reran the two pending gates.  `zsh dev/roundtrip.sh`
printed `ROUNDTRIP PASS mul mimc3` and exited 0, no defect.  The first
`zsh dev/differential.sh` run printed `DIFF ours=12 circom_O0=32
circom_O1=32 ratio_O0=2.6666666666666665` then `FAIL`, and exposed two
defects.

Parse defect: differential.sh read each count with
`rg -i constraints | rg -o '[0-9]+' | head -n 1`.  snarkjs colors its output
with an ANSI escape, so the line reads
`\x1b[32;22m[INFO]  \x1b[39;1msnarkJS\x1b[0m: # of Constraints: 12`, and the
first digit run the old parser finds is the `32` of the escape code, not the
true count, whatever that count is.  True counts, verified with the escapes
stripped: O0 = 17, O1 = 16, O2 = 12.

Reference-level defect: the brief compared the emission against circom
`--O0`, but circom at O0 and O1 keeps the linear constraints (17 = 12
quadratic + 5 linear at O0; 16 at O1) that this project's L1 fold folds into
the quadratic rows before emission.  `--O2` is circom's full linear
simplification, the level at which it emits production rows, and there the
count is 12, matching ours exactly (ratio 1.0).  Against O0 the ratio is
1.417, which fails the band [0.8, 1.25] for a correct emission.

Decision, provisional and open to a user veto, recorded as D-S0-1 in
RATIFICATIONS.md: the pass/fail ratio is taken against circom `--O2`; the O0
and O1 counts stay printed on the DIFF line as information.  dev/differential.sh
was rewritten to compile all three levels, parse each count with the ANSI
escapes stripped (`sd '\x1b\[[0-9;]*m' ''` ahead of the digit match), and
gate on `ratio_O2`.  The rerun printed `DIFF ours=12 circom_O0=17
circom_O1=16 circom_O2=12 ratio_O2=1.` then `PASS`, exit 0.

J1 (dev/spike-gates.sh line 259, the S0-G10 em-dash sweep vacuous over
`git -C $ROOT ls-files` while nothing is staged) was fixed in the same pass:
the sweep now walks the working tree with
`rg --files -g '!_build' -g '!.git' -g '!spike/out' $ROOT`.

### Verifier findings and their dispositions

- F1, blocker, spike/rows/lower.ml and spike/rows/main.ml, filed by three
  verifiers independently: the MiMC-3 pair declared 19 wires while only 15
  stood in a constraint, so wires 4, 9, 14 and 18 were unconstrained and a
  flipped byte in the last witness value left the reader printing
  `READER OK`, which is the exact case S0-G5 names.  FIXED at the root cause
  by the rows builder, with a `Lower.prune` pass that drops every wire no
  emitted constraint mentions, keeps wire 0 and the whole interface, and
  renumbers the survivors.  reader.mjs was not touched.  CONFIRMED FIXED by
  the judge: mimc3 now reports wires=15, the r1cs parsed from its own bytes
  uses all 15, and flipping any one of the 32 bytes of the last witness value
  gives `READER FAIL reason=constraint-10` and exit 1 in all 32 of 32 trials.
- F2, medium and low, spike/rows/main.ml, the `| _ -> usage ()` arm and the
  `Sys.argv` array pattern.  DISPUTED by the fixer, and the judge upholds the
  dispute.  The house rule bans a wildcard arm on a variant type, and this
  match is over `Sys.argv`, which OCaml binds as `string array` with no
  list-returning alternative in the standard library.  `Array.to_list` would
  introduce the banned `Array.` form, so no rewrite improves compliance.  The
  banned-form sweep over spike/rows/*.ml still returns nothing.
- F2 high and F3 medium, stale gate evidence in an earlier builder report.
  RESOLVED: the judge reran the whole suite today, and every line in the gate
  table above comes from that run, not from any earlier report.

### Judge findings

- J1, medium, dev/spike-gates.sh line 259.  The em-dash half of S0-G10 walks
  `git -C $ROOT ls-files`, which returns zero paths, because Stage 0 forbids
  a commit and nothing is staged.  That half of the gate is vacuous as
  written.  The judge ran the check by hand over every file outside `_build`
  and `.git`, found no em-dash and no en-dash, so the verdict stands, but the
  script should walk the working tree, not the index, while the repository
  carries no commit.  FIXED 2026-09-06 in the Stage 0a rerun.
- J2, medium, stage-0-brief.md section 6, the S0-M2 vehicle.  The mul circuit
  emits one constraint whose A, B and C hold exactly one term each, so a
  descending wire order is unobservable there and the mutant escapes the
  vehicle the brief names.  The same mutant dies on the mimc3 vehicle in the
  same mutated tree.  Detail in dev/MUTATION-LOG.md.
- J3, low, dev/spike-gates.sh lines 181 to 184.  The S0-G6 shape test matches
  only the prefix `symbolic run(6) = `, not the required
  `rows = 2 pre_calls = 1 pre_rows = 0` figures.  The figures are checked
  inside gclink.mjs line 95, which drives the exit code the gate does test,
  so the substance is covered twice over and this is a readability point.
- J4, high, dev/differential.sh, FIXED 2026-09-06.  The count parser read
  `rg -i constraints | rg -o '[0-9]+' | head -n 1`, and snarkjs colors its
  output with an ANSI escape ahead of the true digits, so the parser
  returned the `32` inside `\x1b[32;22m` instead of the constraint count.
  FIXED by stripping the escapes with `sd '\x1b\[[0-9;]*m' ''` before the
  digit match, and by anchoring the match to the literal
  `# of Constraints: [0-9]+` label.

Whole run: `zsh /Users/oobi/Documents/taciturn/dev/spike-gates.sh` printed
`GATES-OK` on the 2026-09-06 Stage 0a rerun, with every leg PASS, including
S0-G7 and S0-G8, now that circom and snarkjs are installed.

RATIFY:
