import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, mkdirSync, readdirSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const bootstrapScript = path.join(root, 'scripts/bootstrap-project.ps1');
const releaseScript = path.join(root, 'scripts/release-coordinator.ps1');

// The real CLI answer for a handle that no longer exists (observed on the installed orca):
// exit 1 with JSON {"ok":false,"error":{"code":"terminal_handle_stale",...}}.
const stubLive = '@echo off\r\necho {"ok":true,"result":{}}\r\nexit /b 0\r\n';
const stubNotFound = '@echo off\r\necho {"id":"x","ok":false,"error":{"code":"terminal_handle_stale","message":"terminal_handle_stale"},"_meta":{"runtimeId":"r"}}\r\nexit /b 1\r\n';
const stubTransient = '@echo off\r\nexit /b 1\r\n';
const stubGarbage = '@echo off\r\necho not-json-at-all\r\nexit /b 0\r\n';

const systemPath = 'C:\\Windows\\System32;C:\\Windows';

const wherePwsh = spawnSync('where', ['pwsh'], { encoding: 'utf8' });
assert.equal(wherePwsh.status, 0, 'pwsh must be on PATH to run this suite');
const pwshPath = wherePwsh.stdout.trim().split(/\r?\n/)[0];

// The bootstrap and release scripts shell out to git; a sanitized PATH must still carry it.
const whereGit = spawnSync('where', ['git'], { encoding: 'utf8' });
assert.equal(whereGit.status, 0, 'git must be on PATH to run this suite');
const gitDir = path.dirname(whereGit.stdout.trim().split(/\r?\n/)[0]);

function clean(text) {
  return text
    .replace(/\x1b\[[0-9;]*m/g, '')
    .replace(/\r?\n\s*\|\s*/g, ' ')
    .replace(/\s+/g, ' ');
}

function parseOutput(result) {
  // Write-Warning can precede the JSON payload on stdout; skip to the first object.
  const start = result.stdout.indexOf('{');
  assert.notEqual(start, -1, 'expected a JSON object in stdout');
  return JSON.parse(result.stdout.slice(start));
}

function writeOrcaStub(t, body) {
  const stubDir = mkdtempSync(path.join(tmpdir(), 'orca-stub-'));
  t.after(() => rmSync(stubDir, { recursive: true, force: true }));
  writeFileSync(path.join(stubDir, 'orca.cmd'), body);
  return stubDir;
}

function envWithPath(...dirs) {
  return { ...process.env, PATH: [...dirs, gitDir, systemPath].join(path.delimiter) };
}

function createProject(t) {
  const project = realpathSync.native(mkdtempSync(path.join(tmpdir(), 'coordinator-lock-')));
  t.after(() => rmSync(project, { recursive: true, force: true }));
  const git = (args) => {
    const result = spawnSync('git', args, { cwd: project, encoding: 'utf8', timeout: 15000 });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stdout + result.stderr);
  };
  git(['init', '--template=', '-b', 'control', '-q']);
  git(['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.com', '-c', 'commit.gpgsign=false', 'commit', '--allow-empty', '-q', '-m', 'init']);
  return { project, devWork: path.join(project, '.dev-work') };
}

function writeLock(devWork, fields) {
  mkdirSync(devWork, { recursive: true });
  writeFileSync(path.join(devWork, 'coordinator-lock.json'), JSON.stringify({
    schemaVersion: 1, status: 'active', coordinatorTerminalHandle: 'term_fixture_live',
    coordinatorControlBranch: 'control', coordinatorWorktree: devWork,
    startedAt: '2026-01-01T00:00:00Z', updatedAt: '2026-01-01T00:00:00Z', activeRun: 'fixture-run',
    ...fields,
  }, null, 2));
}

// Include Git metadata so refusal also protects info/exclude.
function snapshotTree(rootDir) {
  const entries = {};
  const walk = (dir) => {
    for (const item of readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const full = path.join(dir, item.name);
      const rel = path.relative(rootDir, full).replace(/\\/g, '/');
      if (item.isDirectory()) {
        entries[rel] = 'dir';
        walk(full);
      } else {
        entries[rel] = readFileSync(full).toString('base64');
      }
    }
  };
  if (existsSync(rootDir)) walk(rootDir);
  return entries;
}

function runBootstrap(project, env) {
  return spawnSync(pwshPath, ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', bootstrapScript,
    '-ProjectRoot', project, '-DeliveryBranch', 'main'], { encoding: 'utf8', timeout: 120000, env });
}

function runRelease(project, env) {
  return spawnSync(pwshPath, ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', releaseScript,
    '-ProjectRoot', project, '-ConfirmRunClosed', '-Reason', 'fixture release'], { encoding: 'utf8', timeout: 120000, env });
}

function readJson(file) {
  return JSON.parse(readFileSync(file, 'utf8'));
}

test('liveness live: bootstrap refuses takeover while the holder answers ok', (t) => {
  const { project, devWork } = createProject(t);
  writeLock(devWork);
  const before = snapshotTree(project);
  const result = runBootstrap(project, envWithPath(writeOrcaStub(t, stubLive)));
  assert.notEqual(result.status, 0, 'bootstrap must refuse a live holder');
  assert.match(clean(result.stdout + result.stderr), /live coordinator is bound/);
  assert.deepEqual(snapshotTree(project), before);
});

test('liveness dead: bootstrap takes over on a positive not-found response', (t) => {
  const { project, devWork } = createProject(t);
  writeLock(devWork);
  const result = runBootstrap(project, envWithPath(writeOrcaStub(t, stubNotFound)));
  assert.equal(result.status, 0, result.stdout + result.stderr);
  const output = parseOutput(result);
  assert.equal(output.lockLiveness, 'dead');
  assert.equal(readJson(path.join(devWork, 'coordinator-lock.json')).status, 'active');
  assert.match(clean(result.stdout), /holder terminal is gone/);
});

test('liveness unknown: bootstrap refuses on a transient probe failure', (t) => {
  const { project, devWork } = createProject(t);
  writeLock(devWork);
  const before = snapshotTree(project);
  const result = runBootstrap(project, envWithPath(writeOrcaStub(t, stubTransient)));
  assert.notEqual(result.status, 0, 'a failed probe proves nothing and must refuse');
  assert.match(clean(result.stdout + result.stderr), /liveness is unverifiable/);
  assert.deepEqual(snapshotTree(project), before);
});

test('liveness unknown: bootstrap refuses when orca is absent from PATH', (t) => {
  const { project, devWork } = createProject(t);
  writeLock(devWork);
  const before = snapshotTree(project);
  const result = runBootstrap(project, envWithPath());
  assert.notEqual(result.status, 0);
  assert.match(clean(result.stdout + result.stderr), /liveness is unverifiable/);
  assert.deepEqual(snapshotTree(project), before);
});

test('liveness unknown: bootstrap refuses on unparsable probe output', (t) => {
  const { project, devWork } = createProject(t);
  writeLock(devWork);
  const result = runBootstrap(project, envWithPath(writeOrcaStub(t, stubGarbage)));
  assert.notEqual(result.status, 0);
  assert.match(clean(result.stdout + result.stderr), /liveness is unverifiable/);
});

test('F6: a refused bootstrap leaves the project tree byte-identical', (t) => {
  const { project, devWork } = createProject(t);
  writeLock(devWork);
  const before = snapshotTree(project);
  const result = runBootstrap(project, envWithPath(writeOrcaStub(t, stubLive)));
  assert.notEqual(result.status, 0);
  assert.deepEqual(snapshotTree(project), before);
});

test('F9: bootstrap over a released lock warns with the previousActiveRun name', (t) => {
  const { project, devWork } = createProject(t);
  writeLock(devWork, {
    status: 'released',
    releasedAt: '2026-01-02T00:00:00Z',
    releaseReason: 'run closed',
    previousActiveRun: 'previous-run',
    activeRun: null,
  });
  const result = runBootstrap(project, envWithPath(writeOrcaStub(t, stubLive)));
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(clean(result.stdout), /previousActiveRun=previous-run/);
  assert.equal(readJson(path.join(devWork, 'coordinator-lock.json')).status, 'active');
});

for (const [label, body] of [
  ['service error', '@echo off\r\necho {"ok":false,"error":{"code":"unavailable"}}\r\nexit /b 1\r\n'],
  ['nonzero ok response', '@echo off\r\necho {"ok":true}\r\nexit /b 1\r\n'],
  ['empty success', '@echo off\r\nexit /b 0\r\n'],
]) {
  test(`liveness unknown: ${label} refuses without changing any files`, (t) => {
    const { project, devWork } = createProject(t);
    writeLock(devWork);
    const before = snapshotTree(project);
    const result = runBootstrap(project, envWithPath(writeOrcaStub(t, body)));
    assert.notEqual(result.status, 0);
    assert.match(clean(result.stdout + result.stderr), /liveness is unverifiable/);
    assert.deepEqual(snapshotTree(project), before);
  });
}

for (const initial of ['absent', 'released']) {
  test(`concurrent bootstrap from ${initial} lock has exactly one winner`, async (t) => {
    const { project, devWork } = createProject(t);
    if (initial === 'released') writeLock(devWork, { status: 'released' });
    const env = { ...envWithPath(writeOrcaStub(t, stubLive)), ORCA_TERMINAL_HANDLE: 'term_winner' };
    const launch = () => new Promise((resolve, reject) => {
      const child = spawn(pwshPath, ['-NoProfile', '-NonInteractive', '-File', bootstrapScript,
        '-ProjectRoot', project, '-DeliveryBranch', 'main'], { env });
      let output = '';
      child.stdout.on('data', (data) => { output += data; });
      child.stderr.on('data', (data) => { output += data; });
      child.on('error', reject);
      child.on('close', (status) => resolve({ status, output }));
    });
    const results = await Promise.all([launch(), launch()]);
    assert.equal(results.filter((result) => result.status === 0).length, 1, JSON.stringify(results));
    assert.equal(readJson(path.join(devWork, 'coordinator-lock.json')).coordinatorTerminalHandle, 'term_winner');
  });
}

test('F9: release clears activeRun and keeps previousActiveRun', (t) => {
  const { project, devWork } = createProject(t);
  mkdirSync(devWork, { recursive: true });
  writeFileSync(path.join(devWork, 'manifest.json'), JSON.stringify({
    schemaVersion: 1, managedBy: 'orca-project-delivery', createdAt: '2026-01-01T00:00:00Z', projectRoot: project,
  }));
  writeLock(devWork);
  writeFileSync(path.join(devWork, 'active-run.json'), JSON.stringify({
    schemaVersion: 1, run: 'release-run', runDirectory: 'runs/release-run', orcaRunId: 'run_fixture', updatedAt: '2026-01-01T00:00:00Z',
  }));
  const result = runRelease(project, envWithPath());
  assert.equal(result.status, 0, result.stdout + result.stderr);
  const lock = readJson(path.join(devWork, 'coordinator-lock.json'));
  assert.equal(lock.status, 'released');
  assert.equal(lock.activeRun, null);
  assert.equal(lock.previousActiveRun, 'release-run');
  assert.ok(!existsSync(path.join(devWork, 'active-run.json')));
});
