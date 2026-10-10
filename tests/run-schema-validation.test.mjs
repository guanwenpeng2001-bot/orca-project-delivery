import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
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

test('raw JSON preserves distinct property casing', (t) => {
  const result = validate(t, { required: [], Required: [] }, {
    schema: { type: 'object', required: ['required', 'Required'], properties: { required: { type: 'array' }, Required: { type: 'array' } }, additionalProperties: false },
  });
  assert.equal(result.standard, true);
  assert.equal(result.valid, true, JSON.stringify(result));
});

test('malformed JSON returns a labeled validation error', (t) => {
  const result = validate(t, '{"skills":', { raw: true });
  assert.equal(result.standard, false);
  assert.equal(result.valid, false);
  assert.match(result.errors.join('\n'), /assignments\/schema-regression\.json:/);
});
