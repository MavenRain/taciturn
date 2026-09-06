import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const bytes = readFileSync(join(here, 'gclink.wasm'));
const mod = await WebAssembly.compile(bytes);

const p = 2n ** 61n - 1n;

const modPow = (base, exp, mod) => {
  const bits = exp.toString(2).split('');
  return bits.reduce((r, bit) => {
    const sq = (r * r) % mod;
    return bit === '1' ? (sq * base) % mod : sq;
  }, 1n);
};

const inverse = (a) => modPow(((a % p) + p) % p, p - 2n, p);

const lines = [];
const push = (...parts) => {
  lines.push(parts.map((v) => (typeof v === 'bigint' ? `${v}n` : `${v}`)).join(' '));
};

push('imports:', JSON.stringify(WebAssembly.Module.imports(mod)));

const native = {
  zk: {
    mul: (a, b) => (a * b) % p,
    assert_one: (y) => y,
  },
  pre: {
    inv: (a) => inverse(a),
  },
};
const i1 = await WebAssembly.instantiate(mod, native);
const nativeOut = i1.exports.run(6n);
push('native run(6) =', nativeOut);

let rows = 0;
let preCalls = 0;
let preRows = 0;
const symbolic = {
  zk: {
    mul: (_a, _b) => {
      rows += 1;
      return BigInt(rows);
    },
    assert_one: (y) => {
      rows += 1;
      return y;
    },
  },
  pre: {
    inv: (a) => {
      preCalls += 1;
      return inverse(a);
    },
  },
};
const i2 = await WebAssembly.instantiate(mod, symbolic);
const symbolicOut = i2.exports.run(6n);
push(
  'symbolic run(6) =', symbolicOut,
  'rows =', rows,
  'pre_calls =', preCalls,
  'pre_rows =', preRows,
);

// pre: {} keeps the namespace key present but empty. node's V8 throws
// TypeError, not LinkError, when the whole module key is absent from the
// import object; an empty namespace with no inv function raises LinkError,
// which is the behaviour section 3.4 requires.
const missing = {
  zk: {
    mul: (a, b) => (a * b) % p,
    assert_one: (y) => y,
  },
  pre: {},
};
let linkErrored = false;
try {
  await WebAssembly.instantiate(mod, missing);
} catch (e) {
  linkErrored = e instanceof WebAssembly.LinkError;
}
push('missing-pre LinkError =', linkErrored);

lines.forEach((l) => console.log(l));

const checks = [
  /^imports: \[.*"zk".*"mul".*"zk".*"assert_one".*"pre".*"inv".*\]$/.test(lines[0]),
  /^native run\(6\) = 1n$/.test(lines[1]),
  /^symbolic run\(6\) = \d+n rows = 2 pre_calls = 1 pre_rows = 0$/.test(lines[2]),
  lines[3] === 'missing-pre LinkError = true',
];

process.exit(checks.every(Boolean) ? 0 : 1);
