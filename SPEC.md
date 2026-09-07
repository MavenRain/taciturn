# taciturn M0

## 1 The claim

taciturn is kanon with a witness quantity.  A taciturn program is a kanon
program whose binders carry one more mark, W, and whose declarations may
carry the zk attribute.  M0 delivers the surface, the marks, the extern
kind with a per-argument quantity signature, the row IR with its L1
lowering, the import section and its three import sets, and the circuit
digest.  M0 proves the claim on two circuits, `x * y = z` and a
three-round MiMC, whose row count stays within 1.25 of circom on the same
MiMC.

The kernel is unchanged.  Two formers, four schema constructors and five
declared shapes at kanon c418062 are two formers, four schema
constructors and five declared shapes here, and the R0 block below pins
that.  A surface form is sugar over one kernel constructor and never a
former, which the sugar table of section 4 shows row by row.

Stage A of M0 delivers the pin, the skeleton, the carried leaf modules,
the witness quantity, the surface and this document.  Stage B delivers
the kernel and the checker, Stage C the backend and the rows, and Stage D
the encoder and the witness writer.  A form that is declared here and not
delivered yet names its stage in the row that declares it.

## 2 The closed grammar

The surface of M0 is closed:  the parser refuses a word that is not
below, with the milestone name of the word in the refusal.  Every
production maps to one kernel constructor through section 4.

```
decl    ::= 'def' name ':' term ':=' term
          | 'zk' 'def' name ':' term ':=' term
          | 'axiom' name ':' term
term    ::= 'fun' binder+ '=>' term
          | 'let' name ':' term ':=' term 'in' term
          | binder '->' term | binder '*' term
          | term '->' term  | term '*' term
          | app
app     ::= app atom | 'inj' nat 'of' nat app | 'absurd' app | atom
atom    ::= name | nat | 'Prop' | 'Type' nat | '()' | 'auto'
          | 'tuple' items | 'sum' items | 'prod' items
          | '(' term ')' | '(' term ',' term ')' | '(' term ':' term ')'
          | atom '.' nat
binder  ::= '(' mark? name ':' term ')'
mark    ::= '0' | 'w' | '1'
items   ::= '()' | '(' term (',' term)* ')'
```

| constructor | milestone | note |
| --- | --- | --- |
| `def`, `axiom` | M0 | the two declaration forms |
| `zk def` | M0 | the ZKMARK attribute of D-M0-3 |
| the marks `0`, `w`, `1` and the absent mark | M0 | section 3 |
| `fun`, `let`, `->`, `*`, application | M0 | |
| `tuple`, `sum`, `prod`, `inj`, `absurd`, `.k` | M0 | |
| `Prop`, `Type n`, `()`, `auto`, `( : )` | M0 | |
| `Field p`, `Bit`, `select` | M0 | declared at Stage A, checked at Stage C |
| `case ... with` | M1 | the collection elimination form |
| `Fin (2^k)` | M1 | declared and refused with the name M1, correction C2 |
| `mu` | M1 | reserved;  the parser refuses it with "mu arrives at M1" |
| `nu` | M2 | reserved;  the parser refuses it with "nu arrives at M2" |
| hints in the language | M1 | the `pre.*` namespace links at M0 and the surface form is M1 |

Application by juxtaposition is left associative.  It binds tighter than
the arrow and the star and looser than the postfix `.1`, `.2` and `.k`,
which is kanon SA-D1.

## R0 counts

`taciturn spec-count` prints this block and dev/r0-count.sh diffs the two
texts, so a count that moves without an edit here fails the R0-COUNT gate.
Stage A moves no count:  the witness quantity adds a mark and adds no
former, no schema constructor and no shape.  Stage B moves no count
either:  the `Extern` kind is a global kind and it is not a former, not
a schema constructor and not a shape, so it adds the ninth line below
and changes none of the eight above it.

```
formers 2: Lan Ran
schema constructors 4: In Elim Sec Out
shapes declared 5: SPi SColl SPar SMu SNu
shapes admitted 3: SPi SColl SMu
named rules declared 3: proof-irrelevance subsingleton-large-elimination literal-fast-path
named rules present 3: proof-irrelevance subsingleton-large-elimination literal-fast-path
eta rows 3: Ran-SPi Lan-SPi Ran-SColl
no eta 3: Lan-SColl Ran-SMu Lan-SMu
global kinds 4: Def Axiom Prim Extern
```

The ninth line is D-M0-4's and it lands at Stage B with the `Extern`
entry of lib/global.ml.  Its number is the length of `Global.kinds` and
its companion `Global.kind_name` is total over the entry sum, so a fifth
kind is a compile error before it is a silent drift.  The three pinned
numbers above do not move, so the milestone row is unaffected.

## 3 Quantity, the four marks

`type t = Zero | W | One | Many`, in that order, lib/quantity.ml.  The
surface reads the binder marks `0`, `w` and `1`, and an absent mark reads
as `Many` (D-M0-3).  `to_string` spells the four marks `0`, `w`, `1` and
`many`.

`Zero` is the erased mark:  the binder exists at check time and erases
before evaluation.  `W` is the witness mark, new at taciturn M0:  the
value is private to the prover and reaches the row builder and nothing
else.  `One` is the linear mark.  `Many` is runtime data.

Multiplication is the sixteen-arm table of lib/quantity.ml, which
composes a binder's mark with the mark of the position it is used in.
`Zero` absorbs on both sides, which is seven arms;  `W` carries over
every mark that is not `Zero`, which is five arms;  `One` is the unit;
and the three remaining pairs give `Many`.

```
Zero, Zero -> Zero      Zero, W    -> Zero      Zero, One  -> Zero      Zero, Many -> Zero
W,    Zero -> Zero      One,  Zero -> Zero      Many, Zero -> Zero
W,    W    -> W         W,    One  -> W         W,    Many -> W
One,  W    -> W         Many, W    -> W
One,  One  -> One
One,  Many -> Many      Many, One  -> Many      Many, Many -> Many
```

### 3.1 The occurrence rule, NORMATIVE

No occurrence of a W-marked binder may sit at a One-stamped or a
Many-stamped point.  `prove` is the only exception:  its witness
parameter is the one place where W data crosses into a construction that
a public value depends on, and the two axioms of section 6 carry that
crossing.

| binder mark | at a Zero point | at a W point | at a One point | at a Many point |
| --- | --- | --- | --- | --- |
| `Zero` | admitted | refused | refused | refused |
| `W` | admitted | admitted | refused, `prove` excepted | refused, `prove` excepted |
| `One` | admitted | admitted | admitted, once | refused |
| `Many` | admitted | admitted | admitted | admitted |

Stage A declares this rule and Stage B enforces it.  A refusal is
`Error.Quantity` with the name of the binder and the name of the point.

### 3.2 The sum, a well-formedness check

The sum counts usage and it is not the normative rule above.  It checks
the counted usage of a binder against its declared mark:  admissible in
`{Zero}` at a `Zero` binder, in `{Zero, W}` at a `W` binder, in
`{One}` on each returning runtime path at a `One` binder, and anywhere
at a `Many` binder.  `One + One = Many`, so two reads on one path fail.
The Stage K carry counts alternatives separately and requires exactly
one read on each returning path.  An erased read does not discharge a
linear binder.  A nonreturning path may omit it but may not duplicate it.
Closure capture and let aliases retain the demands of their consumers.
The witness sum remains idempotent, `W + W = W`; a W argument is
duplicable and cannot consume a linear One binder.

| plus | `Zero` | `W` | `One` | `Many` |
| --- | --- | --- | --- | --- |
| `Zero` | `Zero` | `W` | `One` | `Many` |
| `W` | `W` | `W` | `Many` | `Many` |
| `One` | `One` | `Many` | `Many` | `Many` |
| `Many` | `Many` | `Many` | `Many` | `Many` |

Two erasures run over one parameterised traversal:  the prover erasure
keeps `{W, One, Many}` and the public erasure keeps `{One, Many}`.  Both
lemmas over them, erasure well-formedness and two-erasure agreement, are
M2 Lean 4 work.

## 4 The sugar table

Every surface form maps to one kernel constructor.  Read the right-hand
column to confirm that no surface form is a former.  The table is
carried from kanon SPEC.md section 7 at the pin de40d65, and the last
two rows are new at taciturn M0 (D-M0-3).

| surface form | kernel form | note |
| --- | --- | --- |
| `fun (q x : A) => b` | `Sec (SPi (q, x, A)) [x => b]` | sugar, not former |
| `(q x : A) -> B` | `Ran (SPi (q, x, A)) B` | sugar, not former |
| `A -> B` | `Ran (SPi (Many, "_", A)) B` | sugar, not former |
| `(q x : A) * B` | `Lan (SPi (q, x, A)) B` | sugar, not former |
| `A * B` | `Lan (SPi (Many, "_", A)) B` | sugar, not former |
| `f a` | `Out (SPi ..) (APt (q, a)) f` | sugar, not former.  SA-D1 |
| `(a, b)` | `In (SPi ..) (APt (q, a)) [b]` | sugar, not former |
| `p.1` | `Elim` at `Lan (SPi ..)`, leg `ALeg 0`, first branch binder, with the projection motive | sugar, not former.  D-M0-3 |
| `p.2` | `Elim` at `Lan (SPi ..)`, leg `ALeg 0`, second branch binder, with the projection motive | sugar, not former.  D-M0-3 |
| `inj k of n t` | `In (SColl n) (ALeg k) [t]` | sugar, not former |
| `case t as x return M with \| k xs => b` | `Elim` at `Lan (SColl n)` | sugar, not former |
| `case t as x in F i1 .. im return M with \| c y1 .. yn => b` | `Elim` at `Lan (SMu (F, ..))` | sugar, not former.  M1 |
| `tuple (t1, .., tn)` | `Sec (SColl n) [.. => t1; ..]` | sugar, not former |
| `sum (A1, .., An)` | `Lan (SColl n) (Sec (SColl n) [.. => A1; ..])` | sugar, not former.  SB-D1 |
| `prod (A1, .., An)` | `Ran (SColl n) (Sec (SColl n) [.. => A1; ..])` | sugar, not former.  SB-D1 |
| `t.k` | `Out (SColl n) (ALeg k) t` | sugar, not former |
| `()` | `Sec (SColl 0) []` | sugar, not former |
| `absurd t` | `Elim` at `Lan (SColl 0)` with no branches | sugar, not former |
| `Prop` | `Univ zero` | sugar, not former |
| `Type n` | `Univ (n + 1)` | sugar, not former.  SB-D2 |
| `let x : A := d in b` | `Let (x, A, d, b)` | sugar, not former |
| `(t : A)` | `Ann (t, A)` | sugar, not former |
| `auto` | `Auto` | sugar, not former.  SA-D3 |
| `mu` | none.  Reserved;  the parser refuses it with "mu arrives at M1" | SA-D3 |
| `nu` | none.  Reserved;  the parser refuses it with "nu arrives at M2" | SA-D3 |
| `zk def name : A := t` | the `Def` node of `def`, with the zk flag set | sugar, not former.  D-M0-3 |
| `(w x : A)` | the binder of the row above it, at `Quantity.W` | sugar, not former.  D-M0-3 |

ZKMARK is the keyword pair `zk def`.  It reads as an attribute on `def`
and it declares no second form:  the parser returns the same declaration
node with a zk flag, so every rule over a declaration reads a zk
declaration without a new case.  Stage E reads the flag and Stage A only
carries it.

WMARK is the binder mark `w`, beside `0` and `1`.  The three marks read
as `Quantity.Zero`, `Quantity.W` and `Quantity.One`, and an absent mark
reads as `Quantity.Many`, which is what kanon does at the pin.

## 5 The encoder subset

The encoder writes this subset and nothing else.  The table is carried
from kanon SPEC.md section 8 at the pin de40d65, and the row SD-D15
below is amended for taciturn.  The encoder itself arrives at Stage D;
Stage A declares the subset so that a later diff of this table shows the
growth.

| group | members |
| --- | --- |
| numbers | LEB128 unsigned, LEB128 signed |
| sections used | type, import, function, export, element (declarative segments only), code |
| sections refused | table, memory, global, start, data |
| composite types | struct, array, func, in rec groups, final subtypes only |
| control | `block`, `loop`, `if`, `br`, `br_if`, `br_on_cast`, `return`, `unreachable` |
| calls | `call`, `return_call`, `call_ref`, `return_call_ref` |
| locals | `local.get`, `local.set`, `local.tee` |
| numeric | `i32.const`, `i32.add`, `i32.sub`, `i32.mul`, `i32.div_u`, `i32.eq`, `i32.ne`, `i32.lt_u`, `i32.gt_u` |
| references | `ref.i31`, `i31.get_s`, `i31.get_u`, `ref.cast`, `ref.func`, `ref.null`, `ref.is_null` |
| structs | `struct.new`, `struct.get` |

| row | text |
| --- | --- |
| SD-D15 (amended) | the module has an import section, id 2, spliced between the type section and the function section, and still has no table, memory, global, start or data section |

SD-D15 is cited from two kanon sites at the pin de40d65:  the doc
comment at wasm/gc_encode.ml:200-203, which reads "SD-D15:  the module
has no import, table, memory, global, start or data section", and the
prose of SPEC.md:354 inside section 8, which reads "no import beyond the
gate's export".  taciturn M0 links three import namespaces, section 8
below, so the module carries an import section and the old wording is
false here.  Nothing else in the row moves:  the four refused sections
stay refused and the gate leg reads the amended row.

M0 emits WasmGC core modules only (R-Q4).  There is no linear memory and
no tag.  The text form of a module is the print of the binary, so it can
hold one word that this table does not list;  the printer writes `drop`
around a value that stays on the stack in front of an `unreachable`, and
the gate reads that word as the printer's and not as an opcode of the
encoder (SD-D24).

## 6 The disclosure ledger

Every built-in extern and axiom has one row here.  An extern with no row
refuses to link, and an axiom reaches this ledger and never the code
section.  The quantity signature is per argument (delta 3 of the M0
plan):  it is the mark stamped on the position, and the occurrence rule
of section 3.1 reads it.  Linking normalizes a postulate's type and checks
both the arity and binder marks against its disclosed signature.  This
keeps aliases and annotations from changing the marks of an extern call.
A `w` position takes a `W`, a `One` or a
`Many` binder and refuses a `Zero` binder, so a `w` position is what
keeps witness data out of a public channel.  Stage A declared all ten
rows.  Stage B links the two axioms, because the axioms verb of the
driver prints them from the file it reads, and lib/disclosure.ml carries
the same ten rows in code so that an extern with no row here refuses to
link.  The eight externs link at Stage C, because each one needs
`Field p` or the row IR, which Stage C delivers.

The `axioms` verb reports every checked axiom and extern declared by the
file, including supporting type postulates and names outside this fixed
ledger.  Each row prints the actual checked type; a matching ledger row
adds its description and expected quantity signature.

| name | kind | text | quantity signature | state |
| --- | --- | --- | --- | --- |
| `field.add` | extern | the sum of two field values at the prime p | `(w a : Field p) -> (w b : Field p) -> Field p` | declared at Stage A, linked at Stage C |
| `field.mul` | extern | the product of two field values at the prime p | `(w a : Field p) -> (w b : Field p) -> Field p` | declared at Stage A, linked at Stage C |
| `field.inv` | extern | the multiplicative inverse of a field value, with zero mapped to zero | `(w a : Field p) -> Field p` | declared at Stage A, linked at Stage C |
| `field.eq` | extern | the equality test of two field values, one for equal and zero for other | `(w a : Field p) -> (w b : Field p) -> Field p` | declared at Stage A, linked at Stage C |
| `select` | extern | the only elimination of a `Bit`, which returns the second argument at one and the third at zero | `(w b : Bit) -> (w x : Field p) -> (w y : Field p) -> Field p` | declared at Stage A, linked at Stage C |
| `alloc` | extern | the wire allocator, which appends the rows of one call and returns the wire index of its value | `(w v : Field p) -> Wire` | declared at Stage A, linked at Stage C |
| `prove` | extern | the declassifier, which reads a witness at `w` and returns a public proof | `(many R : Circuit) -> (many x : Public) -> (w wit : Witness) -> Proof R x` | declared at Stage A, linked at Stage C |
| `verifyRaw` | extern | the raw verifier, which returns one on an accepted proof and zero on any other | `(many R : Circuit) -> (many x : Public) -> (many v : Proof R x) -> Field p` | declared at Stage A, linked at Stage C |
| `sound` | axiom | `verifyRaw R x v = 1 -> Exists w, R x w = 1`, the soundness of the raw verifier | `(many R : Circuit) -> (many x : Public) -> (many v : Proof R x) -> (many h : verifyRaw R x v = 1) -> Exists w, R x w = 1` | linked at Stage B |
| `verify_reflect` | axiom | a verifier output wire constrained to one gives the fibre `Proof R x` | `(many R : Circuit) -> (many x : Public) -> (many o : Field p) -> (many h : o = 1) -> Proof R x` | linked at Stage B |

`prove` is the one exception of the occurrence rule of section 3.1:  its
witness parameter is the single place where `W` data crosses into a
public value, and the two axioms above carry that crossing.  The
completeness of `prove` is a believed row with a property gate and it is
not an axiom here.

The wire index that `alloc` returns comes back padded into the value
shape of the field, so the width identity is a host convention and it
sits in the trusted base.

## 7 The wire order convention

D-M0-5.  The wire list of every circuit is written in one order:  wire 0
is the constant one, then the public outputs, then the public inputs,
then the private inputs, then the internal wires.  The formats fix wire
0 and the witness count and the header separates the public count from
the private count, and no format fixes the order of the rest, so the
order is a convention of this compiler.  The convention is the one that
snarkjs expects and the one the Stage 0 spike already writes, and the
blind reader of the row files checks it.

## 8 The three namespaces

D-M0-8.  One signature list has three implementations and each one is a
wire namespace of its own.

`zk.*` is the native set:  `field.add`, `field.mul`, `field.inv`,
`field.eq` and `select` run over a field library, and the trace of the
run is the witness.

`sym.*` is the symbolic set at the same signatures:  every call
allocates a wire index and appends its rows, and the trace of the run is
the constraint file.

`pre.*` is the row free set (R-Q2):  a call computes and emits no row,
which is where a hint lives, and a `pre` value re-enters only as a fresh
`W` input to a check whose `Bit` is constrained to one.  At M0 the
namespace exists and links, and hints in the language arrive at M1.

Each set carries a digest of its implementation and the digest of the
circuit reads all three.  A missing namespace is a link error at load
time, which the Stage 0 spike shows.

## 9 Hand-off notes for Stage C

The Stage K re-pin supplies arbitrary-precision Nat through Zarith 1.14.
Natural literals and their arithmetic have no machine-integer bound.
Universe levels, collection widths and projection indices still require
checked machine integers; a value outside that range is a parse error.
The family declaration surface stays deferred to M1 under D-B-2.

The `RField` arm of delta 2 arrives at Stage C.  `lib/eterm.ml` is not
carried at Stage B, because the Stage B row of the plan does not name it
and the Stage C row does, so the repr sum gains its arm beside `RI31`
when `Field p` lands.

The two erasures of delta 1 arrive at Stage C with `lib/erase.ml`.  They
run over one parameterised traversal:  the prover erasure keeps
`{W, One, Many}` and the public erasure keeps `{One, Many}`.  Section 3.2
declares them and no file implements them yet.

Four of the nine required negatives of the plan arrive at Stage C,
because each one reads the zk fragment or `Field p`:  an `Elim` on a
`Bit` outside `select`, a `Nat` at runtime inside zk, a `Vec` at a
runtime `n` inside zk, and a `Ran SPi` at runtime that is not fully
applied.  Stage B delivers the other five.

The eight extern rows of the ledger of section 6 link at Stage C.  Each
one needs `Field p` or the row IR.  The two axioms link at Stage B.
