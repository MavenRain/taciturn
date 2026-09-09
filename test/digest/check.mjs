// Independent byte specification and SHA-256 oracle using Node BigInt.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const probe = path.resolve(process.argv[2]);
const prime = 21888242871839275222246405745257275088548364400416034343698204186575808495617n;
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const uint = (value, bytes) => {
  let n = BigInt(value);
  const out = Buffer.alloc(bytes);
  for (let i = 0; i < bytes; i++) { out[i] = Number(n & 255n); n >>= 8n; }
  assert.equal(n, 0n);
  return out;
};
const field = n => uint((BigInt(n) % prime + prime) % prime, 32);
const frame = s => Buffer.concat([uint(Buffer.byteLength(s), 8), Buffer.from(s)]);
const row = (selectors, a, b, c) => Buffer.concat([
  ...selectors.map(field), ...[a, b, c, 0].map(n => uint(n, 4)),
]);
const multiply = (a, b, c) => row([0, 0, -1, 1, 0], a, b, c);
const linear = (a, b, c, constant, right = 1) => row([1, right, -1, 0, constant], a, b, c);
const expected = kind => {
  const rows = [];
  let wires = 4;
  if (kind === 'mul') rows.push(multiply(2, 3, 1));
  else if (kind === 'mimc3') {
    let x = 3;
    for (const constant of [1, 2, 3]) {
      const t = wires++, t2 = wires++, t4 = wires++, t6 = wires++, t7 = wires++;
      rows.push(linear(x, 2, t, constant), multiply(t, t, t2),
        multiply(t2, t2, t4), multiply(t4, t2, t6), multiply(t6, t, t7));
      x = t7;
    }
    rows.push(linear(1, 2, x, 0, -1));
  }
  else if (kind === 'inverse') {
    wires = 5;
    rows.push(row([0, 0, 1, 1, -1], 2, 3, 4), row([0, 0, 0, 1, 0], 2, 4, 0),
      row([0, 0, 0, 1, 0], 4, 3, 0), linear(1, 0, 3, 0, 0));
  }
  else if (kind === 'equality') {
    wires = 7;
    rows.push(linear(2, 3, 4, 0, -1), row([0, 0, 1, 1, -1], 4, 5, 6),
      row([0, 0, 0, 1, 0], 4, 6, 0), row([0, 0, 0, 1, 0], 6, 5, 0),
      linear(1, 0, 6, 0, 0));
  }
  else {
    wires = 8;
    rows.push(row([-1, 0, 0, 1, 0], 2, 2, 0), linear(3, 4, 5, 0, -1),
      multiply(2, 5, 6), linear(6, 4, 7, 0, 1), linear(1, 0, 7, 0, 0));
  }
  const counts = { mul: [1, 0, 2], mimc3: [1, 1, 1], inverse: [1, 0, 1],
    equality: [1, 0, 2], select: [1, 0, 3] }[kind];
  return Buffer.concat([
    Buffer.from('taciturn-circuit\0'), uint(1, 4), frame('sha256'),
    frame('plonk-rows-bn254-v1'), uint(prime, 32), frame('taciturn-test-v1'),
    frame('zk'), Buffer.from('0'.repeat(64)), frame('sym'), Buffer.from('1'.repeat(64)),
    frame('pre'), Buffer.from('2'.repeat(64)), uint(3, 8),
    frame('Bit'), uint(1, 4), frame('Field'), uint(1, 4), frame('Unit'), uint(0, 4),
    ...[...counts, wires].map(n => uint(n, 4)), uint(rows.length, 8), ...rows,
  ]);
};
const run = (mode, kind, x, y, env = process.env) => {
  const result = spawnSync(probe, [mode, kind, String(x), String(y)], {
    env, timeout: 15000, maxBuffer: 1024 * 1024,
  });
  assert.ifError(result.error);
  return result;
};
let checks = 0;
const check = (name, fn) => {
  try { fn(); checks++; }
  catch (error) { console.error(`DIGEST-JS FAIL ${name}`); throw error; }
};
for (const kind of ['mul', 'mimc3']) {
  const bytes = expected(kind);
  for (const [x, y] of [[0n, 0n], [3n, 5n], [prime - 1n, prime - 2n]]) {
    check(`${kind}-encoding-${x}`, () => {
      const actual = run('preimage', kind, x, y);
      assert.equal(actual.status, 0, actual.stderr.toString());
      assert.deepEqual(actual.stdout, bytes);
    });
    check(`${kind}-hash-${x}`, () => {
      const actual = run('hash', kind, x, y);
      assert.equal(actual.status, 0, actual.stderr.toString());
      assert.equal(actual.stdout.toString(), `${sha(bytes)}\n`);
    });
  }
}
for (const [kind, x, y] of [['inverse', 3n, 5n], ['equality', 3n, 5n], ['select', 1n, 5n]]) {
  const bytes = expected(kind);
  check(`${kind}-encoding-${x}`, () => {
    const actual = run('preimage', kind, x, y);
    assert.equal(actual.status, 0, actual.stderr.toString());
    assert.deepEqual(actual.stdout, bytes);
  });
  check(`${kind}-hash-${x}`, () => {
    const actual = run('hash', kind, x, y);
    assert.equal(actual.status, 0, actual.stderr.toString());
    assert.equal(actual.stdout.toString(), `${sha(bytes)}\n`);
  });
}
const temporary = mkdtempSync(path.join(tmpdir(), 'taciturn-digest-test-'));
try {
  for (const name of ['ordinary', 'space and $(touch injected)', 'newline\nand\\slash']) {
    const directory = path.join(temporary, name);
    mkdirSync(directory);
    check(`temporary-${JSON.stringify(name)}`, () => {
      const actual = run('hash', 'mul', 3, 5, { ...process.env, TMPDIR: directory });
      assert.equal(actual.status, 0, actual.stderr.toString());
      assert.equal(actual.stdout.toString(), `${sha(expected('mul'))}\n`);
      assert.deepEqual(readdirSync(directory), []);
    });
  }
  check('temporary-missing', () => {
    const actual = run('hash', 'mul', 3, 5, { ...process.env, TMPDIR: path.join(temporary, 'missing') });
    assert.equal(actual.status, 1);
    assert.equal(actual.stdout.length, 0);
    assert.match(actual.stderr.toString(), /^digest-io:/);
  });
  check('absolute-hash-program', () => {
    const directory = path.join(temporary, 'path');
    mkdirSync(directory);
    writeFileSync(path.join(directory, 'shasum'), '#!/bin/sh\nexit 99\n', { mode: 0o755 });
    const actual = run('hash', 'mul', 3, 5, { ...process.env, PATH: directory });
    assert.equal(actual.status, 0, actual.stderr.toString());
    assert.equal(actual.stdout.toString(), `${sha(expected('mul'))}\n`);
  });
  check('perl-module-path', () => {
    const directory = path.join(temporary, 'perl');
    mkdirSync(path.join(directory, 'Digest'), { recursive: true });
    writeFileSync(path.join(directory, 'Digest', 'SHA.pm'),
      "package Digest::SHA;\nuse strict;\nuse Exporter;\nour @ISA = ('Exporter');\nour @EXPORT_OK = ('$errmsg');\nour $errmsg = '';\nsub new { return bless {}, shift }\nsub addfile { return $_[0] }\nsub hexdigest { return '0' x 64 }\n1;\n");
    const actual = run('hash', 'mul', 3, 5, { ...process.env, PERL5LIB: directory });
    assert.equal(actual.status, 0, actual.stderr.toString());
    assert.equal(actual.stdout.toString(), `${sha(expected('mul'))}\n`);
  });
} finally { rmSync(temporary, { recursive: true, force: true }); }
const total = 24;
assert.equal(checks, total, `check count changed: ${checks}`);
console.log(`DIGEST-JS ${checks}/${total}`);
