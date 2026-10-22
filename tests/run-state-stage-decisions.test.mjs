import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, realpathSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const template = JSON.parse(readFileSync(path.join(root, 'templates/dev-work/run-state.json'), 'utf8'));
const decision = { verdict: 'required', reason: 'Public interface changes', evidence: 'reconnaissance/scout.md', decidedAt: '2026-10-11T00:00:00Z', decidedBy: 'coordinator' };
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
$schema = Join-Path $env:SCHEMA_TEST_ROOT 'schemas/run-state.schema.json'
Test-Document $env:SCHEMA_TEST_DOCUMENT $schema 'run-state' $validationErrors
$standard = Test-Json -Json ([IO.File]::ReadAllText($env:SCHEMA_TEST_DOCUMENT)) -SchemaFile $schema -ErrorAction SilentlyContinue
@{ valid = ($validationErrors.Count -eq 0); standard = $standard; errors = @($validationErrors) } | ConvertTo-Json -Depth 10 -Compress
`;

function temporaryDirectory(t) {
  const directory = realpathSync.native(mkdtempSync(path.join(tmpdir(), 'stage-decisions-')));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  return directory;
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: 'utf8', timeout: 15000, ...options });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  return result.stdout;
}

function validate(t, document, expected, diagnostic) {
  const documentPath = path.join(temporaryDirectory(t), 'run-state.json');
  writeFileSync(documentPath, JSON.stringify(document));
  const result = JSON.parse(run('pwsh', ['-NoProfile', '-NonInteractive', '-Command', harness], {
    env: { ...process.env, SCHEMA_TEST_ROOT: root, SCHEMA_TEST_DOCUMENT: documentPath },
  }));
  t.diagnostic(JSON.stringify(result));
  assert.equal(result.standard, expected, 'standard schema result');
  assert.equal(result.valid, expected, JSON.stringify(result));
  // PowerShell 7.6.7's Test-Json emits no per-violation error records for nested
  // violations; the rejection verdict is asserted above regardless, and
  // field-path detail is asserted whenever the engine provides it.
  const engineDetails = result.errors.filter((line) => !/: schema validation failed in /.test(line));
  if (diagnostic && engineDetails.length) assert.match(engineDetails.join('\n'), diagnostic);
}

for (const verdict of ['required', 'skipped']) {
  test(`a: complete ${verdict} design verdict validates`, (t) => {
    validate(t, { ...template, stageDecisions: { design: { ...decision, verdict } } }, true);
  });
}

for (const [name, patch, diagnostic] of [
  ['b: pending verdict is rejected', { verdict: 'pending' }, /verdict/],
  ['c: empty reason is rejected', { reason: '' }, /reason/],
  ['empty evidence is rejected', { evidence: '' }, /evidence/],
]) {
  test(name, (t) => validate(t, { ...template, stageDecisions: { design: { ...decision, ...patch } } }, false, diagnostic));
}

for (const field of Object.keys(decision)) {
  test(`design verdict requires ${field}`, (t) => {
    const incomplete = { ...decision };
    delete incomplete[field];
    validate(t, { ...template, stageDecisions: { design: incomplete } }, false, new RegExp(field));
  });
}

for (const extensions of [false, true]) {
  test(`d: historical run without stageDecisions validates, extensions=${extensions}`, (t) => {
    const document = { ...template };
    delete document.stageDecisions;
    if (extensions) Object.assign(document, {
      scale: 'standard', intakeDecisions: { design: 'required' }, stages: { reconnaissance: 'completed' },
      sideEffectBoundary: { push: false }, runIntent: 'delivery', completedStages: ['intake', 'reconnaissance'],
    });
    validate(t, document, true);
  });
}

test('stage decisions allow extension fields at every object level', (t) => {
  validate(t, { ...template, futureField: true, stageDecisions: { futureStage: { verdict: 'future' }, design: { ...decision, futureField: true } } }, true);
});

test('e: template validates and exposes empty stageDecisions', (t) => {
  validate(t, template, true);
  assert.deepEqual(template.stageDecisions, {});
});

function fixtureProject(t) {
  const project = temporaryDirectory(t);
  run('git', ['init', '--template=', '--initial-branch=control', project]);
  const devWork = path.join(project, '.dev-work');
  mkdirSync(devWork);
  writeFileSync(path.join(devWork, 'manifest.json'), readFileSync(path.join(root, 'templates/dev-work/manifest.json')));
  writeFileSync(path.join(devWork, 'coordinator-lock.json'), JSON.stringify({
    schemaVersion: 1, status: 'active', activeRun: null, coordinatorControlBranch: 'control', coordinatorWorktree: project, startedAt: '2026-01-01',
  }));
  return project;
}

test('f: create-run initializes stageDecisions and all run directories', (t) => {
  const project = fixtureProject(t);
  const result = JSON.parse(run('pwsh', ['-NoProfile', '-NonInteractive', '-File', path.join(root, 'scripts/create-run.ps1'),
    '-ProjectRoot', project, '-Objective', 'Design verdict fixture', '-DeliveryBranch', 'main', '-RunSlug', 'design-test']));
  assert.equal(result.ok, true);
  const state = JSON.parse(readFileSync(result.statePath, 'utf8'));
  assert.deepEqual(state.stageDecisions, {});
  validate(t, state, true);
  const directories = ['assignments', 'attempts', 'dispatch-receipts', 'handoffs', 'reconnaissance', 'audits',
    'designs', 'plans', 'task-briefs', 'worker-reports', 'reviews', 'verification', 'evidence'];
  for (const directory of directories) assert.equal(statSync(path.join(result.runDirectory, directory)).isDirectory(), true, directory);
  t.diagnostic(JSON.stringify({ stageDecisions: state.stageDecisions, directories }));
});

for (const [name, completedStages, stageDecisions, expected] of [
  ['reconnaissance without field', ['intake', 'reconnaissance'], undefined, true],
  ['dynamic reconnaissance without field', ['intake', 'dynamic-reconnaissance'], undefined, true],
  ['parallel reconnaissance without field', ['intake', 'parallel-reconnaissance'], undefined, true],
  ['reconnaissance with empty decisions', ['intake', 'reconnaissance'], {}, true],
  ['reconnaissance with required verdict', ['intake', 'reconnaissance'], { design: decision }, false],
  ['reconnaissance with skipped verdict', ['intake', 'reconnaissance'], { design: { ...decision, verdict: 'skipped' } }, false],
  ['empty completedStages', [], undefined, false],
  ['light run', ['intake', 'implementation'], undefined, false],
]) {
  test(`g: missing design verdict warning: ${name}`, (t) => {
    const project = fixtureProject(t);
    const devWork = path.join(project, '.dev-work');
    const runDir = path.join(devWork, 'runs/design-test');
    mkdirSync(runDir, { recursive: true });
    writeFileSync(path.join(devWork, 'active-run.json'), JSON.stringify({
      schemaVersion: 1, run: 'design-test', runDirectory: 'runs/design-test', orcaRunId: null, updatedAt: '2026-01-01',
    }));
    writeFileSync(path.join(runDir, 'run-state.json'), JSON.stringify({
      ...template, runSlug: 'design-test', coordinatorWorktree: project, coordinatorControlBranch: 'control', deliveryBranch: 'main',
      completedStages, stageDecisions,
    }));
    const report = JSON.parse(run('pwsh', ['-NoProfile', '-NonInteractive', '-File', path.join(root, 'scripts/validate-run.ps1'),
      '-ProjectRoot', project, '-SkipPackageChecks']));
    assert.equal(report.ok, true, JSON.stringify(report));
    assert.deepEqual(report.errors, []);
    const designWarnings = report.warnings.filter((warning) => /stageDecisions\.design/.test(warning));
    assert.equal(designWarnings.length, expected ? 1 : 0, JSON.stringify(report));
    t.diagnostic(JSON.stringify({ completedStages, ok: report.ok, errors: report.errors, designWarnings }));
  });
}
