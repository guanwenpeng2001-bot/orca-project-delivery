import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const scripts = fileURLToPath(new URL('../scripts/', import.meta.url));

test('shared project helpers preserve branch precedence, JSON depth and Git failures', (t) => {
  const directory = mkdtempSync(path.join(tmpdir(), 'project-common-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const harness = String.raw`
$ErrorActionPreference = 'Stop'
. (Join-Path $env:HELPER_SCRIPTS 'project-common.ps1')
. (Join-Path $env:HELPER_SCRIPTS 'verification-common.ps1')
$temporaryRoot = $env:HELPER_ROOT
$git = (Get-Command git).Source
[IO.File]::WriteAllText((Join-Path $temporaryRoot 'empty-git-config'), '')
$repository = New-FixtureRepository 'resolution'
# The shared helper intentionally retains the caller environment. Isolate this fixture caller.
foreach ($key in @(Get-ChildItem Env: | Where-Object Name -Like 'GIT_*')) { Remove-Item ('Env:' + $key.Name) }
$env:GIT_CONFIG_NOSYSTEM = '1'
$env:GIT_CONFIG_GLOBAL = Join-Path $temporaryRoot 'empty-git-config'
function Check-Resolution([string]$Expected, [string]$Source, [string]$Explicit = '') {
  $resolved = Resolve-DeliveryBranch -Root $repository -CurrentBranch 'verification-control' -DeliveryBranch $Explicit
  Assert-Condition ($resolved.Branch -ceq $Expected -and $resolved.Source -ceq $Source) "Resolution mismatch: $($resolved | ConvertTo-Json -Compress)"
}
Check-Resolution 'main' 'main'
$commit = Invoke-Git $repository @('rev-parse', 'HEAD')
$null = Invoke-Git $repository @('update-ref', 'refs/heads/master', $commit)
$null = Invoke-Git $repository @('update-ref', '-d', 'refs/heads/main')
Check-Resolution 'master' 'master'
$null = Invoke-Git $repository @('update-ref', '-d', 'refs/heads/master')
Check-Resolution 'verification-control' 'current'
$null = Invoke-Git $repository @('config', 'init.defaultBranch', 'develop')
Check-Resolution 'verification-control' 'current'
$null = Invoke-Git $repository @('update-ref', 'refs/heads/develop', $commit)
Check-Resolution 'develop' 'init-default'
$null = Invoke-Git $repository @('update-ref', 'refs/remotes/origin/trunk', $commit)
$null = Invoke-Git $repository @('symbolic-ref', 'refs/remotes/origin/HEAD', 'refs/remotes/origin/trunk')
Check-Resolution 'trunk' 'origin-head'
Check-Resolution 'release' 'user' 'release'
$failure = $null
try { Invoke-Git $repository @('rev-parse', '--verify', 'missing-ref') } catch { $failure = $_.Exception.Message }
Assert-Condition ($failure.StartsWith('git rev-parse --verify missing-ref failed (exit 128) in ')) 'Git failure diagnostic changed'
$value = @{ leaf = 'value' }
foreach ($level in 1..24) { $value = @{ nested = $value } }
foreach ($depth in @(20, 30)) {
  $destination = Join-Path $temporaryRoot "depth-$depth.json"
  $expected = ($value | ConvertTo-Json -Depth $depth -WarningAction SilentlyContinue) + [Environment]::NewLine
  Write-JsonFile $destination $value -Depth $depth -WarningAction SilentlyContinue
  Assert-Condition ([IO.File]::ReadAllText($destination) -ceq $expected) "JSON depth $depth changed"
  $bytes = [IO.File]::ReadAllBytes($destination)
  Assert-Condition (-not ($bytes[0] -eq 0xef -and $bytes[1] -eq 0xbb -and $bytes[2] -eq 0xbf)) 'JSON must remain BOM-free'
}
`;
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', harness], {
    encoding: 'utf8', timeout: 20000,
    env: { ...process.env, HELPER_SCRIPTS: scripts, HELPER_ROOT: directory },
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
