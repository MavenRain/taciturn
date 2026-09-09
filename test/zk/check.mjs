import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { spawnSync } from 'node:child_process';

const [probe, spike, reader] = process.argv.slice(2).map(p => resolve(p));
const work = mkdtempSync(join(tmpdir(), 'taciturn-backend-'));
const p = 21888242871839275222246405745257275088548364400416034343698204186575808495617n;
const mod = x => (x % p + p) % p;
let checks = 0;
const expected = 24;
function run(exe, args, expected = 0) {
  const child = spawnSync(exe, args, { encoding: 'utf8', timeout: 15000 });
  assert.equal(child.status, expected, `${args.join(' ')}: ${child.error ?? ''} ${child.stderr}`);
  return child.stdout;
}
function check(name, f) {
  try { f(); checks++; }
  catch (error) { throw new Error(name, { cause: error }); }
}
function power(a, n) {
  let result = 1n;
  for (; n > 0n; n >>= 1n, a = mod(a * a)) if (n & 1n) result = mod(result * a);
  return result;
}

// Deliberately independent of the OCaml serializers and L1 pass.
function big(bytes) {
  let n = 0n;
  for (let i = bytes.length - 1; i >= 0; i--) n = n * 256n + BigInt(bytes[i]);
  return n;
}
function sections(bytes, magic, version, count) {
  assert.equal(bytes.subarray(0, 4).toString(), magic);
  assert.equal(bytes.readUInt32LE(4), version);
  assert.equal(bytes.readUInt32LE(8), count);
  const result = new Map();
  let offset = 12;
  for (let i = 0; i < count; i++) {
    const kind = bytes.readUInt32LE(offset);
    const size = Number(bytes.readBigUInt64LE(offset + 4));
    assert(!result.has(kind));
    offset += 12;
    assert(offset + size <= bytes.length);
    result.set(kind, bytes.subarray(offset, offset + size));
    offset += size;
  }
  assert.equal(offset, bytes.length);
  return result;
}
function parse(prefix) {
  const rs = sections(readFileSync(prefix + '.r1cs'), 'r1cs', 1, 3);
  const ws = sections(readFileSync(prefix + '.wtns'), 'wtns', 2, 2);
  const rh = rs.get(1), wh = ws.get(1);
  assert.equal(rh.length, 64);
  assert.equal(wh.length, 40);
  assert.equal(rh.readUInt32LE(0), 32);
  assert.equal(wh.readUInt32LE(0), 32);
  assert.equal(big(rh.subarray(4, 36)), p);
  assert.equal(big(wh.subarray(4, 36)), p);
  const n = rh.readUInt32LE(36), count = rh.readUInt32LE(60);
  assert.equal(wh.readUInt32LE(36), n);
  assert.equal(rh.readBigUInt64LE(52), BigInt(n));
  assert.equal(rs.get(3).length, n * 8);
  for (let i = 0; i < n; i++) assert.equal(rs.get(3).readBigUInt64LE(i * 8), BigInt(i));
  assert.equal(ws.get(2).length, n * 32);
  const values = Array.from({ length: n }, (_, i) => big(ws.get(2).subarray(i * 32, (i + 1) * 32)));
  values.forEach(v => assert(v < p));
  assert.equal(values[0], 1n);
  const bytes = rs.get(2);
  let offset = 0;
  function lc() {
    const size = bytes.readUInt32LE(offset); offset += 4;
    let previous = -1;
    return Array.from({ length: size }, () => {
      const wire = bytes.readUInt32LE(offset); offset += 4;
      assert(wire > previous && wire < n); previous = wire;
      const coefficient = big(bytes.subarray(offset, offset + 32)); offset += 32;
      assert(coefficient > 0n && coefficient < p);
      return [wire, coefficient];
    });
  }
  const constraints = Array.from({ length: count }, () => [lc(), lc(), lc()]);
  assert.equal(offset, bytes.length);
  return { values, constraints, n };
}
function satisfies({ constraints }, values) {
  const lc = terms => mod(terms.reduce((s, [w, c]) => s + c * values[w], 0n));
  return constraints.every(([a, b, c]) => mod(lc(a) * lc(b)) === lc(c));
}
function artifact(name, args, expectedOutput, count) {
  const prefix = join(work, name);
  run(probe, [...args, prefix]);
  const circuit = parse(prefix);
  assert.equal(circuit.constraints.length, count);
  assert.equal(circuit.values[1], expectedOutput);
  assert(satisfies(circuit, circuit.values));
  const wrong = [...circuit.values]; wrong[1] = mod(wrong[1] + 1n);
  assert(!satisfies(circuit, wrong), 'changed public output must fail');
  return { prefix, circuit };
}

try {
  check('field arithmetic against JS BigInt, 512 vectors', () => {
    const vectors = Array.from({ length: 512 }, (_, i) => {
      const scalar = suffix => BigInt('0x' + createHash('sha256').update(`taciturn:${i}:${suffix}`).digest('hex')) % p;
      return [scalar('a'), scalar('b')];
    });
    vectors.splice(0, 5, [0n, 0n], [0n, p - 1n], [1n, p - 1n], [p - 1n, p - 1n], [1n << 200n, 1n << 128n]);
    const path = join(work, 'fields.txt');
    writeFileSync(path, vectors.map(v => v.join(' ')).join('\n') + '\n');
    const results = run(probe, ['fields', path]).trim().split('\n');
    assert.equal(results.length, vectors.length);
    vectors.forEach(([a, b], i) => assert.deepEqual(results[i].split(' ').map(BigInt),
      [mod(a + b), mod(a - b), mod(a * b), a === 0n ? 0n : power(a, p - 2n)]));
  });

  for (const [x, y] of [[3n, 5n], [0n, 0n], [p - 1n, p - 2n]]) {
    for (const name of ['mul', 'mimc3']) check(`${name} spike byte identity ${x}`, () => {
      let output = mod(x * y);
      if (name === 'mimc3') {
        output = x;
        for (const c of [1n, 2n, 3n]) output = power(mod(output + y + c), 7n);
        output = mod(output + y);
      }
      const { prefix } = artifact(`${name}-${x}`, [name, String(x), String(y)], output, name === 'mul' ? 1 : 12);
      const old = prefix + '-spike';
      run(spike, [name, String(x), String(y), old]);
      for (const ext of ['.r1cs', '.wtns']) assert.deepEqual(readFileSync(prefix + ext), readFileSync(old + ext));
      assert.match(run(process.execPath, [reader, prefix + '.r1cs', prefix + '.wtns', name, String(x), String(y)]), /READER OK/);
    });
  }

  for (const x of [0n, 1n, 7n, p - 1n]) check(`inverse ${x}`, () => {
    const { circuit } = artifact(`inverse-${x}`, ['inv', String(x)], x === 0n ? 0n : power(x, p - 2n), 3);
    for (let i = 1; i < circuit.n; i++) {
      const wrong = [...circuit.values]; wrong[i] = mod(wrong[i] + 1n);
      assert(!satisfies(circuit, wrong), `inverse wire ${i} is constrained`);
    }
  });
  for (const [x, y] of [[0n, 0n], [7n, 7n], [0n, 1n], [p - 1n, 2n]]) check(`equality ${x} ${y}`, () => {
    const { circuit } = artifact(`eq-${x}-${y}`, ['eq', String(x), String(y)], x === y ? 1n : 0n, 3);
    const wrong = [...circuit.values]; wrong[1] = 2n;
    assert(!satisfies(circuit, wrong));
  });
  for (const bit of [0n, 1n]) check(`select ${bit}`, () => {
    const { prefix, circuit } = artifact(`select-${bit}`, ['select', String(bit), '8', '3'], bit === 1n ? 8n : 3n, 3);
    const other = join(work, `select-other-${bit}`);
    run(probe, ['select', String(1n - bit), '123', '456', other]);
    assert.deepEqual(readFileSync(prefix + '.r1cs'), readFileSync(other + '.r1cs'));
    assert.equal(circuit.n, 6);
    const wrong = [...circuit.values]; wrong[2] = 2n; wrong[1] = 13n; wrong[5] = 10n;
    assert(!satisfies(circuit, wrong), 'nonboolean interpolation must fail');
  });
  check('nonboolean select refuses before writing', () => {
    const prefix = join(work, 'invalid-select');
    run(probe, ['select', '2', '8', '3', prefix], 1);
    assert(!existsSync(prefix + '.r1cs') && !existsSync(prefix + '.wtns'));
  });
  check('repeated definition retains its residual equation', () => {
    const { circuit } = artifact('repeated', ['repeated'], 3n, 2);
    const wrong = [...circuit.values]; wrong[1] = 4n; wrong[2] = 4n;
    assert(!satisfies(circuit, wrong));
  });
  check('cyclic definitions lower without dropping the product', () => artifact('cycle', ['cycle'], 4n, 1));
  check('interface retained and unused internal pruned', () => {
    const { circuit } = artifact('interface', ['interface'], 9n, 1);
    assert.deepEqual(circuit.values, [1n, 9n, 9n, 42n]);
    const alternate = [...circuit.values]; alternate[3] = 17n;
    assert(satisfies(circuit, alternate));
  });
  check('probe refuses a prefix in a directory that does not exist', () => {
    const child = spawnSync(probe, ['mul', '6', '7', join(work, 'missing-dir', 'mul')], { encoding: 'utf8', timeout: 15000 });
    assert.equal(child.status, 1);
    assert.match(child.stderr, /^io:/);
  });
  check('probe refuses an unwritable prefix', () => {
    const locked = join(work, 'locked');
    mkdirSync(locked);
    chmodSync(locked, 0o500);
    const child = spawnSync(probe, ['mul', '6', '7', join(locked, 'mul')], { encoding: 'utf8', timeout: 15000 });
    chmodSync(locked, 0o700);
    assert.equal(child.status, 1);
    assert.match(child.stderr, /^io:/);
  });
  check('probe refuses a missing field vector file', () => {
    const child = spawnSync(probe, ['fields', join(work, 'no-such-vectors.txt')], { encoding: 'utf8', timeout: 15000 });
    assert.equal(child.status, 1);
    assert.match(child.stderr, /^io:/);
  });
  assert.equal(checks, expected, `check count changed: ${checks}`);
  console.log(`BACKEND-JS ${checks}/${expected}, 512 field vectors, 6 spike pairs`);
} finally {
  rmSync(work, { recursive: true, force: true });
}
