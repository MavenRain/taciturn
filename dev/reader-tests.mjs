// Independent binary fixtures for the Stage 0 reader, with no OCaml dependency.
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const reader = process.argv[2] ?? fileURLToPath(new URL("../spike/rows/reader.mjs", import.meta.url));
const p = 21888242871839275222246405745257275088548364400416034343698204186575808495617n;
const cat = (...parts) => Buffer.concat(parts);
function le(value, bytes) {
  const out = Buffer.alloc(bytes);
  let n = BigInt(value);
  for (let i = 0; i < bytes; i += 1) {
    out[i] = Number(n & 255n);
    n >>= 8n;
  }
  return out;
}
const u32 = (n) => le(n, 4);
const u64 = (n) => le(n, 8);
const field = (n) => le(n, 32);
const section = (type, body) => cat(u32(type), u64(body.length), body);
const container = (magic, version, parts) => cat(Buffer.from(magic), u32(version), u32(parts.length), ...parts);
const lc = (terms) => cat(u32(terms.length), ...terms.map(([w, v]) => cat(u32(w), field(v))));
const header = cat(u32(32), field(p), u32(4), u32(1), u32(0), u32(2), u64(4), u32(1));
const constraints = cat(lc([[2, 1n]]), lc([[3, 1n]]), lc([[1, 1n]]));
const labels = cat(u64(0), u64(1), u64(2), u64(3));
const witnessHeader = cat(u32(32), field(p), u32(4));
const values = cat(field(1), field(42), field(6), field(7));
const r1cs = (h = header, c = constraints, l = labels) => container("r1cs", 1, [section(1, h), section(2, c), section(3, l)]);
const wtns = (v = values, h = witnessHeader) => container("wtns", 2, [section(1, h), section(2, v)]);
function replace(buf, off, bytes) {
  const out = Buffer.from(buf);
  bytes.copy(out, off);
  return out;
}
const dir = mkdtempSync(join(tmpdir(), "taciturn-reader-"));
let total = 0;
let failed = 0;
function check(name, r, w, reason = null) {
  writeFileSync(join(dir, "c.r1cs"), r);
  writeFileSync(join(dir, "c.wtns"), w);
  const result = spawnSync(process.execPath, [reader, join(dir, "c.r1cs"), join(dir, "c.wtns"), "mul", "6", "7"], { encoding: "utf8", timeout: 5000 });
  const expected = reason === null ? "READER OK constraints=1 wires=4 out=42" : `READER FAIL reason=${reason}`;
  const ok = !result.error && result.status === (reason === null ? 0 : 1) && result.stdout.trim() === expected;
  total += 1;
  if (!ok) {
    failed += 1;
    console.log(`READER-TEST FAIL ${name}: exit=${result.status} output=${result.stdout.trim()} error=${result.error ?? result.stderr.trim()}`);
  }
}
try {
  check("valid multiplication", r1cs(), wtns());
  // Sections are identified by type, not by their physical order.
  check("reordered sections", container("r1cs", 1, [section(3, labels), section(2, constraints), section(1, header)]), wtns());
  check("unknown framed section", container("r1cs", 1, [section(1, header), section(2, constraints), section(3, labels), section(99, Buffer.from("extension"))]), wtns());
  check("witness plus prime", r1cs(), wtns(replace(values, 64, field(p + 6n))), "wtns-field-range");
  check("coefficient plus prime", r1cs(header, replace(constraints, 8, field(p + 1n))), wtns(), "r1cs-c0-A-field-range");
  check("coefficient equals prime", r1cs(header, replace(constraints, 8, field(p))), wtns(), "r1cs-c0-A-field-range");
  check("wire outside witness", r1cs(header, replace(constraints, 4, u32(4))), wtns(), "r1cs-c0-A-wire-range");
  check("impossible LC count", r1cs(header, replace(constraints, 0, u32(0xffffffff))), wtns(), "r1cs-c0-A-size");
  check("truncated LC count", r1cs(header, Buffer.alloc(3)), wtns(), "r1cs-c0-A-size");
  check("zero coefficient", r1cs(header, replace(constraints, 8, field(0))), wtns(), "r1cs-c0-A-zero-term");
  check("unsorted terms", r1cs(header, cat(lc([[3, 1n], [2, 1n]]), lc([[3, 1n]]), lc([[1, 1n]]))), wtns(), "r1cs-c0-A-sort");
  check("duplicate wire", r1cs(header, cat(lc([[2, 1n], [2, 1n]]), lc([[3, 1n]]), lc([[1, 1n]]))), wtns(), "r1cs-c0-A-sort");
  check("altered witness", r1cs(), wtns(replace(values, 64, field(8))), "constraint-0");
  check("constant wire", r1cs(), wtns(replace(values, 0, field(2))), "wire0-value");
  check("interface exceeds wires", r1cs(replace(header, 40, u32(4))), wtns(), "r1cs-interface-count");
  check("label out of range", r1cs(header, constraints, replace(labels, 24, u64(4))), wtns(), "r1cs-label-range");
  check("duplicate label", r1cs(header, constraints, replace(labels, 24, u64(2))), wtns(), "r1cs-label-duplicate");
  check("short R1CS header", r1cs(header.subarray(0, 63)), wtns(), "r1cs-header-size");
  check("long R1CS header", r1cs(cat(header, u32(0))), wtns(), "r1cs-header-size");
  check("short witness header", r1cs(), wtns(values, witnessHeader.subarray(0, 39)), "wtns-header-size");
  check("long witness header", r1cs(), wtns(values, cat(witnessHeader, u32(0))), "wtns-header-size");
  check("high bit in magic", replace(r1cs(), 1, Buffer.from([0xb1])), wtns(), "r1cs-magic");
  check("no public output", r1cs(replace(header, 40, u32(0))), wtns(), "r1cs-pub-out");
  check("witness count against wire count", r1cs(), wtns(values, cat(u32(32), field(p), u32(5))), "witness-count");
  check("extra constraint bytes", r1cs(header, cat(constraints, u32(0))), wtns(), "r1cs-constraint-count");
  check("short label map", r1cs(header, constraints, labels.subarray(0, 24)), wtns(), "r1cs-label-count");
  check("wire 0 label not 0", r1cs(replace(header, 52, u64(8)), constraints, replace(labels, 0, u64(4))), wtns(), "r1cs-label-wire0");
  check("R1CS field size not 32", r1cs(replace(header, 0, u32(16))), wtns(), "r1cs-fs");
  check("witness n8 not 32", r1cs(), wtns(values, replace(witnessHeader, 0, u32(16))), "wtns-n8");
  check("R1CS prime not BN254", r1cs(replace(header, 4, field(p - 1n))), wtns(), "r1cs-prime");
  check("R1CS header section missing", container("r1cs", 1, [section(2, constraints), section(3, labels)]), wtns(), "r1cs-header-missing");
  check("R1CS constraints section missing", container("r1cs", 1, [section(1, header), section(3, labels)]), wtns(), "r1cs-constraints-missing");
  check("R1CS labels section missing", container("r1cs", 1, [section(1, header), section(2, constraints)]), wtns(), "r1cs-labels-missing");
  check("witness header section missing", r1cs(), container("wtns", 2, [section(2, values)]), "wtns-header-missing");
  check("witness values section missing", r1cs(), container("wtns", 2, [section(1, witnessHeader)]), "wtns-values-missing");
  for (const [tag, valid] of [["r1cs", r1cs()], ["wtns", wtns()]]) {
    const malformed = (name, bytes, reason) => check(`${tag} ${name}`, tag === "r1cs" ? bytes : r1cs(), tag === "wtns" ? bytes : wtns(), `${tag}-${reason}`);
    malformed("short preamble", valid.subarray(0, 11), "preamble-size");
    malformed("short section header", valid.subarray(0, 23), "section-header-size");
    malformed("truncated section", valid.subarray(0, valid.length - 1), "section-size");
    malformed("oversized section", replace(valid, 16, u64(2n ** 64n - 1n)), "section-size");
    malformed("trailing bytes", cat(valid, u32(0)), "trailing-bytes");
    const firstEnd = 24 + Number(valid.readBigUInt64LE(16));
    const duplicate = cat(replace(valid, 8, u32(valid.readUInt32LE(8) + 1)), valid.subarray(12, firstEnd));
    malformed("duplicate section", duplicate, "section-duplicate");
  }
} finally {
  rmSync(dir, { recursive: true, force: true });
}
console.log(`READER-TESTS ${failed === 0 ? "OK" : "FAIL"} ${total - failed}/${total}`);
process.exitCode = failed === 0 ? 0 : 1;
