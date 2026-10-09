import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const script = path.join(root, 'skills', 'frontend-visual-design', 'scripts', 'contrast-ratio.mjs');

function run(args) {
  const result = spawnSync(process.execPath, [script, ...args], {
    cwd: root,
    encoding: 'utf8',
    env: { PATH: process.env.PATH, SystemRoot: process.env.SystemRoot },
    timeout: 15000,
  });
  assert.notEqual(result.status, null, result.error && result.error.message);
  return result;
}

function reportOf(result) {
  assert.equal(result.stderr, '', result.stderr);
  return JSON.parse(result.stdout);
}

test('black on white is 21:1 and meets both text and boundary thresholds', () => {
  const result = run(['--foreground', '#000000', '--background', '#ffffff']);
  assert.equal(result.status, 0, result.stderr);
  const report = reportOf(result);
  assert.equal(report.ratio, 21);
  assert.equal(report.meets.text, true);
  assert.equal(report.meets.boundary, true);
  assert.equal(report.threshold, null);
});

test('the same pair is symmetric and short hex expands to the same ratio', () => {
  const long = reportOf(run(['--foreground', '#ffffff', '--background', '#000']));
  assert.equal(long.ratio, 21);
  assert.equal(long.foreground, '#FFFFFF');
  assert.equal(long.background, '#000000');
});

test('a large-text pair meets 3:1 and fails ordinary 4.5:1 text', () => {
  const result = run(['--foreground', '#777777', '--background', '#FFFFFF']);
  assert.equal(result.status, 0, result.stderr);
  const report = reportOf(result);
  assert.ok(report.ratio > 4 && report.ratio < 4.5, `expected between 4 and 4.5, got ${report.ratio}`);
  assert.equal(report.meets.text, false);
  assert.equal(report.meets.boundary, true);
});

test('an accent that misses the requested text threshold exits nonzero and still reports the ratio', () => {
  const result = run(['--foreground', '#777777', '--background', '#FFFFFF', '--threshold', '4.5']);
  assert.notEqual(result.status, 0);
  const report = JSON.parse(result.stdout);
  assert.equal(report.meets.requested, false);
  assert.equal(report.threshold, 4.5);
  assert.ok(report.ratio < 4.5);
  assert.ok(report.ratio > 4.5 * 0.95, `expected near the 4.5 boundary, got ${report.ratio}`);
});

test('the same near-boundary accent passes when only the 3:1 boundary is requested', () => {
  const result = run(['--foreground', '#777777', '--background', '#FFFFFF', '--threshold', '3']);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout).meets.requested, true);
});

test('equal colors are 1:1 and fail every requested threshold', () => {
  const result = run(['--foreground', '#336699', '--background', '#336699', '--threshold', '3']);
  assert.notEqual(result.status, 0);
  const report = JSON.parse(result.stdout);
  assert.equal(report.ratio, 1);
  assert.equal(report.meets.text, false);
  assert.equal(report.meets.boundary, false);
  assert.equal(report.meets.requested, false);
});

test('malformed color, alpha, and an unknown threshold exit nonzero with no report', () => {
  for (const args of [
    ['--foreground', '#12', '--background', '#000000'],
    ['--foreground', '#00000080', '--background', '#ffffff'],
    ['--foreground', 'black', '--background', '#ffffff'],
    ['--foreground', '#000000', '--background', '#ffffff', '--threshold', '7'],
    ['--foreground', '#000000'],
  ]) {
    const result = run(args);
    assert.notEqual(result.status, 0, args.join(' '));
    assert.equal(result.stdout, '', args.join(' '));
    assert.match(result.stderr, /contrast-ratio:/);
  }
});

test('a fixture page states the same ratios the calculator reports', () => {
  const fixture = readFileSync(path.join(root, 'tests', 'fixtures', 'capability', 'design-browser-page.html'), 'utf8');
  assert.ok(fixture.length > 0);
  const pairs = [...fixture.matchAll(/data-contrast="(#[0-9a-fA-F]{6}) (#[0-9a-fA-F]{6}) ([0-9.]+)"/g)];
  assert.ok(pairs.length >= 2);
  for (const [, foreground, background, expected] of pairs) {
    const report = reportOf(run(['--foreground', foreground, '--background', background]));
    assert.equal(report.ratio, Number(expected));
  }
});

test('the sample spec keeps one passing journey and one deliberate failure, and records trace guidance', () => {
  const spec = readFileSync(path.join(root, 'skills', 'browser-e2e', 'scripts', 'sample.spec.mjs'), 'utf8');
  assert.match(spec, /saves a tide reading/);
  assert.match(spec, /refuses a blank tide time/);
  assert.match(spec, /trace/);
  assert.match(spec, /keyboard/);
});

test('the fixture server binds to loopback and serves the page', async () => {
  const child = spawn(process.execPath, [path.join(root, 'skills', 'browser-e2e', 'scripts', 'serve-fixture.mjs')], {
    cwd: root,
    env: { PATH: process.env.PATH, SystemRoot: process.env.SystemRoot },
    stdio: ['pipe', 'pipe', 'pipe'],
  });
  let output = '';
  child.stdout.on('data', (chunk) => { output += chunk; });
  try {
    const match = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`no loopback line: ${output}`)), 5000);
      child.stdout.on('data', () => {
        const found = /listening http:\/\/127\.0\.0\.1:(\d+)/.exec(output);
        if (found) { clearTimeout(timer); resolve(found); }
      });
      child.on('exit', (code) => reject(new Error(`server exited ${code}`)));
    });
    const response = await fetch(`http://127.0.0.1:${match[1]}/`);
    assert.equal(response.status, 200);
    assert.match(await response.text(), /Tide time is required\./);
  } finally {
    child.stdin.end();
    await new Promise((resolve) => child.on('exit', resolve));
  }
});
