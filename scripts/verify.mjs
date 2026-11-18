// Independent finite-state oracle: no DBM, shortest paths or closure implementation.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const moon = process.env.MOON_BIN || (process.env.MOON_HOME ? join(process.env.MOON_HOME, 'bin', process.platform === 'win32' ? 'moon.exe' : 'moon') : 'moon');
const receipt = { seed: 7331, systems: 0, queries: 0, transfers: 0, lattices: 0, conflicts: 0, backends: [], examples: [] };
function run(command, args) {
  const r = spawnSync(command, args, { cwd: root, encoding: 'utf8', maxBuffer: 20_000_000 });
  if (r.error || r.status !== 0) throw new Error(`${command} [${args.length} arguments]\n${r.error?.message || r.stderr || r.stdout}`);
  return r.stdout;
}
run(moon, ['build', '--target', 'js', '-j', '1']);
const entry = join(root, '_build/js/debug/build/cmd/main/main.js');
const core = await import(pathToFileURL(join(root, '_build/js/debug/build/bridge/bridge.js')).href);
function batch(requests) {
  const result = [];
  for (let i = 0; i < requests.length; i += 64) {
    const part = requests.slice(i, i + 64);
    const output = JSON.parse(core.batch(JSON.stringify(part)));
    assert.equal(output.length, part.length);
    for (const x of output) { assert.equal(x.ok, true, JSON.stringify(x)); result.push(x.result); }
  }
  return result;
}
const term = (variable, sign = 1) => ({ variable, sign });
const unary = (variable, sign, bound) => ({ left: term(variable, sign), bound });
const binary = (a, sa, b, sb, bound) => ({ left: term(a, sa), right: term(b, sb), bound });
const evalExpr = (p, c) => c.left.sign * p[c.left.variable] + (c.right ? c.right.sign * p[c.right.variable] : 0);
const satisfies = (p, cs) => cs.every(c => evalExpr(p, c) <= c.bound);
const box = (n, radius) => Array.from({ length: n }, (_, i) => [unary(i, 1, radius), unary(i, -1, radius)]).flat();
function points(n, r) {
  let out = [[]];
  for (let i = 0; i < n; i++) out = out.flatMap(p => Array.from({ length: r * 2 + 1 }, (_, j) => [...p, j - r]));
  return out;
}
function expressions(n) {
  const out = [];
  for (let i = 0; i < n; i++) for (const s of [-1, 1]) out.push(unary(i, s, 0));
  for (let i = 0; i < n; i++) for (let j = i; j < n; j++) for (const a of [-1, 1]) for (const b of [-1, 1]) out.push(binary(i, a, j, b, 0));
  return out;
}
function validateReport(report, expected, cs) {
  if (!expected.length) { assert.equal(report.state, 'empty'); return; }
  assert.equal(report.state, 'nonempty');
  const p = report.witness.map(Number);
  assert(p.every(Number.isSafeInteger));
  assert(satisfies(p, cs), `invalid witness ${JSON.stringify(p)}`);
  for (let i = 0; i < p.length; i++) {
    assert.equal(Number(report.intervals[i].lower), Math.min(...expected.map(v => v[i])));
    assert.equal(Number(report.intervals[i].upper), Math.max(...expected.map(v => v[i])));
  }
}
let seed = receipt.seed;
const random = n => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed % n; };
const systems = [];
for (const n of [2, 3]) {
  const expr = expressions(n);
  for (let k = 0; k < 320; k++) {
    const cs = box(n, 3);
    for (let j = 0; j < 1 + k % 9; j++) cs.push({ ...expr[random(expr.length)], bound: random(13) - 6 });
    const concrete = points(n, 3).filter(p => satisfies(p, cs));
    const queries = expr.map((c, i) => ({ ...c, bound: (i % 7) - 3 }));
    systems.push({ n, cs, concrete, queries });
  }
}
const answers = batch(systems.map(x => ({ op: 'analyze', dimensions: x.n, constraints: x.cs, queries: x.queries })));
answers.forEach((out, idx) => {
  const { n, cs, concrete, queries } = systems[idx];
  validateReport(out.domain, concrete, cs);
  out.queries.forEach((q, i) => {
    receipt.queries++;
    if (!concrete.length) { assert.equal(q.verdict, 'vacuous'); return; }
    const maximum = Math.max(...concrete.map(p => evalExpr(p, queries[i]))) || 0;
    assert.equal(Number(q.bound), maximum, `tight bound system ${idx} query ${i}`);
    assert.equal(q.verdict, maximum <= queries[i].bound ? 'proven' : 'refuted');
    if (q.verdict === 'refuted') {
      const p = q.countermodel.map(Number);
      assert(satisfies(p, cs));
      assert(evalExpr(p, queries[i]) > queries[i].bound);
    }
  });
  receipt.systems++;
});

// Exhaust every unordered pair from 28 signed two-variable guards.
const pool = [];
for (const a of [-1, 1]) for (const b of [-1, 1]) for (let bound = -3; bound <= 3; bound++) pool.push(binary(0, a, 1, b, bound));
const exhaustive = [];
for (let a = 0; a < pool.length; a++) for (let b = 0; b <= a; b++) {
  const cs = [...box(2, 3), pool[a], pool[b]];
  exhaustive.push({ cs, concrete: points(2, 3).filter(p => satisfies(p, cs)) });
}
const exhaustiveAnswers = batch(exhaustive.map(x => ({ op: 'analyze', dimensions: 2, constraints: x.cs, queries: expressions(2) })));
exhaustiveAnswers.forEach((out, i) => {
  const x = exhaustive[i];
  validateReport(out.domain, x.concrete, x.cs);
  out.queries.forEach((q, j) => {
    receipt.queries++;
    if (x.concrete.length) assert.equal(Number(q.bound), Math.max(...x.concrete.map(p => evalExpr(p, expressions(2)[j]))) || 0);
    else assert.equal(q.verdict, 'vacuous');
  });
  receipt.systems++;
});

// Exact signed-copy transfer images; brute-force the pre-state then apply assignments.
const transferCases = [];
for (const x of systems.filter(x => x.concrete.length).slice(0, 160)) {
  for (const sign of [-1, 1]) {
    const target = random(x.n), source = random(x.n), offset = random(5) - 2;
    const image = x.concrete.map(p => p.map((v, i) => i === target ? sign * p[source] + offset : v));
    transferCases.push({ ...x, target, source, sign, offset, image });
  }
}
const transferAnswers = batch(transferCases.map(x => ({ op: 'transfer', dimensions: x.n, constraints: x.cs, transfers: [{ op: 'assign', target: x.target, source: term(x.source, x.sign), offset: x.offset }] })));
transferAnswers.forEach((r, i) => {
  const x = transferCases[i];
  const p = r.witness.map(Number);
  assert(x.image.some(v => v.every((a, j) => a === p[j])));
  for (let j = 0; j < x.n; j++) {
    assert.equal(Number(r.intervals[j].lower), Math.min(...x.image.map(v => v[j])));
    assert.equal(Number(r.intervals[j].upper), Math.max(...x.image.map(v => v[j])));
  }
  receipt.transfers++;
});

// Join extrema equal extrema of the union; meet equals concrete intersection.
const latticeCases = [];
for (let i = 0; i < 160; i++) {
  const a = systems[i], b = systems[(i + 29) % 320];
  for (const op of ['join', 'meet']) latticeCases.push({ a, b, op });
}
const latticeAnswers = batch(latticeCases.map(({ a, b, op }) => ({ op, dimensions: a.n, constraints: a.cs, other: b.cs })));
latticeAnswers.forEach((r, i) => {
  const { a, b, op } = latticeCases[i];
  const expected = op === 'join' ? [...a.concrete, ...b.concrete] : a.concrete.filter(p => satisfies(p, b.cs));
  if (op === 'meet') validateReport(r, expected, [...a.cs, ...b.cs]);
  else if (!expected.length) assert.equal(r.state, 'empty');
  else for (let j = 0; j < a.n; j++) {
    assert.equal(Number(r.intervals[j].lower), Math.min(...expected.map(v => v[j])));
    assert.equal(Number(r.intervals[j].upper), Math.max(...expected.map(v => v[j])));
  }
  receipt.lattices++;
});

// Conflict subsets independently enumerated in a bounded universe. Keeping all
// the original box bounds during each deletion makes this a decisive check.
const emptyCases = systems.filter(x => !x.concrete.length).slice(0, 64);
const conflicts = batch(emptyCases.map(x => ({ op: 'conflict', dimensions: x.n, constraints: x.cs })));
conflicts.forEach((out, i) => {
  const x = emptyCases[i], ids = out.conflict.indices;
  assert.equal(out.verified, true);
  assert.equal(new Set(ids).size, ids.length);
  const chosen = ids.map(k => x.cs[k]);
  // No chosen conjunction can have a solution inside the original finite box.
  assert(!points(x.n, 3).some(p => satisfies(p, chosen)));
  receipt.conflicts++;
});

const errors = [
  { op: 'analyze', dimensions: 1.5, constraints: [] },
  { op: 'analyze', dimensions: 1, constraints: [], ignored: true },
  { op: 'analyze', dimensions: 1, constraints: [unary(1, 1, 0)] },
  { op: 'loop', dimensions: 1, constraints: [], guard: [], body: [], max_iterations: 0 },
];
const errorAnswers = JSON.parse(core.batch(JSON.stringify(errors)));
assert(errorAnswers.every(x => x.ok === false));
for (const file of ['configuration.json', 'sensors.json', 'loop.json', 'parity-conflict.json']) {
  const request = readFileSync(join(root, 'examples', file), 'utf8');
  const out = JSON.parse(core.analyze(request));
  assert.equal(out.ok, true);
  receipt.examples.push({ file, output: out });
}

// Re-run the same behavior suite on every installed non-native runtime.
// Native is checked separately because its compiler is supplied by the host.
for (const target of ['js', 'wasm-gc', 'wasm']) {
  const test = run(moon, ['test', '--target', target, '--deny-warn', '-j', '1']);
  run(moon, ['build', '--target', target, '-j', '1']);
  const example = run(moon, ['run', 'examples/relations', '--target', target, '-j', '1']);
  receipt.backends.push({ target, tests: test.trim(), example });
}
const sample = { op: 'analyze', dimensions: 2, constraints: box(2, 3), queries: expressions(2) };
const jsOutput = run(process.execPath, [entry, JSON.stringify(sample)]).trim();
for (const target of ['wasm-gc', 'wasm']) {
  const output = run(moon, ['run', 'cmd/main', '--target', target, '-j', '1', '--', JSON.stringify(sample)]).trim();
  assert.deepEqual(JSON.parse(output), JSON.parse(jsOutput), `CLI parity: ${target}`);
}
mkdirSync(join(root, '_build', 'reports'), { recursive: true });
writeFileSync(join(root, '_build/reports/independent-oracle.json'), JSON.stringify(receipt, null, 2) + '\n');
console.log(JSON.stringify({ ...receipt, backends: receipt.backends.map(x => ({ target: x.target, tests: x.tests })), examples: receipt.examples.map(x => x.file) }, null, 2));
