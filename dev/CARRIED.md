# Carried files

Every file below comes from the kanon clone under vendor/kanon at the pin
de40d65, which PIN names.  The pin is interim under D-A-1:  kanon Stage K
moves the kernel that these files sit in, so Stage K forces the re-carry
of section 1 of the M0 plan at the new sha, and every row here is
recomputed then.  The first line of each carried file states the delta and
dev/carry-check.sh re-diffs the file against the pin, so a silent edit to
a carried file fails the CARRY gate.

The count is the line count of `diff` between
`git -C vendor/kanon show ORIGIN` and the file.  A file whose only delta
is the header line counts 4 when the pin already carries a header line of
its own, because the diff holds the range line, the old line, the marker
and the new line, and counts 2 when the pin has no header line, because
the diff holds the range line and the new line alone.

Six files carry a delta beyond the header.  lib/quantity.ml holds the
fourth mark W of section 4 of M0-PLAN.md, its five mul arms, its six equal
arms, its to_string arm and the prose that states the table.
lib/global.ml holds the Extern kind of Stage B, its entry record with the
per-argument quantity signature, and the arity and mark checks that link a foreign
implementation against the disclosure ledger.  lib/error.ml holds the two
extern arms of Stage B brief 3.3 and the two arms of brief 3.5, Usage for
the sum of SPEC.md section 3.2 and Extern_clash for a definition that
carries a ledger name.  lib/check.ml holds the occurrence rule of the
brief section 4 at one site, the extern point walk, the declassifier, the
call into the usage sum and the D-B-2 drop below.  The review adds duplicate
global rejection, normalized postulate linking and domain-directed extern
argument checking.  lib/rules.ml validates lambda domains and reads binder
marks through annotations.  lib/conv.ml reads application argument types
from the actual head during conversion.

| file | origin | diff lines |
| --- | --- | --- |
| lib/budget.ml | de40d65:lib/budget.ml | 4 |
| lib/check.ml | de40d65:lib/check.ml | 325 |
| lib/conv.ml | de40d65:lib/conv.ml | 14 |
| lib/error.ml | de40d65:lib/error.ml | 32 |
| lib/eval.ml | de40d65:lib/eval.ml | 2 |
| lib/global.ml | de40d65:lib/global.ml | 78 |
| lib/level.ml | de40d65:lib/level.ml | 4 |
| lib/literal.ml | de40d65:lib/literal.ml | 4 |
| lib/positivity.ml | de40d65:lib/positivity.ml | 2 |
| lib/pp.ml | de40d65:lib/pp.ml | 2 |
| lib/prim.ml | de40d65:lib/prim.ml | 2 |
| lib/quantity.ml | de40d65:lib/quantity.ml | 66 |
| lib/rules.ml | de40d65:lib/rules.ml | 53 |
| lib/shape.ml | de40d65:lib/shape.ml | 2 |
| lib/term.ml | de40d65:lib/term.ml | 2 |
| lib/totality.ml | de40d65:lib/totality.ml | 2 |
| lib/value.ml | de40d65:lib/value.ml | 2 |
| lib/budget.mli | de40d65:lib/budget.mli | 4 |
| lib/level.mli | de40d65:lib/level.mli | 4 |

## The D-B-2 drops

D-B-2 caps the eight kernel files shape.ml, term.ml, rules.ml, check.ml,
value.ml, eval.ml, conv.ml and totality.ml at 3000 lines.  The initial carry
lands at 2995, and the review lands at 2987 by compacting comments without
dropping kernel logic.  lib/check.ml drops the
inductive family declaration of the pin, 190 lines in two type
declarations and seven definitions:  family_decl, ctor_decl,
check_telescope, index_rules, check_index_telescope, declare_family,
parameter_at, check_ctor and define_ctors.  The 190 measures the family
declaration block removed by Stage B.  Review changes additionally condense
the introductory comments in check.ml and several comments in rules.ml.
No further kernel definitions are removed.  The dropped block declares families and their
constructors, which the closed grammar of SPEC.md section 2 does not
reach at M0, so no surface form of Stage B needs it;  M1 carries it back
at the Stage K pin when the family syntax lands, and the count above is
the size of the re-carry.

lib/spec_count.ml, lib/disclosure.ml, lib/link.ml and lib/usage.ml are not
carried:  they are taciturn's own files and they hold no carry header, so
carry-check.sh wants no row for them.

surface/lexer.ml, surface/parser.ml and surface/elab.ml are carried as
algorithm, not byte for byte, so they hold no carry header and no row.
Each mirrored function cites its kanon line above the definition.
