#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const batch = args[0] === '--batch';
const inputPath = args[batch ? 1 : 0];
const fail = message => { console.error(message); process.exit(2); };
if (!inputPath || args.length !== (batch ? 2 : 1)) fail('Usage: node scripts/cli.mjs [--batch] file.json');
let raw;
try { raw = readFileSync(inputPath, 'utf8'); } catch (e) { fail(`Cannot read input: ${e.message}`); }
// A file workflow avoids shell quoting and catches output failures. Core validates the schema.
const moon = process.env.MOON_BIN || (process.env.MOON_HOME ? join(process.env.MOON_HOME, 'bin', process.platform === 'win32' ? 'moon.exe' : 'moon') : 'moon');
let built = spawnSync(moon, ['build', '--target', 'js', '-j', '1'], { cwd: root, encoding: 'utf8', maxBuffer: 8_000_000 });
if (built.error || built.status !== 0) fail(built.error?.message || built.stderr || 'Build failed');
const core = await import(pathToFileURL(join(root, '_build/js/debug/build/bridge/bridge.js')).href);
const parsed = JSON.parse(batch ? core.batch(raw) : core.analyze(raw));
process.stdout.write(JSON.stringify(parsed, null, 2) + '\n');
if (!Array.isArray(parsed) && parsed.ok !== true) process.exitCode = 2;
