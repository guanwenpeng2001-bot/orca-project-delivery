[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = (Get-Location).Path,

  [Parameter(Mandatory = $false)]
  [switch]$ConfirmRunClosed,

  [Parameter(Mandatory = $false)]
  [string]$Reason = "coordinator released"
)

$ErrorActionPreference = "Stop"
$warnings = @()

function Write-JsonFile {
  param([string]$Path, [object]$Value)
  $json = $Value | ConvertTo-Json -Depth 20
  [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

$root = (Resolve-Path $ProjectRoot).Path
$gitRoot = (& git -C $root rev-parse --show-toplevel 2>$null)
if (-not $gitRoot) { throw "Not inside a Git worktree." }
$gitRoot = (Resolve-Path $gitRoot.Trim()).Path

$devWork = Join-Path $gitRoot ".dev-work"
if (-not (Test-Path (Join-Path $devWork "manifest.json"))) {
  throw ".dev-work is not initialized: $devWork"
}
if (-not $ConfirmRunClosed) {
  throw @"
Refusing to release without -ConfirmRunClosed.
Before releasing, confirm that:
  1. every Task is settled (orca orchestration task-list --json),
  2. no worker still owes a decision
     (orca orchestration worker-list --terminal-state reclaimable --json),
  3. final verification and the run reports are written under .dev-work/runs/.
Then re-run with -ConfirmRunClosed.
"@
}

# Best-effort reclaimable-worker check. Unverifiable is reported, never treated as failure.
$reclaimable = $null
try {
  if (Get-Command orca -ErrorAction SilentlyContinue) {
    $raw = & orca orchestration worker-list --terminal-state reclaimable --json 2>$null
    if ($LASTEXITCODE -eq 0 -and $raw) {
      $parsed = $raw | ConvertFrom-Json
      $reclaimable = @(($parsed.result.workers)).Count
      if ($reclaimable -gt 0) {
        $warnings += "$reclaimable worker terminal(s) still report as reclaimable; settle or release them with the orchestration Skill."
      }
    } else {
      $warnings += "Could not read worker-list; reclaimable state is unverifiable."
    }
  } else {
    $warnings += "orca CLI not found; reclaimable state is unverifiable."
  }
} catch {
  $warnings += "worker-list check failed: $($_.Exception.Message)"
}

$stamp = [DateTimeOffset]::UtcNow.ToString("yyyyMMdd-HHmmss")
$archiveDir = Join-Path $devWork "archive\released-$stamp"
New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null

$lockPath = Join-Path $devWork "coordinator-lock.json"
$activePath = Join-Path $devWork "active-run.json"
$archived = @()
$activeRun = $null

if (Test-Path $activePath) {
  $active = Get-Content $activePath -Raw | ConvertFrom-Json
  $activeRun = $active.run
  Copy-Item $activePath (Join-Path $archiveDir "active-run.json")
  $archived += "active-run.json"
  Remove-Item $activePath -Force
} else {
  $warnings += "No active-run.json to clear."
}

if (Test-Path $lockPath) {
  Copy-Item $lockPath (Join-Path $archiveDir "coordinator-lock.json")
  $archived += "coordinator-lock.json"
  $lock = Get-Content $lockPath -Raw | ConvertFrom-Json
  $lock.status = "released"
  $lock | Add-Member -NotePropertyName releasedAt -NotePropertyValue ([DateTimeOffset]::UtcNow.ToString("o")) -Force
  $lock | Add-Member -NotePropertyName releaseReason -NotePropertyValue $Reason -Force
  $lock | Add-Member -NotePropertyName previousActiveRun -NotePropertyValue $activeRun -Force
  Write-JsonFile $lockPath $lock
} else {
  $warnings += "No coordinator-lock.json found; nothing to release."
}

[ordered]@{
  ok = $true
  projectRoot = $gitRoot
  releasedRun = $activeRun
  reason = $Reason
  archived = $archived
  archiveDir = $archiveDir
  reclaimableWorkers = $reclaimable
  warnings = $warnings
  note = "The Orca Run itself is a namespace and is not deleted by this script."
} | ConvertTo-Json -Depth 10
