# Circuit identity, encoding version 1

The Stage C digest library identifies a validated BN254 row circuit and
its compilation context.  `taciturn_zk.Digest.encode` produces pure
canonical bytes; `taciturn_zk_host.Hash.circuit` hashes them with SHA-256.
This adopts M0-PLAN D-M0-2's recommendation as a provisional implementation
choice.  It does not mark the decision sheet ratified.

The digest describes the ordered rows before L1 lowering.  Wire numbers,
row order and allocated wire count are significant, including unused
wires and rows that L1 later removes.  This is a deterministic encoding
of that representation, with no claim that equivalent circuits have the
same digest.  Every field coefficient uses its canonical residue.
Witness bindings and values, including public outputs, are absent.

All integers below are unsigned little endian.  A framed string is its
byte length as u64 followed by exactly those bytes, with no terminator.
Names and compiler versions are byte strings without Unicode normalization.
Import hashes occupy exactly 64 lower-case ASCII hexadecimal bytes.
The encoding concatenates these fields in the stated order:

| Field | Encoding |
| --- | --- |
| Domain | ASCII `taciturn-circuit` followed by one zero byte |
| Format version | u32, value 1 |
| Hash algorithm | framed `sha256` |
| Row format | framed `plonk-rows-bn254-v1` |
| Prime | 32 bytes, BN254 scalar prime |
| Compiler version | framed, nonempty |
| Native import set | framed `zk`, then its SHA-256 hex |
| Symbolic import set | framed `sym`, then its SHA-256 hex |
| Advice import set | framed `pre`, then its SHA-256 hex |
| Width count | u64 |
| Each width entry | framed name, then field-slot width as u32 |
| Public output count | u32 |
| Public input count | u32 |
| Private input count | u32 |
| Allocated wire count | u32, including constant wire 0 |
| Row count | u64 |
| Each row | ql, qr, qo, qm, qc as five 32-byte field residues, then a, b, c, lookup as four u32 values |

Width names sort by OCaml `String.compare`, in ascending byte order.
Empty and duplicate names are refused.  Widths range from 0 to
4294967295; zero represents an erased or empty carrier.  The table may
be empty.  Upper-case import hex is accepted and normalized; malformed
hashes are refused before a context can be constructed.  All three
namespace fields are required, even when a particular circuit makes no
calls into one of them.  The row builder currently refuses nonzero lookup
tags; the zero tag still has an explicit slot in each encoded row.

The caller must supply the complete width table, hashes of the actual
three import implementations and a compiler version that changes with
the compiler or backend.  This library cannot verify their provenance
or infer them from a typed program.  Missing tables and invented but
well-formed hashes do not become trustworthy through hashing.  The
digest also does not establish constraint completeness, proof-system
soundness or compatibility of separately selected proving artifacts.
Typed metadata production, `taciturn digest FILE`, disclosure integration
and digest-based zkey naming remain subsequent integration work.

The host layer uses the fixed `/usr/bin/shasum` executable with algorithm
256 and binary input mode.  It passes an argument vector directly, gives
the child process the explicit environment PATH=/usr/bin:/bin, checks
the process status and exact output shape, and returns named error
values.  A signal is named, not numbered.  Only the canonical preimage
is written to a temporary file, with cleanup attempted on success and
on every reported failure.  A cleanup error is reported when the hash
succeeded.  A hash error has precedence over a cleanup error.  Newlines
and backslashes in temporary paths follow shasum's escaped filename
convention.  The host tool and its /usr/bin/perl interpreter remain
trusted dependencies; this slice does not add a SHA-256 implementation
to the pure backend.

Validation: `zsh dev/zk-digest-gates.sh` runs native identity checks and
an independent Node BigInt encoding plus SHA-256 comparison.  Each of
multiplication, MiMC-3, inverse, equality and select undergoes 1,000
witness substitutions with identical preimage bytes.  The corpus also
checks metadata changes, every selector, wire indices, each interface
count on its own, the allocated wire count, row order, booleanity and
rows discarded by L1.  The host suite checks standard hash vectors,
binary circuit bytes, temporary-file cleanup, unusual paths, a missing
temporary directory, PATH shadowing and a Perl module path override.
`python3 -I dev/zk-digest-mutate.py` requires eleven compiling mutants
to fail their named identity or oracle checks.
