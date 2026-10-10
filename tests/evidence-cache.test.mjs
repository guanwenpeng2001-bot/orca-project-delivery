import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const validator = fileURLToPath(new URL('../scripts/validate-git-evidence.ps1', import.meta.url));

test('evidence input and assignment caches retain case, duplicates and original diagnostics', (t) => {
  const directory = mkdtempSync(path.join(tmpdir(), 'evidence-cache-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const harness = String.raw`
$ErrorActionPreference = 'Stop'
$tokens = $null
$errors = $null
$syntax = [Management.Automation.Language.Parser]::ParseFile($env:CACHE_VALIDATOR, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$entry = @($syntax.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.TryStatementAst] })[0]
$definitions = [IO.File]::ReadAllText($env:CACHE_VALIDATOR).Substring(0, $entry.Extent.StartOffset)
. ([scriptblock]::Create($definitions))
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$runName = 'cache-run'
$runDirectory = $env:CACHE_ROOT
$assignmentDirectory = Join-Path $runDirectory 'assignments'
$null = New-Item -ItemType Directory $assignmentDirectory
[IO.File]::WriteAllText((Join-Path $assignmentDirectory 'lower.json'), '{"taskKey":"report","branch":{"mergeTarget":"main"}}')
[IO.File]::WriteAllText((Join-Path $assignmentDirectory 'upper.json'), '{"taskKey":"Report","branch":{"mergeTarget":null}}')
[IO.File]::WriteAllText((Join-Path $assignmentDirectory 'duplicate.json'), '{"taskKey":"report","branch":{"mergeTarget":"main"}}')
Initialize-Assignments
Require ($assignments.Count -eq 3) 'All assignments must be retained'
Require ($assignmentsByTaskKey.Count -eq 2) 'Task keys must be case-sensitive'
Require ($assignmentsByTaskKey['report'].Count -eq 2) 'Duplicate task keys must not overwrite each other'
Remove-Item -LiteralPath $assignmentDirectory -Recurse -Force
Initialize-Assignments
Require ($assignments.Count -eq 3) 'Assignments must be loaded once per invocation'
Test-SupersededAssignment @{ taskKey = 'old'; supersededBy = 'report' } $assignments @('completed')
Require ($problems[-1] -ceq 'Assignment old supersededBy must identify exactly one existing assignment in this run') 'Duplicate successor diagnostic changed'
$problems.Clear()
$evidenceDirectory = Join-Path $runDirectory 'evidence/git'
$null = New-Item -ItemType Directory $evidenceDirectory -Force
$path = Join-Path $evidenceDirectory 'report.json'
[IO.File]::WriteAllText($path, '{"run":"cache-run","subject":{"taskKey":"report"}}')
$first = Read-Json $path
# The selected evidence is parsed once for run selection and later schema validation.
[IO.File]::WriteAllText($path, 'invalid replacement after first read')
$schema = '{"type":"object","required":["run","subject"]}'
function Test-RecordedCommits($Value, [string]$Label) {}
$second = Get-Evidence $path
Require ([object]::ReferenceEquals($first, $second)) 'Evidence should reuse the parsed document'
Require ((Get-Evidence $path).run -ceq 'cache-run') 'Validated document must remain cached'
Require ($problems.Count -eq 0) 'Cached valid raw JSON must pass schema validation'
$missingPath = Join-Path $runDirectory 'missing.json'
try { Read-Json $missingPath; throw 'missing accepted' } catch {
  Require ($_.Exception.Message -ceq "Missing evidence file $missingPath; rebuild evidence or mark UNVERIFIABLE.") 'Missing-file diagnostic changed'
}
$badPath = Join-Path $runDirectory 'bad.json'
[IO.File]::WriteAllText($badPath, '{broken')
try { Read-Json $badPath; throw 'bad JSON accepted' } catch {
  Require ($_.Exception.Message.StartsWith("Invalid JSON in "+$badPath+':')) 'Invalid JSON diagnostic changed'
}
# Exercise read-only classification through the index, including the case distinction.
function Resolve-EvidencePath([string]$Path, [string]$Base) { return $env:CACHE_VALIDATOR }
function Test-Ancestor {}
$document = @{ subject = @{ taskKey = 'Report' }; state = 'reviewed'; source = @{ workerDone = @{ taskId = 'author'; dispatchId = 'author' } }; reviews = @(@{ reviewer = @{ taskId = 'reviewer'; dispatchId = 'reviewer' }; reportPath = 'report'; baseline = @{ commitSha = 'same' }; target = @{ commitSha = 'same' }; verdict = 'APPROVED' }) }
Test-TaskEvidence $document 'review'
Require ($problems.Count -eq 0) 'Exact read-only key should allow equal baseline'
$document.subject.taskKey = 'report'
Test-TaskEvidence $document 'review'
Require ($problems[-1] -ceq 'report review target equals baseline') 'Differently cased formal key must not acquire read-only exemption'
`;
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', harness], {
    encoding: 'utf8', timeout: 15000,
    env: { ...process.env, CACHE_VALIDATOR: validator, CACHE_ROOT: directory },
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
