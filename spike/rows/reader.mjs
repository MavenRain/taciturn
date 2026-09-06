// reader.mjs: blind reader for spike (a), written from the format spec alone.
// Sources: taciturn-dossier-toolchain.md sections 1 (r1cs) and 2 (wtns),
// and the MiMC-3 definition of stage-0-brief.md section 4.
// Never opens spike/rows/*.ml, never runs rows.exe, never reads spike/out.
import { readFile } from "node:fs/promises";

const P = 21888242871839275222246405745257275088548364400416034343698204186575808495617n;
const FS = 32;

function fail(reason) {
  console.log(`READER FAIL reason=${reason}`);
  process.exit(1);
}

function readU32LE(buf, off) {
  return buf.readUInt32LE(off);
}

function readU64LE(buf, off) {
  return buf.readBigUInt64LE(off);
}

function readBigLE(buf, off, len) {
  let v = 0n;
  for (let i = len - 1; i >= 0; i -= 1) {
    v = (v << 8n) | BigInt(buf[off + i]);
  }
  return v;
}

function parseSections(buf, magicStr, expectedVersion, tag) {
  const magic = buf.toString("ascii", 0, 4);
  if (magic !== magicStr) fail(`${tag}-magic`);
  const version = readU32LE(buf, 4);
  if (version !== expectedVersion) fail(`${tag}-version`);
  const nSections = readU32LE(buf, 8);
  let off = 12;
  const sections = new Map();
  for (let i = 0; i < nSections; i += 1) {
    const type = readU32LE(buf, off);
    off += 4;
    const size = Number(readU64LE(buf, off));
    off += 8;
    sections.set(type, buf.subarray(off, off + size));
    off += size;
  }
  return sections;
}

function parseR1csHeader(content, tag) {
  if (content === undefined) fail(`${tag}-header-missing`);
  let off = 0;
  const fs = readU32LE(content, off);
  off += 4;
  if (fs !== FS) fail(`${tag}-fs`);
  const prime = readBigLE(content, off, fs);
  off += fs;
  if (prime !== P) fail(`${tag}-prime`);
  const wireCount = readU32LE(content, off);
  off += 4;
  const nPubOut = readU32LE(content, off);
  off += 4;
  const nPubIn = readU32LE(content, off);
  off += 4;
  const nPrivIn = readU32LE(content, off);
  off += 4;
  const nLabels = Number(readU64LE(content, off));
  off += 8;
  const nConstraints = readU32LE(content, off);
  return { fs, prime, wireCount, nPubOut, nPubIn, nPrivIn, nLabels, nConstraints };
}

function parseLC(buf, off, fs, label) {
  const count = readU32LE(buf, off);
  off += 4;
  const terms = [];
  let prevWire = -1;
  for (let i = 0; i < count; i += 1) {
    const wireId = readU32LE(buf, off);
    off += 4;
    const value = readBigLE(buf, off, fs);
    off += fs;
    if (value === 0n) fail(`${label}-zero-term`);
    if (wireId <= prevWire) fail(`${label}-sort`);
    prevWire = wireId;
    terms.push([wireId, value]);
  }
  return [terms, off];
}

function parseConstraints(content, fs, m, tag) {
  if (content === undefined) fail(`${tag}-constraints-missing`);
  let off = 0;
  const constraints = [];
  for (let i = 0; i < m; i += 1) {
    const [A, off1] = parseLC(content, off, fs, `${tag}-c${i}-A`);
    const [B, off2] = parseLC(content, off1, fs, `${tag}-c${i}-B`);
    const [C, off3] = parseLC(content, off2, fs, `${tag}-c${i}-C`);
    off = off3;
    constraints.push({ A, B, C });
  }
  if (off !== content.length) fail(`${tag}-constraint-count`);
  return constraints;
}

function parseLabels(content, wireCount, tag) {
  if (content === undefined) fail(`${tag}-labels-missing`);
  if (content.length !== wireCount * 8) fail(`${tag}-label-count`);
  const labels = [];
  for (let i = 0; i < wireCount; i += 1) {
    labels.push(readU64LE(content, i * 8));
  }
  if (labels[0] !== 0n) fail(`${tag}-label-wire0`);
  return labels;
}

function parseWtnsHeader(content) {
  if (content === undefined) fail("wtns-header-missing");
  let off = 0;
  const n8 = readU32LE(content, off);
  off += 4;
  if (n8 !== FS) fail("wtns-n8");
  const prime = readBigLE(content, off, n8);
  off += n8;
  if (prime !== P) fail("wtns-prime");
  const witnessCount = readU32LE(content, off);
  return { n8, prime, witnessCount };
}

function parseWtnsValues(content, n8, count) {
  if (content === undefined) fail("wtns-values-missing");
  if (content.length !== n8 * count) fail("wtns-value-count");
  const values = [];
  for (let i = 0; i < count; i += 1) {
    values.push(readBigLE(content, i * n8, n8));
  }
  return values;
}

function evalLC(terms, values) {
  return terms.reduce((acc, [w, v]) => (acc + v * values[w]) % P, 0n);
}

function mimc3Expected(x, k) {
  const c = [1n, 2n, 3n];
  let xi = ((x % P) + P) % P;
  const kk = ((k % P) + P) % P;
  for (let i = 0; i < 3; i += 1) {
    const t = (xi + kk + c[i]) % P;
    const t2 = (t * t) % P;
    const t4 = (t2 * t2) % P;
    const t6 = (t4 * t2) % P;
    xi = (t6 * t) % P;
  }
  return (xi + kk) % P;
}

async function main() {
  const args = process.argv.slice(2);
  if (args.length < 2) fail("usage");
  const [r1csPath, wtnsPath, ...rest] = args;

  const r1csBuf = await readFile(r1csPath);
  const wtnsBuf = await readFile(wtnsPath);

  const r1csSections = parseSections(r1csBuf, "r1cs", 1, "r1cs");
  const header = parseR1csHeader(r1csSections.get(1), "r1cs");
  const constraints = parseConstraints(r1csSections.get(2), header.fs, header.nConstraints, "r1cs");
  if (constraints.length !== header.nConstraints) fail("r1cs-constraint-count");
  const labels = parseLabels(r1csSections.get(3), header.wireCount, "r1cs");
  if (labels.length !== header.wireCount) fail("r1cs-label-count");

  const wtnsSections = parseSections(wtnsBuf, "wtns", 2, "wtns");
  const wHeader = parseWtnsHeader(wtnsSections.get(1));
  if (wHeader.n8 !== header.fs) fail("fs-mismatch");
  if (wHeader.prime !== header.prime) fail("prime-mismatch");
  if (wHeader.witnessCount !== header.wireCount) fail("witness-count");

  const values = parseWtnsValues(wtnsSections.get(2), wHeader.n8, wHeader.witnessCount);
  if (values[0] !== 1n) fail("wire0-value");

  for (let i = 0; i < constraints.length; i += 1) {
    const { A, B, C } = constraints[i];
    const a = evalLC(A, values);
    const b = evalLC(B, values);
    const c = evalLC(C, values);
    if ((a * b) % P !== c) fail(`constraint-${i}`);
  }

  if (rest.length > 0) {
    const kind = rest[0];
    if (kind === "mul" && rest.length >= 3) {
      const x = BigInt(rest[1]);
      const y = BigInt(rest[2]);
      const expected = ((x * y) % P + P) % P;
      if (values[1] !== expected) fail("circuit-mismatch");
    } else if (kind === "mimc3" && rest.length >= 3) {
      const x = BigInt(rest[1]);
      const k = BigInt(rest[2]);
      const expected = mimc3Expected(x, k);
      if (values[1] !== expected) fail("circuit-mismatch");
    } else {
      fail("usage");
    }
  }

  console.log(`READER OK constraints=${header.nConstraints} wires=${header.wireCount} out=${values[1]}`);
  process.exit(0);
}

main().catch((err) => {
  console.log(`READER FAIL reason=exception:${String((err && err.message) || err)}`);
  process.exit(1);
});
