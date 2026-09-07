# taciturn

Can a proof-system-native zk circuit language keep the W mark typed and
honest by construction, from the row IR through R1CS and WasmGC, with no
occurrence of a W-marked binder escaping to a public observable?

Sibling relation: taciturn vendors kanon Stage K under `vendor/kanon`.
The pin supplies arbitrary-precision Nat and path-sensitive linear One
checking.  Taciturn adds witness quantities and disclosed externs.

M0 gate, quoted from the verdict's milestone table:  `x * y = z` and a
3-round MiMC written in taciturn emit an `.r1cs` and a `.wtns` that
`snarkjs plonk setup`, `prove` and `verify` accept, the row count is
within 1.25 of circom on the same MiMC, and `spec_count` still prints two
formers, four schema constructors and five shapes.

Stages A and B deliver the kernel, surface and witness occurrence rule.
Stage 0 supplies the validated row IR, L1 lowering, `.r1cs` and `.wtns`
writers, blind JS reader, three-way WasmGC linking and circom comparison.
The Stage K re-pin prepares Stage C: Field p, the row backend and two
erasures.  Those Stage C features are not implemented yet.

PIN records `c4180626123687858ff83408bab801c6f87e3e71` and the
`vendor/kanon` submodule is checked out at that commit.  The kernel uses
Zarith 1.14.  `dev/CARRIED.md` records every carry and local delta.

Validation: `zsh dev/dunecho.sh build`, `zsh dev/dunecho.sh test`,
then `zsh dev/stage-a-gates.sh`, `zsh dev/stage-b-gates.sh` and
`zsh dev/spike-gates.sh`.  ROUNDTRIP and DIFF report PENDING only when
their external tools are absent.

User install commands, quoted from dossier-toolchain section 9 (run by
the user, never by an agent):

```
npm i -g snarkjs
git clone https://github.com/iden3/circom.git
cd circom && cargo install --path circom
curl -L -o powersOfTau28_hez_final_10.ptau https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_10.ptau
```
