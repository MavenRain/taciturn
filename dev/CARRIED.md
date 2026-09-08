# Carried files

The pin is kanon Stage K, `c4180626123687858ff83408bab801c6f87e3e71`,
as recorded in PIN and the vendor/kanon gitlink.  This replaces the interim
Stage H pin under D-A-1.  The carry includes bignum Nat, path-sensitive One
usage, and the dependencies of the Stage K positivity and totality guards.
Each header names its origin and delta.  dev/carry-check.sh re-diffs every
row, so any subsequent carry edit requires a matching count update.

The count is the line count of `diff` between
`git -C vendor/kanon show ORIGIN` and the file.  A file whose only delta
is the header line counts 4 when the pin already carries a header line of
its own, because the diff holds the range line, the old line, the marker
and the new line, and counts 2 when the pin has no header line, because
the diff holds the range line and the new line alone.

The local deltas retain witness W and the disclosed Extern kind.
lib/quantity.ml keeps the four marks and sixteen-arm tables.  The path
usage machinery is extracted from the same upstream module into
lib/linear.ml, with independent occurrence stamps and multiplicity counts.
W remains a private stamp and is duplicable; a One argument cannot enter
a W consumer.  This separation lets a witness-mode closure bind its own
linear argument without making that argument duplicable.

lib/check.ml keeps the witness occurrence rule, prove declassification,
normalized postulate linking and duplicate-global refusal.  The Stage K
checker threads usage through the rule packs.  lib/rules.ml keeps checked
lambda domains and annotation-aware binder marks, and directs extern
argument checking through a ledger hook without counting an argument twice.
Surface projections and pair eta share its dependent projection motives.
The inner first projection carries a motive under both self binders, so
the second projection's type is inferable and eta preserves that type.
The projection branch takes the binder name of the source pair, so a
refusal about a projection names a binder the reader can find in the
program.  lib/eval.ml reads the motive of a frozen elimination back under
a fresh self binder at the readback size, so the motive is scoped where
the readback lands and a stuck projection inside a pair fibre keeps its
type.
lib/conv.ml keeps actual-head domain checks during spine conversion.
lib/global.ml retains Extern and its signature checks.  lib/error.ml keeps
the four taciturn-specific errors alongside the Stage K termination error.

| file | origin | diff lines |
| --- | --- | --- |
| lib/bignum.ml | c418062:lib/bignum.ml | 2 |
| lib/budget.ml | c418062:lib/budget.ml | 4 |
| lib/budget.mli | c418062:lib/budget.mli | 4 |
| lib/check.ml | c418062:lib/check.ml | 413 |
| lib/conv.ml | c418062:lib/conv.ml | 43 |
| lib/error.ml | c418062:lib/error.ml | 49 |
| lib/eval.ml | c418062:lib/eval.ml | 30 |
| lib/global.ml | c418062:lib/global.ml | 78 |
| lib/level.ml | c418062:lib/level.ml | 4 |
| lib/level.mli | c418062:lib/level.mli | 4 |
| lib/linear.ml | c418062:lib/quantity.ml | 195 |
| lib/literal.ml | c418062:lib/literal.ml | 2 |
| lib/order.ml | c418062:lib/order.ml | 2 |
| lib/positivity.ml | c418062:lib/positivity.ml | 2 |
| lib/pp.ml | c418062:lib/pp.ml | 2 |
| lib/prim.ml | c418062:lib/prim.ml | 2 |
| lib/quantity.ml | c418062:lib/quantity.ml | 180 |
| lib/rules.ml | c418062:lib/rules.ml | 430 |
| lib/shape.ml | c418062:lib/shape.ml | 2 |
| lib/term.ml | c418062:lib/term.ml | 2 |
| lib/totality.ml | c418062:lib/totality.ml | 2 |
| lib/value.ml | c418062:lib/value.ml | 2 |

## The D-B-2 drops

The eight kernel files shape.ml, term.ml, rules.ml, check.ml, value.ml,
eval.ml, conv.ml and totality.ml retain their combined 3000-line cap.
The Stage B family-declaration omission remains: family_decl, ctor_decl,
check_telescope, index_rules, check_index_telescope, declare_family,
parameter_at, check_ctor and define_ctors.  The closed M0 surface cannot
declare families; M1 restores that path.  The Stage K re-carry compacts
comments to fit the same cap without dropping additional checking logic.

lib/order.ml carries the structural termination certificate algorithm.
It is outside that historical eight-file count, as are the carried bignum
boundary and the extracted linear-usage algebra.  Their line counts are
reported separately in the re-pin build log.  The M0 declaration checker
still does not admit recursive declarations.

lib/spec_count.ml, lib/disclosure.ml, lib/link.ml and lib/usage.ml are
taciturn-specific modules.  Surface files are carried as algorithms and
cite the upstream definitions beside each mirrored function.  Their Nat
changes preserve arbitrary-precision literals while explicitly narrowing
universe levels, collection widths and projection indices.
