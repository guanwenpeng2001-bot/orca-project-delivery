import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const verifier = fileURLToPath(new URL('../scripts/verification-runtime.ps1', import.meta.url));
const helpers = fileURLToPath(new URL('../scripts/verification-common.ps1', import.meta.url));
const requiredSuites = ['document-production.test.py', 'document-depth-office.test.py'];

for (const metadataOnly of [false, true]) {
  test(`setup failure emits one JSON result before closing summary (MetadataOnly=${metadataOnly})`, (t) => {
    const root = mkdtempSync(path.join(tmpdir(), 'package-setup-failure-'));
    t.after(() => rmSync(root, { recursive: true, force: true }));
    const entrypoint = fileURLToPath(new URL('../scripts/verify-package.ps1', import.meta.url));
    const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', entrypoint,
      '-PackageRoot', path.join(root, 'missing'), ...(metadataOnly ? ['-MetadataOnly'] : [])], {
      encoding: 'utf8', timeout: 20000,
    });
    assert.ifError(result.error);
    assert.equal(result.status, 1, result.stdout + result.stderr);
    const lines = result.stdout.trim().split(/\r?\n/);
    const jsonLines = lines.filter((line) => line.startsWith('{'));
    assert.equal(jsonLines.length, 1, result.stdout);
    assert.equal(JSON.parse(jsonLines[0]).failed, 1);
    assert.match(lines.at(-1), /SUMMARY PASS=0 FAIL=1$/);
    assert.ok(lines.indexOf(jsonLines[0]) < lines.length - 1);
  });
}

test('MetadataOnly cleanup failure exits 1 with the failure in JSON and summary', (t) => {
  const source = fileURLToPath(new URL('../', import.meta.url));
  const copy = mkdtempSync(path.join(tmpdir(), 'package-cleanup-failure-'));
  t.after(() => rmSync(copy, { recursive: true, force: true }));
  cpSync(source, copy, { recursive: true, filter: (item) => !['.git', '.dev-work', '.claude'].includes(path.basename(item)) });
  const entrypoint = path.join(copy, 'scripts', 'verify-package.ps1');
  const original = readFileSync(entrypoint, 'utf8');
  const anchor = 'Assert-Condition (-not (Test-Path -LiteralPath $resolvedTemporary)) "Temporary root remains: $resolvedTemporary"';
  assert.equal(original.split(anchor).length - 1, 1, 'cleanup assertion anchor must be unique');
  writeFileSync(entrypoint, original.replace(anchor, "Assert-Condition $false 'induced cleanup failure for regression test'"));
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', entrypoint, '-PackageRoot', copy, '-MetadataOnly'], {
    encoding: 'utf8', timeout: 20000,
  });
  assert.ifError(result.error);
  assert.equal(result.status, 1, result.stdout + result.stderr);
  const lines = result.stdout.trim().split(/\r?\n/);
  const jsonLines = lines.filter((line) => line.startsWith('{'));
  assert.equal(jsonLines.length, 1, result.stdout);
  const summary = JSON.parse(jsonLines[0]);
  assert.ok(summary.failed >= 1, result.stdout);
  assert.equal(summary.ok, false);
  assert.match(lines.at(-1), /^METADATA SUMMARY PASS=\d+ FAIL=[1-9]\d*$/);
  assert.match(result.stdout, /FAIL cleanup\/temporary-root: induced cleanup failure/);
});

for (const characters of [19799, 19800, 22000, 22001]) {
  test(`entry character budget at ${characters} Unicode characters`, (t) => {
    const source = fileURLToPath(new URL('../', import.meta.url));
    const entrypoint = path.join(source, 'scripts', 'verify-package.ps1');
    const copy = mkdtempSync(path.join(tmpdir(), 'package-entry-budget-'));
    t.after(() => rmSync(copy, { recursive: true, force: true }));
    cpSync(source, copy, { recursive: true, filter: (item) => !['.git', '.dev-work'].includes(path.basename(item)) });
    const entryPath = path.join(copy, 'SKILL.md');
    const outline = readFileSync(entryPath, 'utf8').split('\n').filter((line) => line.startsWith('## ')).join('\n') + '\n';
    const padding = characters - [...outline].length;
    assert.ok(padding > 0);
    writeFileSync(entryPath, outline + '\u{10400}'.repeat(padding - 1) + ' ');
    const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', entrypoint, '-PackageRoot', copy, '-MetadataOnly'], {
      encoding: 'utf8', timeout: 20000,
    });
    assert.ifError(result.error);
    const output = result.stdout + result.stderr;
    const oversized = characters > 22000;
    assert.equal(result.status, oversized ? 1 : 0, output);
    if (oversized) assert.match(output, /FAIL metadata\/entry-character-budget: SKILL\.md has 22001 Unicode characters including whitespace; limit is 22000/);
    else assert.match(output, /PASS metadata\/entry-character-budget/);
    const outputLines = result.stdout.trim().split(/\r?\n/);
    const summaryLines = outputLines.filter((line) => line.startsWith('{'));
    assert.equal(summaryLines.length, 1, output);
    assert.match(outputLines.at(-1), /^METADATA SUMMARY PASS=\d+ FAIL=\d+$/);
    const summaryLine = summaryLines[0];
    assert.ok(outputLines.indexOf(summaryLine) < outputLines.length - 1);
    const summary = JSON.parse(summaryLine);
    assert.equal(summary.failed, oversized ? 1 : 0, output);
    assert.equal(summary.ok, !oversized);
    assert.equal(summary.warnings.length, characters >= 19800 && !oversized ? 1 : 0);
    if (summary.warnings.length) {
      assert.ok(summary.warnings[0].includes(`SKILL.md has ${characters} Unicode characters including whitespace`));
      assert.ok(output.includes(`WARNING: ${summary.warnings[0]}`), output);
    } else assert.doesNotMatch(output, /WARNING: SKILL\.md/);
    t.diagnostic(`characters=${characters}, status=${result.status}, warnings=${summary.warnings.length}`);
  });
}

// Keep the baseline entrypoints plus the extracted runtime dependencies mandatory.
test('MetadataOnly rejects every missing required script and parses discovered extensions', (t) => {
  const source = fileURLToPath(new URL('../', import.meta.url));
  const entrypoint = path.join(source, 'scripts', 'verify-package.ps1');
  const copy = mkdtempSync(path.join(tmpdir(), 'package-required-scripts-'));
  t.after(() => rmSync(copy, { recursive: true, force: true }));
  cpSync(source, copy, { recursive: true, filter: (item) => !['.git', '.dev-work'].includes(path.basename(item)) });
  const required = [
    'assemble-task.ps1', 'bootstrap-project.ps1', 'create-run.ps1', 'dispatch-task.ps1',
    'probe-claude-capabilities.ps1', 'query-routing.ps1', 'reconcile-state.ps1', 'release-coordinator.ps1',
    'validate-run.ps1', 'validate-git-evidence.ps1', 'verify-package.ps1',
    'requirements-lib.ps1', 'check-requirements.ps1', 'invoke-with-requirements.ps1',
    'verify-requirements.ps1', 'project-common.ps1', 'verification-common.ps1',
    'verification-structure.ps1', 'verification-runtime.ps1', 'verification-lifecycle.ps1',
    'verification-evidence-fixtures.ps1', 'verification-evidence.ps1', 'verification-mutations.ps1',
  ];
  const verify = () => {
    const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', entrypoint, '-PackageRoot', copy, '-MetadataOnly'], {
      encoding: 'utf8', timeout: 20000,
    });
    assert.ifError(result.error);
    return { status: result.status, output: result.stdout + result.stderr };
  };
  const baseline = verify();
  assert.equal(baseline.status, 0, baseline.output);
  for (const name of required) {
    const target = path.join(copy, 'scripts', name);
    const original = readFileSync(target);
    try {
      rmSync(target);
      const result = verify();
      assert.equal(result.status, 1, name + ': ' + result.output);
      assert.match(result.output, /FAIL package\/required-scripts: Missing required script:/);
      assert.ok(result.output.includes(name), result.output);
    } finally { writeFileSync(target, original); }
  }
  writeFileSync(path.join(copy, 'scripts', 'discovered-extension.ps1'), 'function Broken {');
  const extension = verify();
  assert.equal(extension.status, 1, extension.output);
  assert.match(extension.output, /FAIL parse\/discovered-extension.ps1/);
});
// Execute the suite selection resolver verbatim without rerunning unrelated package gates.
const resolverHarness = String.raw`
$ErrorActionPreference = 'Stop'
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($env:PACKAGE_TEST_RESOLVER_SOURCE, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$definitions = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Resolve-SuiteSelection' }, $true))
if ($definitions.Count -ne 1) { throw 'Expected exactly one Resolve-SuiteSelection definition' }
. ([scriptblock]::Create($definitions[0].Extent.Text))
$requested = @($env:PACKAGE_TEST_REQUESTED -split '\n' | Where-Object { $_ -ne '' })
$result = Resolve-SuiteSelection -Requested $requested -MetadataOnly:($env:PACKAGE_TEST_METADATA_ONLY -eq '1') -SkipMutationTests:($env:PACKAGE_TEST_SKIP -eq '1')
[ordered]@{ requested = @($result.Requested); running = @($result.Running); explicit = [bool]$result.Explicit } | ConvertTo-Json -Compress
`;

function runResolver(requested, { metadataOnly = false, skipMutationTests = false } = {}) {
  const environment = { ...process.env,
    PACKAGE_TEST_RESOLVER_SOURCE: helpers,
    PACKAGE_TEST_REQUESTED: requested.join('\n'),
    PACKAGE_TEST_METADATA_ONLY: metadataOnly ? '1' : '0',
    PACKAGE_TEST_SKIP: skipMutationTests ? '1' : '0',
  };
  delete environment.NODE_TEST_CONTEXT;
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', resolverHarness], {
    encoding: 'utf8', timeout: 20000, env: environment,
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  return JSON.parse(result.stdout.trim());
}

test('suite selection rejects an unknown suite name', (t) => {
  const entrypoint = fileURLToPath(new URL('../scripts/verify-package.ps1', import.meta.url));
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', entrypoint, '-Suites', 'no-such-suite'], {
    encoding: 'utf8', timeout: 20000,
  });
  assert.ifError(result.error);
  assert.equal(result.status, 1, result.stdout + result.stderr);
  const lines = result.stdout.trim().split(/\r?\n/);
  const jsonLines = lines.filter((line) => line.startsWith('{'));
  assert.equal(jsonLines.length, 1, result.stdout);
  assert.equal(JSON.parse(jsonLines[0]).failed, 1);
  assert.match(lines.at(-1), /SUMMARY PASS=0 FAIL=1$/);
  assert.match(result.stdout, /FAIL harness\/setup: Unknown suite 'no-such-suite'/);
  assert.ok(result.stdout.includes('git evidence'), result.stdout);
});

test('suite selection rejects an empty suite name', (t) => {
  const entrypoint = fileURLToPath(new URL('../scripts/verify-package.ps1', import.meta.url));
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', entrypoint, '-Suites', '   '], {
    encoding: 'utf8', timeout: 20000,
  });
  assert.ifError(result.error);
  assert.equal(result.status, 1, result.stdout + result.stderr);
  const lines = result.stdout.trim().split(/\r?\n/);
  const jsonLines = lines.filter((line) => line.startsWith('{'));
  assert.equal(jsonLines.length, 1, result.stdout);
  assert.equal(JSON.parse(jsonLines[0]).failed, 1);
  assert.match(lines.at(-1), /SUMMARY PASS=0 FAIL=1$/);
  assert.match(result.stdout, /FAIL harness\/setup: Unknown suite '   '\s*\(declared: /);
});

test('suite selection refuses -MetadataOnly combined with -Suites', (t) => {
  const entrypoint = fileURLToPath(new URL('../scripts/verify-package.ps1', import.meta.url));
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', entrypoint, '-MetadataOnly', '-Suites', 'package contracts'], {
    encoding: 'utf8', timeout: 20000,
  });
  assert.ifError(result.error);
  assert.equal(result.status, 1, result.stdout + result.stderr);
  const lines = result.stdout.trim().split(/\r?\n/);
  const jsonLines = lines.filter((line) => line.startsWith('{'));
  assert.equal(jsonLines.length, 1, result.stdout);
  assert.equal(JSON.parse(jsonLines[0]).failed, 1);
  assert.match(result.stdout, /-MetadataOnly cannot be combined with -Suites/);
  assert.ok(!result.stdout.includes('SUITE package runtime'), result.stdout);
});

test('Resolve-SuiteSelection normalizes case and whitespace and deduplicates', () => {
  const result = runResolver([' Package Contracts ', 'package contracts']);
  assert.deepEqual(result.requested, ['package contracts']);
  assert.deepEqual(result.running, ['package structure', 'package contracts']);
  assert.equal(result.explicit, true);
});

test('Resolve-SuiteSelection expands evidence source mutations with git evidence', () => {
  const result = runResolver(['evidence source mutations']);
  assert.deepEqual(result.requested, ['evidence source mutations']);
  assert.deepEqual(result.running, ['package structure', 'git evidence', 'evidence source mutations']);
  assert.equal(result.explicit, true);
});

test('Resolve-SuiteSelection treats an empty selection as the full gate', () => {
  const result = runResolver([]);
  assert.deepEqual(result.requested, []);
  assert.deepEqual(result.running, ['package structure', 'package runtime', 'package contracts', 'project lifecycle', 'git evidence', 'evidence source mutations']);
  assert.equal(result.explicit, false);
});

test('Resolve-SuiteSelection applies SkipMutationTests after expansion', () => {
  const result = runResolver(['evidence source mutations'], { skipMutationTests: true });
  assert.deepEqual(result.running, ['package structure', 'git evidence']);
  assert.equal(result.explicit, true);
});

test('subset run prints SUITES lines and keeps the summary contract', (t) => {
  const source = fileURLToPath(new URL('../', import.meta.url));
  const copy = mkdtempSync(path.join(tmpdir(), 'package-suite-selection-'));
  t.after(() => rmSync(copy, { recursive: true, force: true }));
  cpSync(source, copy, { recursive: true, filter: (item) => !['.git', '.dev-work', '.claude'].includes(path.basename(item)) });
  const entrypoint = path.join(copy, 'scripts', 'verify-package.ps1');
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', entrypoint, '-PackageRoot', copy, '-Suites', 'package contracts'], {
    encoding: 'utf8', timeout: 120000,
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.ok(result.stdout.includes('SUITES requested: package contracts'), result.stdout);
  assert.ok(result.stdout.includes('SUITES running: package structure, package contracts'), result.stdout);
  assert.ok(result.stdout.includes('SUITE package contracts'), result.stdout);
  assert.ok(!result.stdout.includes('SUITE package runtime'), result.stdout);
  assert.ok(result.stdout.includes('PASS fixtures/stage-package-and-skills'), result.stdout);
  const lines = result.stdout.trim().split(/\r?\n/);
  const jsonLines = lines.filter((line) => line.startsWith('{'));
  assert.equal(jsonLines.length, 1, result.stdout);
  assert.equal(JSON.parse(jsonLines[0]).ok, true);
  assert.match(lines.at(-1), /^SUMMARY PASS=\d+ FAIL=0$/);
});

function spawnSubsetRun(t, tempPrefix, ...selectionArguments) {
  const source = fileURLToPath(new URL('../', import.meta.url));
  const copy = mkdtempSync(path.join(tmpdir(), tempPrefix));
  t.after(() => rmSync(copy, { recursive: true, force: true }));
  cpSync(source, copy, { recursive: true, filter: (item) => !['.git', '.dev-work', '.claude'].includes(path.basename(item)) });
  const entrypoint = path.join(copy, 'scripts', 'verify-package.ps1');
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', entrypoint, '-PackageRoot', copy, ...selectionArguments], {
    encoding: 'utf8', timeout: 120000,
  });
  assert.ifError(result.error);
  return result;
}

test('comma-joined multi-suite selection runs both suites', (t) => {
  const result = spawnSubsetRun(t, 'package-suite-comma-', '-Suites', 'package structure,package contracts');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.ok(result.stdout.includes('SUITES requested: package structure, package contracts'), result.stdout);
  assert.ok(result.stdout.includes('SUITES running: package structure, package contracts'), result.stdout);
  assert.ok(result.stdout.includes('SUITE package structure'), result.stdout);
  assert.ok(result.stdout.includes('SUITE package contracts'), result.stdout);
  const lines = result.stdout.trim().split(/\r?\n/);
  const jsonLines = lines.filter((line) => line.startsWith('{'));
  assert.equal(jsonLines.length, 1, result.stdout);
  assert.equal(JSON.parse(jsonLines[0]).ok, true);
  assert.match(lines.at(-1), /^SUMMARY PASS=\d+ FAIL=0$/);
});

test('a straggler token fails loudly instead of narrowing silently', (t) => {
  const result = spawnSubsetRun(t, 'package-suite-straggler-', '-Suites', 'package contracts', 'git evidence');
  assert.notEqual(result.status, 0, result.stdout + result.stderr);
  assert.ok(!result.stdout.includes('SUMMARY PASS='), result.stdout);
  assert.ok(!result.stdout.includes('SUITES requested:'), result.stdout);
});

test('the comma form normalizes case, surrounding whitespace and duplicates', (t) => {
  const result = spawnSubsetRun(t, 'package-suite-normalize-', '-Suites', '  PACKAGE STRUCTURE , package structure  ');
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.ok(result.stdout.includes('SUITES requested: package structure'), result.stdout);
  assert.ok(result.stdout.includes('SUITES running: package structure'), result.stdout);
  assert.ok(!result.stdout.includes('SUITE package contracts'), result.stdout);
  assert.ok(!result.stdout.includes('PASS fixtures/stage-package-and-skills'), result.stdout);
  assert.ok(!result.stdout.includes('TEMP package copy'), result.stdout);
});

const pythonProbe = spawnSync('python', ['-I', '-c', 'import sys; print(sys.executable)'], { encoding: 'utf8', timeout: 10000 });
const python = pythonProbe.status === 0 ? pythonProbe.stdout.trim() : '';
const pythonOptions = { skip: python ? false : 'missing dependency: Python interpreter was not found on PATH' };

// Execute the production checks and helpers verbatim without rerunning unrelated package gates.
const harness = String.raw`
$ErrorActionPreference = 'Stop'
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($env:PACKAGE_TEST_VERIFIER, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
. $env:PACKAGE_TEST_HELPERS
$checks = @($ast.FindAll({ param($node)
  $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Invoke-Check' -and
    $node.CommandElements[1].Value -eq $env:PACKAGE_TEST_CHECK
}, $true))
if ($checks.Count -ne 1) { throw 'Expected one runtime check' }
$root = $env:PACKAGE_TEST_ROOT
$temporaryRoot = $root
$stagedPackage = $root
# A runtime check must use the staged package even when the source has no tests.
$root = Join-Path $root 'source-package-not-used'
$SuiteTimeoutSeconds = 30
$DocumentPython = $env:PACKAGE_TEST_PYTHON
$passed = 0
$failed = 0
& ([scriptblock]::Create($checks[0].Extent.Text))
if ($failed) { exit 1 }
exit 0
`;

function runCheck(t, check, files) {
  const root = mkdtempSync(path.join(tmpdir(), 'package-discovery-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  mkdirSync(path.join(root, 'tests'));
  mkdirSync(path.join(root, 'skills'));
  for (const [name, content] of Object.entries(files)) {
    const destination = path.join(root, name);
    mkdirSync(path.dirname(destination), { recursive: true });
    writeFileSync(destination, content);
  }
  const environment = { ...process.env, PACKAGE_TEST_VERIFIER: verifier, PACKAGE_TEST_HELPERS: helpers, PACKAGE_TEST_ROOT: root,
    PACKAGE_TEST_CHECK: check, PACKAGE_TEST_PYTHON: python };
  // Nested Node runners otherwise suppress execution when inheriting the parent test context.
  delete environment.NODE_TEST_CONTEXT;
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', harness], {
    encoding: 'utf8', timeout: 15000, env: environment,
  });
  assert.ifError(result.error);
  return { status: result.status, output: result.stdout + result.stderr };
}

const passingPython = Object.fromEntries(requiredSuites.map((name) => [
  `tests/${name}`, `import sys\nassert sys.flags.isolated == 1\nprint('${name} executed')\n`,
]));

for (const missing of [[requiredSuites[0]], [requiredSuites[1]], requiredSuites]) {
  test(`document gate rejects missing suites: ${missing.join(', ')}`, pythonOptions, (t) => {
    const files = { ...passingPython, 'tests/extension.test.py': "print('extension executed')\n" };
    for (const name of missing) delete files[`tests/${name}`];
    const result = runCheck(t, 'runtime/document-generation-readback', files);
    assert.equal(result.status, 1, result.output);
    assert.ok(result.output.includes(`Missing required document suite: ${missing[0]}`), result.output);
  });
}

test('document gate rejects an empty Python discovery', pythonOptions, (t) => {
  const result = runCheck(t, 'runtime/document-generation-readback', {});
  assert.equal(result.status, 1, result.output);
  assert.match(result.output, /Missing required document suite:/);
});

test('document gate runs both required suites and extensions with isolated Python', pythonOptions, (t) => {
  const files = { ...passingPython, 'tests/extension.test.py': "import sys\nassert sys.flags.isolated == 1\nprint('extension executed')\n" };
  const result = runCheck(t, 'runtime/document-generation-readback', files);
  assert.equal(result.status, 0, result.output);
  for (const name of requiredSuites) assert.ok(result.output.includes(`${name} executed`), result.output);
  assert.match(result.output, /extension executed/);
});

for (const name of [...requiredSuites, 'extension.test.py']) {
  test(`document gate propagates actual test failure: ${name}`, pythonOptions, (t) => {
    const result = runCheck(t, 'runtime/document-generation-readback', {
      ...passingPython, [`tests/${name}`]: "import unittest\nclass Broken(unittest.TestCase):\n    def test_failure(self):\n        self.fail('document fixture failure')\nunittest.main()\n",
    });
    assert.equal(result.status, 1, result.output);
    assert.ok(result.output.includes(`Document generation tests failed for ${name}`), result.output);
    assert.match(result.output, /document fixture failure/);
    assert.match(result.output, /FAILED \(failures=1\)/);
  });
}

test('Node gate rejects empty discovery', (t) => {
  const result = runCheck(t, 'runtime/capability-behavior', {});
  assert.equal(result.status, 1, result.output);
  assert.match(result.output, /No Node test suites were discovered/);
});

test('Node gate discovers top-level suites and nested examples', (t) => {
  const result = runCheck(t, 'runtime/capability-behavior', {
    'tests/fixture.test.mjs': "import test from 'node:test'; test('top-level fixture', () => {});\n",
    'skills/fixture/examples/example.test.mjs': "import test from 'node:test'; test('nested fixture', () => {});\n",
  });
  assert.equal(result.status, 0, result.output);
  assert.match(result.output, /top-level fixture/);
  assert.match(result.output, /nested fixture/);
});

test('Node gate propagates an actual nested example test failure', (t) => {
  const result = runCheck(t, 'runtime/capability-behavior', {
    'skills/fixture/examples/example.test.mjs': "import test from 'node:test'; import assert from 'node:assert/strict'; test('nested fixture failure', () => assert.fail('example failed'));\n",
  });
  assert.equal(result.status, 1, result.output);
  assert.match(result.output, /Capability behavior tests failed/);
  assert.match(result.output, /example failed/);
});
