import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, readdirSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const readJson = (file) => JSON.parse(readFileSync(file, 'utf8'));
function writeJson(file, value) {
  mkdirSync(path.dirname(file), { recursive: true });
  writeFileSync(file, JSON.stringify(value));
}
function fixture(t) {
  const project = realpathSync.native(mkdtempSync(path.join(tmpdir(), 'state-scripts-')));
  t.after(() => rmSync(project, { recursive: true, force: true }));
  const result = spawnSync('git', ['init', '--template=', '-b', 'control', '-q'], { cwd: project, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  const devWork = path.join(project, '.dev-work');
  writeJson(path.join(devWork, 'manifest.json'), { schemaVersion: 1 });
  writeJson(path.join(devWork, 'coordinator-lock.json'), { activeRun: 'previous-run', coordinatorTerminalHandle: 'term_holder' });
  writeJson(path.join(devWork, 'active-run.json'), { run: 'previous-run', runDirectory: 'runs/previous-run' });
  const runDir = path.join(devWork, 'runs/previous-run');
  writeJson(path.join(runDir, 'run-state.json'), { preserved: 'previous state' });
  return { project, devWork, runDir };
}
function runScript(script, project, args = [], terminal = '') {
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', path.join(root, 'scripts', script), '-ProjectRoot', project, ...args], {
    cwd: project, encoding: 'utf8', timeout: 30000, env: { ...process.env, ORCA_TERMINAL_HANDLE: terminal },
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  return result.stdout.replace(/\x1b\[[0-9;]*m/g, '');
}
function createRun(project, slug, terminal = '') {
  return runScript('create-run.ps1', project, ['-Objective', 'State regression', '-DeliveryBranch', 'main', '-RunSlug', slug, '-Force'], terminal);
}

for (const [name, placement, expected] of [['relative artifact', 'devWork', true], ['cwd impostor', 'project', false], ['rooted artifact', 'absolute', true]]) {
  test(`reconcile resolves ${name} independently of cwd`, (t) => {
    const { project, devWork, runDir } = fixture(t);
    const file = path.join(placement === 'devWork' ? devWork : project, 'report.txt');
    writeFileSync(file, 'artifact');
    const artifactPath = placement === 'absolute' ? file : 'report.txt';
    writeJson(path.join(runDir, 'assignments/task.json'), {
      taskKey: 'task', status: 'completed', branch: {}, orca: {}, artifacts: { reportPath: artifactPath, evidencePath: artifactPath },
    });
    const row = JSON.parse(runScript('reconcile-state.ps1', project)).assignments[0];
    assert.equal(row.reportExists, expected);
    assert.equal(row.evidenceExists, expected);
  });
}

test('forced different slug archives the old pointer and names the displaced run', (t) => {
  const { project, devWork, runDir } = fixture(t);
  const previous = readFileSync(path.join(devWork, 'active-run.json'), 'utf8');
  const output = createRun(project, 'next-run');
  assert.match(output, /previous-run/);
  const archives = readdirSync(path.join(devWork, 'archive')).filter((name) => name.startsWith('active-run-'));
  assert.equal(archives.length, 1);
  assert.equal(readFileSync(path.join(devWork, 'archive', archives[0]), 'utf8'), previous);
  assert.equal(readJson(path.join(devWork, 'active-run.json')).run, 'next-run');
  assert.deepEqual(readJson(path.join(runDir, 'run-state.json')), { preserved: 'previous state' });
});

test('forced same slug retains archived state and existing artifacts', (t) => {
  const { project, runDir } = fixture(t);
  writeFileSync(path.join(runDir, 'report.txt'), 'keep');
  const output = createRun(project, 'previous-run');
  assert.match(output, /Reusing run 'previous-run'/);
  const archive = readdirSync(path.join(runDir, 'archive')).find((name) => name.startsWith('run-state.'));
  assert.deepEqual(readJson(path.join(runDir, 'archive', archive)), { preserved: 'previous state' });
  assert.equal(readFileSync(path.join(runDir, 'report.txt'), 'utf8'), 'keep');
});

for (const terminal of ['term_other', 'term_holder', '']) {
  test(`lock ownership warning with caller ${terminal || 'headless'}`, (t) => {
    const { project, devWork } = fixture(t);
    const output = createRun(project, 'previous-run', terminal);
    if (terminal === 'term_other') assert.match(output, /term_holder.*term_other/);
    else assert.doesNotMatch(output, /term_holder/);
    assert.equal(readJson(path.join(devWork, 'coordinator-lock.json')).activeRun, 'previous-run');
  });
}

test('assignment template uses runtime placeholders and a real fallback heading', () => {
  const file = path.join(root, 'templates/dev-work/assignment.json');
  const text = readFileSync(file, 'utf8');
  const assignment = JSON.parse(text);
  assert.doesNotMatch(text, /§4\.4/);
  assert.equal(assignment.runtime.verification.status, '<status>');
  assert.match(assignment.runtime.verification.evidence, /<evidence>/);
  assert.match(assignment.runtime.verification.evidence, /references\/failure-taxonomy\.md#access-and-configuration/);
  assert.equal(assignment.fallbackReason, null);
});
