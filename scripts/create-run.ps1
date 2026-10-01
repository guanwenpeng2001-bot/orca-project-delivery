[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = (Get-Location).Path,

  [Parameter(Mandatory = $true)]
  [string]$Objective,

  [Parameter(Mandatory = $false)]
  [ValidateSet("feature-development", "bug-fix", "refactor", "audit")]
  [string]$Workflow = "feature-development",

  [Parameter(Mandatory = $false)]
  [string]$DeliveryBranch,

  [Parameter(Mandatory = $false)]
  [string]$RunSlug,

  [Parameter(Mandatory = $false)]
  [string]$OrcaRunId,

  [Parameter(Mandatory = $false)]
  [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-JsonFile {
  param([string]$Path, [object]$Value)
  $json = $Value | ConvertTo-Json -Depth 30
  [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

$root = (Resolve-Path $ProjectRoot).Path
$gitRoot = (& git -C $root rev-parse --show-toplevel 2>$null)
if (-not $gitRoot) { throw "Not inside a Git worktree." }
$gitRoot = (Resolve-Path $gitRoot.Trim()).Path

# Validate the coordinator control branch before any write, so a detached HEAD cannot
# leave a partial run directory behind.
$currentBranch = (& git -C $gitRoot branch --show-current 2>$null)
$currentBranch = if ($currentBranch) { $currentBranch.Trim() } else { $null }
if (-not $currentBranch) {
  throw "Cannot create a run from a detached HEAD: $gitRoot. Check out the coordinator control branch first."
}

# delivery_branch: an explicit value wins; otherwise the repository default branch
# (main, else master), else the current branch. The source is recorded in run-state.
$deliveryBranchSource = "user"
if (-not $DeliveryBranch) {
  foreach ($candidate in @("main", "master")) {
    & git -C $gitRoot show-ref --verify --quiet "refs/heads/$candidate"
    if ($LASTEXITCODE -eq 0) { $DeliveryBranch = $candidate; $deliveryBranchSource = $candidate; break }
  }
  if (-not $DeliveryBranch) { $DeliveryBranch = $currentBranch; $deliveryBranchSource = "current" }
}

$devWork = Join-Path $gitRoot ".dev-work"
if (-not (Test-Path (Join-Path $devWork "manifest.json"))) {
  throw ".dev-work is not initialized. Run bootstrap-project.ps1 first."
}

$activePath = Join-Path $devWork "active-run.json"
if ((Test-Path $activePath) -and -not $Force) {
  $active = Get-Content $activePath -Raw | ConvertFrom-Json
  if ($active.run) {
    throw "An active run already exists: $($active.run). Close it or use -Force only after reconciliation."
  }
}

if (-not $RunSlug) {
  $candidate = $Objective.ToLowerInvariant()
  $candidate = [regex]::Replace($candidate, "[^a-z0-9]+", "-").Trim("-")
  if (-not $candidate) {
    $candidate = "run-" + [DateTimeOffset]::UtcNow.ToString("yyyyMMdd-HHmmss")
  }
  $RunSlug = $candidate.Substring(0, [Math]::Min(64, $candidate.Length))
}

$runDir = Join-Path (Join-Path $devWork "runs") $RunSlug
$runDirCreated = $false
$archivedState = $null

try {
  if ((Test-Path $runDir) -and -not $Force) {
    throw "Run directory already exists: $runDir"
  }
  if (-not (Test-Path $runDir)) {
    New-Item -ItemType Directory -Path $runDir | Out-Null
    $runDirCreated = $true
  }

  $subdirs = @(
    "assignments",
    "attempts",
    "handoffs",
    "reconnaissance",
    "audits",
    "plans",
    "task-briefs",
    "worker-reports",
    "reviews",
    "verification",
    "evidence"
  )
  foreach ($dir in $subdirs) {
    New-Item -ItemType Directory -Path (Join-Path $runDir $dir) -Force | Out-Null
  }

  # -Force reuses an existing run directory. Archive the prior state first so a reset
  # is never silent.
  if ($Force) {
    $existingStatePath = Join-Path $runDir "run-state.json"
    if (Test-Path $existingStatePath) {
      $archiveDir = Join-Path $runDir "archive"
      New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
      $stamp = [DateTimeOffset]::UtcNow.ToString("yyyyMMdd-HHmmss")
      foreach ($name in @("run-state", "branch-map", "task-map", "degradation-events")) {
        $src = Join-Path $runDir "$name.json"
        if (Test-Path $src) { Copy-Item $src (Join-Path $archiveDir "$name.$stamp.json") }
      }
      $archivedState = $archiveDir
      Write-Warning "Reusing run '$RunSlug' with -Force; the previous run state was archived under $archiveDir."
    }
  }

  $now = [DateTimeOffset]::UtcNow.ToString("o")
  $state = [ordered]@{
    schemaVersion = 1
    runSlug = $RunSlug
    objective = $Objective
    workflow = $Workflow
    status = "active"
    stage = "intake"
    deliveryBranch = $DeliveryBranch
    deliveryBranchSource = $deliveryBranchSource
    coordinatorControlBranch = $currentBranch
    coordinatorWorktree = $gitRoot
    orcaRunId = $(if ($OrcaRunId) { $OrcaRunId } else { $null })
    completedStages = @()
    pendingUserDecisions = @()
    createdAt = $now
    updatedAt = $now
  }
  Write-JsonFile (Join-Path $runDir "run-state.json") $state
  Write-JsonFile (Join-Path $runDir "branch-map.json") ([ordered]@{ schemaVersion = 1; branches = @{} })
  Write-JsonFile (Join-Path $runDir "task-map.json") ([ordered]@{ schemaVersion = 1; tasks = @{} })
  Write-JsonFile (Join-Path $runDir "degradation-events.json") ([ordered]@{ schemaVersion = 1; events = @() })

  $active = [ordered]@{
    schemaVersion = 1
    run = $RunSlug
    runDirectory = "runs/$RunSlug"
    orcaRunId = $(if ($OrcaRunId) { $OrcaRunId } else { $null })
    updatedAt = $now
  }
  Write-JsonFile $activePath $active

  $lockPath = Join-Path $devWork "coordinator-lock.json"
  if (Test-Path $lockPath) {
    $lock = Get-Content $lockPath -Raw | ConvertFrom-Json
    $lock.activeRun = $RunSlug
    $lock | Add-Member -NotePropertyName updatedAt -NotePropertyValue $now -Force
    Write-JsonFile $lockPath $lock
  }
} catch {
  # A failure must not leave a partial run directory that blocks a retry. Only a
  # directory created by this invocation is removed.
  if ($runDirCreated -and (Test-Path $runDir)) {
    Remove-Item -Recurse -Force $runDir -ErrorAction SilentlyContinue
  }
  throw
}

[ordered]@{
  ok = $true
  runSlug = $RunSlug
  runDirectory = $runDir
  deliveryBranch = $DeliveryBranch
  deliveryBranchSource = $deliveryBranchSource
  workflow = $Workflow
  archivedState = $archivedState
  statePath = (Join-Path $runDir "run-state.json")
} | ConvertTo-Json -Depth 10
