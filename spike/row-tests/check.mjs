import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const executable = resolve(process.argv[2]);
const run = (...args) => spawnSync(executable, args, { encoding: 'utf8' });
const suite = run();
assert.equal(suite.status, 0, `${suite.error ?? ''}${suite.stdout}${suite.stderr}`);
process.stdout.write(suite.stdout);

const directory = mkdtempSync(join(tmpdir(), 'taciturn-row-validation-'));
try {
  for (const scenario of ['missing', 'lookup']) {
    const prefix = join(directory, scenario);
    const rejected = run(scenario, prefix);
    assert.equal(rejected.status, 1, `${rejected.stdout}${rejected.stderr}`);
    assert.match(rejected.stderr, /^ROWS-FAIL reason=/);
    assert.equal(rejected.stdout, '');
    assert.deepEqual(readdirSync(directory), []);
    for (const extension of ['r1cs', 'wtns']) {
      writeFileSync(`${prefix}.${extension}`, 'existing artifact');
    }
    const existing = run(scenario, prefix);
    assert.equal(existing.status, 1, `${existing.stdout}${existing.stderr}`);
    assert.match(existing.stderr, /^ROWS-FAIL reason=/);
    for (const extension of ['r1cs', 'wtns']) {
      assert.equal(readFileSync(`${prefix}.${extension}`, 'utf8'), 'existing artifact');
      rmSync(`${prefix}.${extension}`);
    }
  }
  process.stdout.write('ROW-EMIT OK missing and lookup refuse before file writes\n');
} finally {
  rmSync(directory, { recursive: true, force: true });
}
