import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const assignment = JSON.parse(readFileSync(path.join(root, 'templates/dev-work/assignment.json'), 'utf8'));

// Load the production document validator verbatim, without unrelated Git/runtime checks.
const harness = String.raw`
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $env:SCHEMA_TEST_ROOT 'scripts/validate-run.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
foreach ($definition in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
  . ([scriptblock]::Create($definition.Extent.Text))
}
$script:schemaCache = @{}
$validationErrors = [Collections.ArrayList]::new()
Test-Document $env:SCHEMA_TEST_DOCUMENT $env:SCHEMA_TEST_SCHEMA 'assignments/schema-regression.json' $validationErrors
$standard = Test-Json -Json ([IO.File]::ReadAllText($env:SCHEMA_TEST_DOCUMENT)) -SchemaFile $env:SCHEMA_TEST_SCHEMA -ErrorAction SilentlyContinue
@{ valid = ($validationErrors.Count -eq 0); standard = $standard; errors = @($validationErrors) } | ConvertTo-Json -Depth 10 -Compress
`;

function validate(t, document, { raw = false, schema } = {}) {
  const temporaryRoot = mkdtempSync(path.join(tmpdir(), 'run-schema-validation-'));
  t.after(() => rmSync(temporaryRoot, { recursive: true, force: true }));
  const documentPath = path.join(temporaryRoot, 'assignment.json');
  writeFileSync(documentPath, raw ? document : JSON.stringify(document));
  let schemaPath = path.join(root, 'schemas/assignment.schema.json');
  if (schema !== undefined) {
    schemaPath = path.join(temporaryRoot, 'fixture.schema.json');
    writeFileSync(schemaPath, JSON.stringify(schema));
  }
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', harness], {
    encoding: 'utf8', timeout: 15000,
    env: { ...process.env, SCHEMA_TEST_ROOT: root, SCHEMA_TEST_DOCUMENT: documentPath, SCHEMA_TEST_SCHEMA: schemaPath },
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  return JSON.parse(result.stdout);
}

const cases = [
  ['empty arrays remain valid', (document) => {}, true],
  ['null cannot replace an array', (document) => { document.skills.required = null; }, false, /skills(?:\.|\/)required/],
  ['required property names are case sensitive', (document) => {
    document.skills.Required = document.skills.required;
    delete document.skills.required;
  }, false, /required/],
  ['additional property names are case sensitive', (document) => { document.skills.Required = []; }, false, /Required/],
  ['enum values are case sensitive', (document) => { document.status = 'PLANNED'; }, false, /status/],
  ['array item errors identify the element', (document) => { document.skills.required = ['valid', 42]; }, false, /skills(?:\.|\/)required(?:\[1\]|\/1|\.1)/],
  ['missing nested properties retain the existing diagnostic path', (document) => { delete document.artifacts.evidencePath; }, false, /artifacts\.evidencePath/],
];

for (const [name, mutate, expected, diagnostic] of cases) {
  test(name, (t) => {
    const document = structuredClone(assignment);
    mutate(document);
    const result = validate(t, document);
    assert.equal(result.standard, expected, 'standard schema result');
    assert.equal(result.valid, expected, JSON.stringify(result));
    if (diagnostic) {
      assert.match(result.errors.join('\n'), diagnostic);
      for (const error of result.errors) assert.match(error, /^assignments\/schema-regression\.json:/);
    }
  });
}

test('multiple errors preserve both field paths', (t) => {
  const document = structuredClone(assignment);
  document.skills.required = null;
  document.skills.conditional = [false];
  const result = validate(t, document);
  assert.equal(result.valid, false);
  assert.match(result.errors.join('\n'), /skills(?:\.|\/)required/);
  assert.match(result.errors.join('\n'), /skills(?:\.|\/)conditional(?:\[0\]|\/0|\.0)/);
});

test('schema-valid case-variant keys are rejected when state consumers cannot parse them', (t) => {
  const result = validate(t, { required: [], Required: [] }, {
    schema: { type: 'object', required: ['required', 'Required'], properties: { required: { type: 'array' }, Required: { type: 'array' } }, additionalProperties: false },
  });
  assert.equal(result.standard, true);
  assert.equal(result.valid, false, JSON.stringify(result));
  assert.match(result.errors.join('\n'), /assignments\/schema-regression\.json: validation failed/);
});

test('malformed JSON returns a labeled validation error', (t) => {
  const result = validate(t, '{"skills":', { raw: true });
  assert.equal(result.standard, false);
  assert.equal(result.valid, false);
  assert.match(result.errors.join('\n'), /assignments\/schema-regression\.json:/);
});

for (const duplicateRunKey of [false, true]) {
  test(`CLI rejects missing run state with case-variant run key=${duplicateRunKey}`, (t) => {
    const project = mkdtempSync(path.join(tmpdir(), 'run-schema-entry-'));
    t.after(() => rmSync(project, { recursive: true, force: true }));
    const initialized = spawnSync('git', ['init', '--template=', project], { encoding: 'utf8', timeout: 15000 });
    assert.ifError(initialized.error);
    assert.equal(initialized.status, 0, initialized.stdout + initialized.stderr);
    const devWork = path.join(project, '.dev-work');
    mkdirSync(devWork);
    writeFileSync(path.join(devWork, 'manifest.json'), readFileSync(path.join(root, 'templates/dev-work/manifest.json')));
    writeFileSync(path.join(devWork, 'coordinator-lock.json'), JSON.stringify({
      schemaVersion: 1, status: 'active', coordinatorControlBranch: 'control', coordinatorWorktree: project, startedAt: '2026-01-01',
    }));
    const activeRun = { schemaVersion: 1, run: 'missing-run', runDirectory: 'runs/missing-run', orcaRunId: null, updatedAt: '2026-01-01' };
    if (duplicateRunKey) activeRun.Run = 'other-run';
    writeFileSync(path.join(devWork, 'active-run.json'), JSON.stringify(activeRun));
    const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', path.join(root, 'scripts/validate-run.ps1'), '-ProjectRoot', project, '-SkipPackageChecks'], {
      encoding: 'utf8', timeout: 15000,
    });
    assert.ifError(result.error);
    assert.equal(result.status, 1, result.stdout + result.stderr);
    const report = JSON.parse(result.stdout);
    assert.equal(report.ok, false);
    assert.ok(report.errors.length > 0);
    assert.match(report.errors.join('\n'), duplicateRunKey ? /active-run:/ : /run-state: missing/);
  });
}

function validateWaveRun(t, waves) {
  const project = realpathSync.native(mkdtempSync(path.join(tmpdir(), 'dispatch-wave-entry-')));
  t.after(() => rmSync(project, { recursive: true, force: true }));
  const initialized = spawnSync('git', ['init', '--template=', project], { encoding: 'utf8', timeout: 15000 });
  assert.ifError(initialized.error);
  assert.equal(initialized.status, 0, initialized.stdout + initialized.stderr);
  const devWork = path.join(project, '.dev-work');
  const runDir = path.join(devWork, 'runs/wave-test');
  mkdirSync(runDir, { recursive: true });
  writeFileSync(path.join(devWork, 'manifest.json'), readFileSync(path.join(root, 'templates/dev-work/manifest.json')));
  writeFileSync(path.join(devWork, 'coordinator-lock.json'), JSON.stringify({
    schemaVersion: 1, status: 'active', coordinatorControlBranch: 'control', coordinatorWorktree: project, startedAt: '2026-01-01',
  }));
  writeFileSync(path.join(devWork, 'active-run.json'), JSON.stringify({
    schemaVersion: 1, run: 'wave-test', runDirectory: 'runs/wave-test', orcaRunId: null, updatedAt: '2026-01-01',
  }));
  const state = JSON.parse(readFileSync(path.join(root, 'templates/dev-work/run-state.json'), 'utf8'));
  Object.assign(state, { runSlug: 'wave-test', coordinatorWorktree: project, coordinatorControlBranch: 'control', deliveryBranch: 'main' });
  writeFileSync(path.join(runDir, 'run-state.json'), JSON.stringify(state));
  if (waves !== undefined) {
    mkdirSync(path.join(runDir, 'dispatch-waves'));
    for (const [name, content] of Object.entries(waves)) writeFileSync(path.join(runDir, 'dispatch-waves', name), content);
  }
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', path.join(root, 'scripts/validate-run.ps1'), '-ProjectRoot', project, '-SkipPackageChecks'], {
    encoding: 'utf8', timeout: 15000,
  });
  assert.ifError(result.error);
  const report = JSON.parse(result.stdout);
  assert.equal(result.status, report.ok ? 0 : 1, result.stdout + result.stderr);
  return report;
}

const wave = {
  waveId: 'wave-test', runSlug: 'wave-test', orcaRunId: 'run_test',
  waveStartedAt: '2026-01-01T00:00:00Z', waveRecordedAt: '2026-01-01T00:00:01Z', taskCount: 1,
  tasks: [{ taskKey: 'task-test', requestedModel: 'sonnet', requestedEffort: 'high',
    orcaTaskId: 'task_test', orcaDispatchId: 'ctx_test', startExit: 0, startState: 'ready',
    launchRequested: { agent: 'claude', model: 'sonnet', effort: 'high' },
    launchEffective: { agent: 'claude', model: 'sonnet', effort: 'high' }, recordedInLedger: true }],
  parallelWindowSeconds: 0, note: 'Recorded at dispatch time',
};

for (const [name, waves] of [
  ['absent directory', undefined], ['empty directory', {}],
  ['minimal core record', { 'minimal.json': JSON.stringify({
    waveId: wave.waveId, runSlug: wave.runSlug, orcaRunId: wave.orcaRunId,
    waveStartedAt: wave.waveStartedAt, waveRecordedAt: wave.waveRecordedAt,
    taskCount: 1, tasks: [{ taskKey: 'minimal' }],
  }) }],
  ['unknown receipt values and nested extensions', { 'unknown.json': JSON.stringify({
    ...wave, tasks: [{ ...wave.tasks[0], orcaTaskId: null, orcaDispatchId: null,
      requestedModel: null, requestedEffort: null, startExit: null, startState: null,
      launchRequested: null, launchEffective: { agent: null, model: null, effort: null, futureField: true },
      recordedInLedger: false, futureField: true }],
  }) }],
  ['multiple valid files and extension fields', {
    'first.json': JSON.stringify(wave),
    'second.json': JSON.stringify({ ...wave, waveId: 'wave-next', futureField: true }),
  }],
]) {
  test(`wave CLI accepts ${name}`, (t) => {
    const report = validateWaveRun(t, waves);
    assert.equal(report.ok, true, JSON.stringify(report));
  });
}

for (const [name, content, diagnostic] of [
  ['malformed JSON', '{', /dispatch-waves\/bad.json:/],
  ['missing core identity', JSON.stringify({ ...wave, waveId: undefined }), /waveId/],
  ['wrong tasks type', JSON.stringify({ ...wave, tasks: null }), /tasks/],
  ['missing task key', JSON.stringify({ ...wave, tasks: [{}] }), /taskKey/],
]) {
  test(`wave CLI rejects ${name} and names the file`, (t) => {
    const report = validateWaveRun(t, { 'good.json': JSON.stringify(wave), 'bad.json': content });
    assert.equal(report.ok, false, JSON.stringify(report));
    assert.match(report.errors.join('\n'), /dispatch-waves\/bad.json:/);
    assert.match(report.errors.join('\n'), diagnostic);
    assert.doesNotMatch(report.errors.join('\n'), /dispatch-waves\/good.json:/);
  });
}
