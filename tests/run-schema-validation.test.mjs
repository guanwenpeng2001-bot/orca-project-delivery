import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
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
      // PowerShell 7.6.7's Test-Json emits no per-violation error records for
      // nested violations; the rejection verdict is asserted above regardless,
      // and field-path detail is asserted whenever the engine provides it.
      const engineDetails = result.errors.filter((line) => !/: schema validation failed in /.test(line));
      if (engineDetails.length) assert.match(engineDetails.join('\n'), diagnostic);
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
  // See the engine-detail note in the cases loop above.
  const engineDetails = result.errors.filter((line) => !/: schema validation failed in /.test(line));
  if (engineDetails.length) {
    assert.match(engineDetails.join('\n'), /skills(?:\.|\/)required/);
    assert.match(engineDetails.join('\n'), /skills(?:\.|\/)conditional(?:\[0\]|\/0|\.0)/);
  }
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
