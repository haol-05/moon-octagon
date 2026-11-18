#!/usr/bin/env node
// File and stdin entry point for the MoonBit bridge. Reads one JSON request,
// imports the compiled JS bridge and prints the result.
// Exit codes: 0 success, 2 request/response error, 64 usage, 1 build/internal.
import { readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const usage = `Usage: node scripts/cli.mjs [--batch] [file.json|-] [--out FILE]

Reads a JSON request from a file or from stdin ("-"), runs the MoonBit bridge
and writes the result to stdout or to --out. Exit codes: 0 success, 2 request
error, 64 usage, 1 build or internal failure.`;
const args = process.argv.slice(2);
if (args.includes('--help') || args.includes('-h')) {
  console.log(usage);
  process.exit(0);
}
const fail = (message, code = 1) => {
  console.error(message);
  process.exit(code);
};
let batch = false;
let out = null;
let inputPath = null;
for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg === '--batch') {
    batch = true;
  } else if (arg === '--out') {
    out = args[++i];
    if (!out) fail(`--out needs a path\n\n${usage}`, 64);
  } else if (arg.startsWith('-') && arg !== '-') {
    fail(`Unknown option: ${arg}\n\n${usage}`, 64);
  } else if (inputPath !== null) {
    fail(`Unexpected argument: ${arg}\n\n${usage}`, 64);
  } else {
    inputPath = arg;
  }
}
if (inputPath === null) fail(`Missing input\n\n${usage}`, 64);
let raw;
try {
  raw = inputPath === '-' ? readFileSync(0, 'utf8') : readFileSync(inputPath, 'utf8');
} catch (e) {
  fail(`Cannot read input: ${e.message}`);
}
const moon = process.env.MOON_BIN || (process.env.MOON_HOME ? join(process.env.MOON_HOME, 'bin', process.platform === 'win32' ? 'moon.exe' : 'moon') : 'moon');
const built = spawnSync(moon, ['build', '--target', 'js', '-j', '1'], { cwd: root, encoding: 'utf8', maxBuffer: 8_000_000 });
if (built.error || built.status !== 0) fail(built.error?.message || built.stderr || 'Build failed');
const core = await import(pathToFileURL(join(root, '_build/js/debug/build/bridge/bridge.js')).href);
let parsed;
try {
  parsed = JSON.parse(batch ? core.batch(raw) : core.analyze(raw));
} catch (e) {
  fail(`Bridge returned invalid JSON: ${e.message}`);
}
const text = JSON.stringify(parsed, null, 2) + '\n';
if (out) {
  try {
    writeFileSync(out, text);
  } catch (e) {
    fail(`Cannot write output: ${e.message}`);
  }
} else {
  process.stdout.write(text);
}
if (!Array.isArray(parsed) && parsed.ok !== true) process.exitCode = 2;
