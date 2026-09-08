import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const executable = resolve(process.argv[2]);
const work = mkdtempSync(join(tmpdir(), "taciturn-aggregate-"));

// A left nested pair type of this depth with a matching chain of first
// projections.  The program is well typed, so the case measures what it
// costs to elaborate a projection prefix under the same five second bound
// the rejection cases run under.
const depth = 120;
const nested = Array.from({ length: depth - 1 }).reduce(
  (acc) => ({ ty: `(${acc.ty}) * Nat`, val: `(${acc.val}, 1)` }),
  { ty: "Nat * Nat", val: "(1, 1)" },
);
const chain = `
def deep : ${nested.ty} := ${nested.val}
def flat : Nat := deep${".1".repeat(depth)}
`;

const cases = [
  ["unchecked-let-loop", `
def bad : Nat :=
  let self : (f : (x : Nat) -> Nat) -> Nat :=
    fun (f : (x : Nat) -> Nat) => f f
  in let loop : Nat := self self in 0
`, "reject"],
  ["let-in-type-position-loop", `
def bad :
  (let self : (f : (x : Nat) -> Nat) -> Nat :=
     fun (f : (x : Nat) -> Nat) => f f
   in let loop : Nat := self self in Nat) := 0
`, "reject"],
  ["let-in-pair-point-loop", `
def bad : (0 A : Type 0) * A :=
  (let self : (f : (x : Nat) -> Nat) -> Nat :=
     fun (f : (x : Nat) -> Nat) => f f
   in let loop : Nat := self self in Nat, 0)
`, "reject"],
  ["projection-chain-cost", chain, "accept"],
];

const verdicts = {
  reject: (result) => !result.error && result.status === 1
    && result.stdout === "" && result.stderr.startsWith("mismatch:"),
  accept: (result) => !result.error && result.status === 0 && result.stderr === "",
};

const runCase = ([name, source, expect]) => {
  const path = join(work, `${name}.tac`);
  writeFileSync(path, source);
  const result = spawnSync(executable, ["check", path], {
    encoding: "utf8", timeout: 5000,
  });
  const ok = verdicts[expect](result);
  console.log(`AGGREGATE-CLI ${name} ${ok ? "OK" : "FAIL"}`);
  if (!ok) {
    console.error(result.error?.message ?? result.stderr);
  }
  return ok;
};

const outcomes = (() => {
  try {
    return cases.map(runCase);
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
})();
const passed = outcomes.filter(Boolean).length;
console.log(`AGGREGATE-CLI ${passed}/${cases.length}`);
process.exitCode = passed === cases.length ? 0 : 1;
