import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, linkSync, mkdtempSync, mkdirSync, readFileSync, readdirSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const script = path.join(root, 'scripts/dispatch-task.ps1');
const orcaRunId = 'run_fixture1234567890';
const normalized = (value) => value.replace(/\\/g, '/').replace(/\/+$/, '');

function writeJson(file, value) {
  writeFileSync(file, JSON.stringify(value, null, 2));
}

function readJson(file) {
  return JSON.parse(readFileSync(file, 'utf8'));
}

// PowerShell renders thrown messages with ANSI colors and hard line wraps; flatten both before
// matching so an assertion does not depend on the console width of the day.
function clean(text) {
  return text
    .replace(/\x1b\[[0-9;]*m/g, '')
    .replace(/\r?\n\s*\|\s*/g, ' ')
    .replace(/\s+/g, ' ');
}

function parseOutput(result) {
  return JSON.parse(result.stdout.trim());
}

function createProject(t) {
  // Canonicalize so the recorded worktree (short vs long temp name) matches git's own spelling.
  const project = realpathSync.native(mkdtempSync(path.join(tmpdir(), 'dispatch-task-')));
  t.after(() => rmSync(project, { recursive: true, force: true }));
  const git = (args) => {
    const result = spawnSync('git', args, { cwd: project, encoding: 'utf8', timeout: 15000 });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stdout + result.stderr);
  };
  git(['init', '--template=', '-b', 'main', '-q']);
  git(['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.com', '-c', 'commit.gpgsign=false', 'commit', '--allow-empty', '-q', '-m', 'init']);

  const devWork = path.join(project, '.dev-work');
  const runDir = path.join(devWork, 'runs', 'fixture-run');
  mkdirSync(path.join(runDir, 'assignments'), { recursive: true });
  mkdirSync(path.join(runDir, 'evidence'), { recursive: true });
  writeJson(path.join(devWork, 'manifest.json'), {
    schemaVersion: 1, managedBy: 'orca-project-delivery', createdAt: '2026-01-01T00:00:00Z', projectRoot: project,
  });
  writeJson(path.join(devWork, 'coordinator-lock.json'), {
    schemaVersion: 1, status: 'active', coordinatorControlBranch: 'control', coordinatorWorktree: project,
    startedAt: '2026-01-01T00:00:00Z', updatedAt: '2026-01-01T00:00:00Z', activeRun: 'fixture-run',
  });
  writeJson(path.join(devWork, 'active-run.json'), {
    schemaVersion: 1, run: 'fixture-run', runDirectory: 'runs/fixture-run', orcaRunId, updatedAt: '2026-01-01T00:00:00Z',
  });
  writeJson(path.join(runDir, 'run-state.json'), {
    schemaVersion: 1, runSlug: 'fixture-run', objective: 'dispatch fixture', workflow: 'feature-development',
    status: 'active', stage: 'task-graph', deliveryBranch: 'main', deliveryBranchSource: 'user',
    coordinatorControlBranch: 'control', coordinatorWorktree: project, orcaRunId,
    completedStages: ['intake'], pendingUserDecisions: [],
    createdAt: '2026-01-01T00:00:00Z', updatedAt: '2026-01-01T00:00:00Z',
  });
  writeJson(path.join(runDir, 'task-map.json'), { schemaVersion: 1, tasks: {} });
  writeJson(path.join(runDir, 'branch-map.json'), { schemaVersion: 1, branches: {} });
  return { project, runDir, devWork };
}

function writeInputs(t, project, mutate = {}) {
  const worktree = mutate.worktree ?? path.join(path.dirname(project), 'fixture-worktree');
  const definition = {
    schemaVersion: 1,
    taskKey: 'fixture-task',
    title: 'Fixture task',
    objective: 'Exercise dispatch accounting',
    role: 'software-implementer',
    skills: { required: ['test-driven-development'], conditional: [] },
    skillDeliveryMode: 'explicit-path',
    branch: { delivery: 'main', base: 'main', work: 'fixture/task', mergeTarget: 'main', worktree },
    artifacts: { reportPath: path.join(project, 'worker-report.md'), evidencePath: '' },
    ...mutate.definition,
  };
  const receipt = {
    id: '11111111-2222-3333-4444-555555555555',
    ok: true,
    result: {
      runId: orcaRunId,
      taskId: mutate.taskId ?? 'task_abcdef123456',
      dispatchId: mutate.dispatchId ?? 'ctx_abcdef123456',
      state: 'ready',
      stage: 'input_accepted',
      turnStart: 'observed',
      launch: {
        requested: { agent: 'codex' },
        effective: mutate.effective ?? { agent: 'codex' },
      },
      mode: { mode: 'terminal', preferred: 'terminal', reason: 'user_default', detail: 'Started a terminal agent worker.' },
      timeoutMs: 60000,
      effects: mutate.effects ?? [
        { kind: 'worktree', action: 'created_top_level', id: `topology-id::${normalized(worktree)}` },
        { kind: 'terminal', role: 'agent', action: 'created', id: 'term_fixture', surface: 'visible' },
      ],
      residualResources: [],
      mutation: { requestId: '22222222-3333-4444-5555-666666666666', replayed: false },
    },
    _meta: { runtimeId: '33333333-4444-5555-6666-777777777777' },
  };
  const inputs = path.join(project, 'inputs');
  mkdirSync(inputs, { recursive: true });
  const definitionPath = path.join(inputs, `${mutate.taskKeyName ?? 'fixture-task'}.json`);
  const briefPath = path.join(inputs, 'fixture-task.md');
  const receiptPath = path.join(inputs, 'receipt.json');
  writeJson(definitionPath, definition);
  writeJson(receiptPath, receipt);
  writeFileSync(briefPath, '# Worker brief\n');
  t.after(() => rmSync(inputs, { recursive: true, force: true }));
  return { definitionPath, briefPath, receiptPath, worktree };
}

function runDispatch(project, paths, args = []) {
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', script,
    '-ProjectRoot', project, '-TaskDefinitionPath', paths.definitionPath,
    '-BriefPath', paths.briefPath, '-ReceiptPath', paths.receiptPath, ...args], {
    encoding: 'utf8', timeout: 60000,
  });
  assert.ifError(result.error);
  return result;
}

test('records the resolved brief path and refreshes it on redispatch', (t) => {
  const { project, runDir } = createProject(t);
  const paths = writeInputs(t, project);
  for (const brief of [Buffer.from('﻿# Brief 中文\r\n'), Buffer.from('# Edited brief\n')]) {
    writeFileSync(paths.briefPath, brief);
    const result = runDispatch(project, paths);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    const output = parseOutput(result);
    const assignment = readJson(path.join(runDir, 'assignments', 'fixture-task.json'));
    assert.equal(assignment.artifacts.briefPath, paths.briefPath);
    assert.equal(assignment.artifacts.briefSha256, undefined);
    assert.equal(output.briefPath, paths.briefPath);
    assert.equal(output.briefSha256, undefined);
  }
});

for (const [name, launch, status, note] of [
  ['explicit-null', { requested: null, effective: null }, 'unverified', /agent identity/],
  ['object-of-nulls', { requested: { agent: null, model: null, effort: null }, effective: { agent: null, model: null, effort: null } }, 'unverified', /agent identity/],
  ['missing', undefined, 'unverified', /no launch.requested\/effective block/],
  ['missing fields', { requested: {}, effective: {} }, 'unverified', /agent identity/],
  ['agent defaults', { requested: { agent: 'codex' }, effective: { agent: 'codex' } }, 'verified', /matches/],
  ['reported defaults', { requested: { agent: 'codex' }, effective: { agent: 'codex', model: 'native-model', effort: 'native-effort' } }, 'verified', /matches/],
  ['unknown default internals', { requested: { agent: 'opencode', model: null, effort: null }, effective: { agent: 'opencode', model: null, effort: null } }, 'verified', /matches/],
  ['model pin unknown', { requested: { agent: 'codex', model: 'pinned-model' }, effective: { agent: 'codex' } }, 'unverified', /not reported.*model/],
  ['effort pin unknown', { requested: { agent: 'codex', effort: 'high' }, effective: { agent: 'codex', model: 'native-model' } }, 'unverified', /not reported.*effort/],
  ['model pin honored', { requested: { agent: 'codex', model: 'pinned-model' }, effective: { agent: 'codex', model: 'pinned-model', effort: 'native-effort' } }, 'verified', /matches/],
  ['effort pin honored', { requested: { agent: 'codex', effort: 'high' }, effective: { agent: 'codex', model: 'native-model', effort: 'high' } }, 'verified', /matches/],
  ['agent mismatch', { requested: { agent: 'codex' }, effective: { agent: 'claude' } }, 'mismatch', /differs/],
  ['model pin mismatch', { requested: { agent: 'codex', model: 'pinned-model' }, effective: { agent: 'codex', model: 'other-model' } }, 'mismatch', /differs/],
  ['equal', { requested: { agent: 'claude', model: 'sonnet', effort: 'high' }, effective: { agent: 'claude', model: 'sonnet', effort: 'high' } }, 'verified', /matches/],
  ['mismatch', { requested: { agent: 'claude', model: 'sonnet', effort: 'high' }, effective: { agent: 'claude', model: 'haiku', effort: null } }, 'mismatch', /differs/],
  ['alias-fallback', { requested: { agent: 'claude', model: 'haiku', effort: null }, effective: { agent: 'claude', model: 'haiku', effort: null } }, 'verified', /matches/],
]) {
  test(`launch comparator ${name} records ${status}`, (t) => {
    const { project, runDir } = createProject(t);
    const paths = writeInputs(t, project);
    const receipt = readJson(paths.receiptPath);
    receipt.result.launch = launch;
    writeJson(paths.receiptPath, receipt);
    const result = runDispatch(project, paths);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.equal(parseOutput(result).runtimeVerification, status);
    const assignment = readJson(path.join(runDir, 'assignments', 'fixture-task.json'));
    assert.equal(assignment.runtime.verification.status, status);
    assert.match(assignment.runtime.verification.evidence, note);
    for (const profile of ['requested', 'effective']) {
      for (const field of ['agent', 'model', 'effort']) {
        assert.equal(assignment.runtime[profile][field], launch?.[profile]?.[field] ?? null);
      }
    }
    if (status === 'verified') assert.deepEqual(parseOutput(result).warnings, []);
    if (status === 'unverified') assert.equal(assignment.fallbackReason, null);
  });
}

test('records a successful dispatch receipt as the run record', (t) => {
  const { project, runDir } = createProject(t);
  const paths = writeInputs(t, project);
  const result = runDispatch(project, paths, []);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  const output = parseOutput(result);
  assert.equal(output.ok, true);
  assert.equal(output.runtimeVerification, 'verified');
  assert.equal(output.stage, 'task-graph');
  assert.deepEqual(output.warnings, []);

  const assignmentPath = path.join(runDir, 'assignments', 'fixture-task.json');
  const bytes = readFileSync(assignmentPath);
  assert.notEqual(bytes[0], 0xef, 'assignment must not start with a UTF-8 BOM');
  const assignment = JSON.parse(bytes.toString('utf8'));
  assert.equal(assignment.taskKey, 'fixture-task');
  assert.equal(assignment.role, 'software-implementer');
  assert.deepEqual(assignment.skills, { required: ['test-driven-development'], conditional: [] });
  assert.deepEqual(assignment.orca, { runId: orcaRunId, taskId: 'task_abcdef123456', dispatchId: 'ctx_abcdef123456' });
  assert.equal(assignment.status, 'active');
  assert.equal(assignment.runtime.verification.status, 'verified');
  assert.deepEqual(assignment.runtime.requested, { agent: 'codex', model: null, effort: null });
  assert.deepEqual(assignment.runtime.effective, { agent: 'codex', model: null, effort: null });
  assert.equal(assignment.runtime.mode.mode, 'terminal');
  assert.equal(assignment.runtime.surface, 'visible');
  assert.equal(assignment.runtime.terminalHandle, 'term_fixture');
  assert.equal(assignment.branch.worktree, normalized(paths.worktree));
  assert.equal(assignment.evidence, undefined);
  assert.equal(assignment.fallbackReason, null);
  assert.equal(assignment.runtime.previousDispatches, undefined);

  const taskMap = readJson(path.join(runDir, 'task-map.json'));
  assert.deepEqual(Object.keys(taskMap.tasks), ['fixture-task']);
  assert.deepEqual(taskMap.tasks['fixture-task'], { taskId: 'task_abcdef123456', assignment: 'assignments/fixture-task.json' });

  const branchMap = readJson(path.join(runDir, 'branch-map.json'));
  assert.deepEqual(branchMap.branches['fixture-task'], {
    branch: 'fixture/task', base: 'main', mergeTarget: 'main', worktree: normalized(paths.worktree),
  });

  const state = readJson(path.join(runDir, 'run-state.json'));
  assert.equal(state.stage, 'task-graph');
  assert.notEqual(state.updatedAt, '2026-01-01T00:00:00Z');
  const lock = readJson(path.join(project, '.dev-work', 'coordinator-lock.json'));
  assert.notEqual(lock.updatedAt, '2026-01-01T00:00:00Z');
});

for (const [name, taskKind, mergeTarget, patterns] of [
  ['source null target', 'source', null, [/taskKind/, /mergeTarget/]],
  ['default source null target', undefined, null, [/taskKind/, /mergeTarget/]],
  ['source empty target', 'source', '', [/taskKind/, /mergeTarget/]],
  ['read-only source target', 'read-only', 'main', [/taskKind/, /mergeTarget/]],
]) {
  test(`rejects ${name} without writing the run records`, (t) => {
    const { project, runDir, devWork } = createProject(t);
    const paths = writeInputs(t, project);
    const definition = readJson(paths.definitionPath);
    Object.assign(definition, { taskKind });
    definition.branch.mergeTarget = mergeTarget;
    writeJson(paths.definitionPath, definition);
    const statePaths = [path.join(runDir, 'task-map.json'), path.join(runDir, 'branch-map.json'), path.join(runDir, 'run-state.json'), path.join(devWork, 'coordinator-lock.json')];
    const before = statePaths.map((file) => readFileSync(file, 'utf8'));
    const result = runDispatch(project, paths);
    assert.equal(result.status, 1, result.stdout + result.stderr);
    for (const pattern of patterns) assert.match(clean(result.stdout + result.stderr), pattern);
    assert.equal(existsSync(path.join(runDir, 'assignments', 'fixture-task.json')), false);
    assert.deepEqual(statePaths.map((file) => readFileSync(file, 'utf8')), before);
  });
}

test('refuses placements the run contract does not allow', (t) => {
  const { project, runDir } = createProject(t);
  const assignmentPath = path.join(runDir, 'assignments', 'refused-task.json');
  const cases = [
    {
      name: 'control worktree',
      mutate: { taskKeyName: 'refused-task', effects: [
        { kind: 'worktree', action: 'reused', id: `topology-id::${normalized(project)}` },
        { kind: 'terminal', role: 'agent', action: 'created', id: 'term_fixture', surface: 'visible' },
      ] },
      pattern: /coordinator control worktree/,
    },
    {
      name: 'worktree contradicting the definition',
      mutate: { taskKeyName: 'refused-task', worktree: path.join(path.dirname(project), 'expected-worktree'), effects: [
        { kind: 'worktree', action: 'created_top_level', id: `topology-id::${normalized(path.join(path.dirname(project), 'other-worktree'))}` },
        { kind: 'terminal', role: 'agent', action: 'created', id: 'term_fixture', surface: 'visible' },
      ] },
      pattern: /does not match the task definition worktree/,
    },
    {
      name: 'no worktree effect',
      mutate: { taskKeyName: 'refused-task', effects: [
        { kind: 'terminal', role: 'agent', action: 'created', id: 'term_fixture', surface: 'visible' },
      ] },
      pattern: /no worktree effect/,
    },
  ];
  for (const item of cases) {
    const paths = writeInputs(t, project, { ...item.mutate, definition: { taskKey: 'refused-task' } });
    const result = runDispatch(project, paths);
    assert.equal(result.status, 1, `${item.name}: ${result.stdout}${result.stderr}`);
    assert.match(clean(result.stdout + result.stderr), item.pattern, item.name);
    assert.equal(existsSync(assignmentPath), false, `${item.name}: nothing may be written`);
  }
});

test('refuses a second live dispatch until it is forced, then keeps the history', (t) => {
  const { project, runDir } = createProject(t);
  const first = writeInputs(t, project);
  assert.equal(runDispatch(project, first).status, 0);

  const second = writeInputs(t, project, {
    dispatchId: 'ctx_second123456',
    effective: { agent: 'claude', model: 'haiku', effort: null },
  });
  const refused = runDispatch(project, second);
  assert.equal(refused.status, 1, refused.stdout + refused.stderr);
  assert.match(clean(refused.stdout + refused.stderr), /already has a live dispatch/);

  const forced = runDispatch(project, second, ['-ForceReDispatch']);
  assert.equal(forced.status, 0, forced.stdout + forced.stderr);
  const output = parseOutput(forced);
  assert.equal(output.runtimeVerification, 'mismatch');
  assert.ok(output.warnings.some((warning) => /differs from the request/.test(warning)), forced.stdout);

  const assignment = readJson(path.join(runDir, 'assignments', 'fixture-task.json'));
  assert.equal(assignment.orca.dispatchId, 'ctx_second123456');
  assert.equal(assignment.runtime.verification.status, 'mismatch');
  assert.match(assignment.fallbackReason, /launch\.effective differs from launch\.requested/);
  assert.equal(assignment.runtime.previousDispatches.length, 1);
  assert.equal(assignment.runtime.previousDispatches[0].dispatchId, 'ctx_abcdef123456');
  assert.equal(assignment.runtime.previousDispatches[0].status, 'active');
});

test('rejects an unknown status and incomplete inputs without writing anything', (t) => {
  const { project, runDir } = createProject(t);
  const assignmentPath = path.join(runDir, 'assignments', 'fixture-task.json');

  const badStatus = writeInputs(t, project);
  const statusResult = runDispatch(project, badStatus, ['-Status', 'dispatched']);
  assert.equal(statusResult.status, 1, statusResult.stdout + statusResult.stderr);
  assert.match(clean(statusResult.stderr), /ValidateSet|dispatched/);

  const incomplete = writeInputs(t, project, { definition: { artifacts: undefined } });
  const definition = readJson(incomplete.definitionPath);
  delete definition.artifacts;
  writeJson(incomplete.definitionPath, definition);
  const incompleteResult = runDispatch(project, incomplete);
  assert.equal(incompleteResult.status, 1, incompleteResult.stdout + incompleteResult.stderr);
  assert.match(clean(incompleteResult.stderr), /artifacts/);

  const missingBrief = writeInputs(t, project);
  rmSync(missingBrief.briefPath);
  const briefResult = runDispatch(project, missingBrief);
  assert.equal(briefResult.status, 1, briefResult.stdout + briefResult.stderr);
  assert.match(clean(briefResult.stderr), /assemble-task\.ps1/);

  assert.equal(existsSync(assignmentPath), false);
});

test('warns about task-map drift and keeps unfamiliar top-level keys intact', (t) => {
  const { project, runDir } = createProject(t);
  writeJson(path.join(runDir, 'task-map.json'), {
    schemaVersion: 1, tasks: {}, 'release-metadata': { taskId: 'task_stray000000', status: 'dispatched' },
  });
  const paths = writeInputs(t, project);
  const result = runDispatch(project, paths);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  const output = parseOutput(result);
  assert.ok(output.warnings.some((warning) => /outside 'tasks'/.test(warning)), result.stdout);
  const taskMap = readJson(path.join(runDir, 'task-map.json'));
  assert.equal(taskMap['release-metadata'].taskId, 'task_stray000000');
  assert.equal(taskMap.tasks['fixture-task'].taskId, 'task_abcdef123456');
});

test('all five state files are replaced without modifying their previous file objects', (t) => {
  const { project, runDir, devWork } = createProject(t);
  const paths = writeInputs(t, project);
  assert.equal(runDispatch(project, paths).status, 0);
  const files = [path.join(runDir, 'assignments', 'fixture-task.json'),
    ...['task-map.json', 'branch-map.json', 'run-state.json'].map((name) => path.join(runDir, name)),
    path.join(devWork, 'coordinator-lock.json')];
  const snapshots = files.map((file) => {
    const value = readJson(file);
    value.atomicWriteProbe = true;
    writeJson(file, value);
    const alias = file + '.previous';
    linkSync(file, alias);
    return { alias, bytes: readFileSync(alias) };
  });
  const second = writeInputs(t, project, { dispatchId: 'ctx_second123456' });
  const result = runDispatch(project, second, ['-ForceReDispatch']);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  for (const { alias, bytes } of snapshots) assert.deepEqual(readFileSync(alias), bytes);
  for (const file of files) assert.doesNotThrow(() => readJson(file));
});

test('an interrupted state write exits non-zero and leaves every written file valid JSON', (t) => {
  const { project, runDir, devWork } = createProject(t);
  const paths = writeInputs(t, project);
  const stateBefore = readFileSync(path.join(runDir, 'run-state.json'), 'utf8');
  const lockBefore = readFileSync(path.join(devWork, 'coordinator-lock.json'), 'utf8');
  const harness = String.raw`
$ErrorActionPreference = 'Stop'
$lines = [IO.File]::ReadAllLines($env:DISPATCH_SCRIPT)
$line = 1 + [Array]::FindIndex($lines, [Predicate[string]] { param($text) $text -match '^Write-(Atomic)?JsonFile -Path \$assignmentPath' })
$null = Set-PSBreakpoint -Script $env:DISPATCH_SCRIPT -Line $line -Action {
  Remove-Item -LiteralPath $env:COLLISION_PATH
  $null = New-Item -ItemType Directory -Path $env:COLLISION_PATH
}
& $env:DISPATCH_SCRIPT -ProjectRoot $env:FIXTURE_PROJECT -TaskDefinitionPath $env:DEFINITION_PATH -BriefPath $env:BRIEF_PATH -ReceiptPath $env:RECEIPT_PATH
`;
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', harness], {
    encoding: 'utf8', timeout: 60000,
    env: { ...process.env, DISPATCH_SCRIPT: script, COLLISION_PATH: path.join(runDir, 'branch-map.json'),
      FIXTURE_PROJECT: project, DEFINITION_PATH: paths.definitionPath, BRIEF_PATH: paths.briefPath, RECEIPT_PATH: paths.receiptPath },
  });
  assert.ifError(result.error);
  assert.notEqual(result.status, 0, result.stdout + result.stderr);
  assert.match(clean(result.stdout + result.stderr), /Atomic write failed for/);
  assert.match(clean(result.stdout + result.stderr), /branch-map/);
  assert.equal(readJson(path.join(runDir, 'assignments', 'fixture-task.json')).orca.dispatchId, 'ctx_abcdef123456');
  assert.equal(readJson(path.join(runDir, 'task-map.json')).tasks['fixture-task'].taskId, 'task_abcdef123456');
  assert.equal(readFileSync(path.join(runDir, 'run-state.json'), 'utf8'), stateBefore);
  assert.equal(readFileSync(path.join(devWork, 'coordinator-lock.json'), 'utf8'), lockBefore);
  for (const directory of [runDir, path.join(runDir, 'assignments'), devWork]) {
    assert.ok(readdirSync(directory).every((entry) => !/\.tmp\.[0-9a-f]{32}$/.test(entry)));
  }
});
