# taciturn

Can a proof-system-native zk circuit language keep the W mark typed and
honest by construction, from the row IR through R1CS and WasmGC, with no
occurrence of a W-marked binder escaping to a public observable?

Sibling relation: taciturn is a sibling of kanon.  It vendors kanon at
M1-EXIT under `vendor/kanon` once the pin exists (kanon Stage K, the
bignum Nat and the linear counting, has not opened, so Stage 0 needs no
pin and runs first).

M0 gate, quoted from the verdict's milestone table:  `x * y = z` and a
3-round MiMC written in taciturn emit an `.r1cs` and a `.wtns` that
`snarkjs plonk setup`, `prove` and `verify` accept, the row count is
within 1.25 of circom on the same MiMC, and `spec_count` still prints two
formers, four schema constructors and five shapes.

Stage 0 status: the three Q6 spikes only, no kernel code.  Spike (a) is
the OCaml row IR, L1 lowering, `.r1cs` and `.wtns` writers plus a blind
JS reader.  Spike (b) is the WasmGC import table linked three ways
(native, symbolic, `pre.*`).  Spike (c) is the circom differential
source and the round-trip script, both PENDING because circom and
snarkjs are not installed:

- S0-G7 ROUNDTRIP: PENDING until snarkjs is installed.
- S0-G8 DIFF: PENDING until circom and snarkjs are installed.

User install commands, quoted from dossier-toolchain section 9 (run by
the user, never by an agent):

```
npm i -g snarkjs
git clone https://github.com/iden3/circom.git
cd circom && cargo install --path circom
curl -L -o powersOfTau28_hez_final_10.ptau https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_10.ptau
```
