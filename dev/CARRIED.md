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

lib/quantity.ml is the one file with a delta beyond the header:  the
fourth mark W of section 4 of M0-PLAN.md, its five mul arms, its six
equal arms, its to_string arm and the prose that states the table.

| file | origin | diff lines |
| --- | --- | --- |
| lib/level.ml | de40d65:lib/level.ml | 4 |
| lib/level.mli | de40d65:lib/level.mli | 4 |
| lib/literal.ml | de40d65:lib/literal.ml | 4 |
| lib/budget.ml | de40d65:lib/budget.ml | 4 |
| lib/budget.mli | de40d65:lib/budget.mli | 4 |
| lib/error.ml | de40d65:lib/error.ml | 2 |
| lib/shape.ml | de40d65:lib/shape.ml | 2 |
| lib/quantity.ml | de40d65:lib/quantity.ml | 66 |

lib/spec_count.ml is not carried:  it is taciturn's own file and it holds
no carry header, so carry-check.sh wants no row for it.

surface/lexer.ml and surface/parser.ml are carried as algorithm, not byte
for byte, so they hold no carry header and no row.  Each mirrored function
cites its kanon line above the definition.

lib/prim.ml and lib/positivity.ml are named in the Stage A brief and do
not land here.  Both read lib/term.ml, and prim.ml also reads lib/rules.ml
and lib/value.ml, none of which Stage A delivers, so a byte for byte carry
of either one does not compile.  Both arrive with the kernel at Stage B.
