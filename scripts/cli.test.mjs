import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const cli = join(root, 'scripts', 'cli.mjs');
const request = '{"op":"analyze","dimensions":1,"constraints":[]}';

function run(args, input) {
  return spawnSync(process.execPath, [cli, ...args], {
    cwd: root,
    encoding: 'utf8',
    input,
    maxBuffer: 8_000_000,
  });
}

test('reads a request from stdin', () => {
  const r = run(['-'], request);
  assert.equal(r.status, 0, r.stderr);
  const out = JSON.parse(r.stdout);
  assert.equal(out.ok, true);
  assert.equal(out.result.domain.state, 'nonempty');
});

test('batch stdin keeps per-item success', () => {
  const r = run(['--batch', '-'], `[${request},{"op":"missing","dimensions":1,"constraints":[]}]`);
  assert.equal(r.status, 0, r.stderr);
  const out = JSON.parse(r.stdout);
  assert.equal(out.length, 2);
  assert.equal(out[0].ok, true);
  assert.equal(out[1].ok, false);
});

test('writes to --out and reports request errors with exit code 2', () => {
  const dir = mkdtempSync(join(tmpdir(), 'octagon-cli-'));
  const file = join(dir, 'out.json');
  const ok = run(['examples/configuration.json', '--out', file]);
  assert.equal(ok.status, 0, ok.stderr);
  assert.equal(ok.stdout, '');
  assert.equal(JSON.parse(readFileSync(file, 'utf8')).ok, true);
  const bad = run(['-', '--out', file], '{"op":"analyze","dimensions":0,"constraints":[]}');
  assert.equal(bad.status, 2, bad.stderr);
  assert.equal(JSON.parse(readFileSync(file, 'utf8')).ok, false);
  rmSync(dir, { recursive: true, force: true });
});

test('rejects usage errors with exit code 64', () => {
  assert.equal(run(['--bogus'], '').status, 64);
  assert.equal(run([], '').status, 64);
});
