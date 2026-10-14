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

# --- host environment guard -------------------------------------------------
# Some hosts inject GIT_CONFIG_COUNT together with GIT_CONFIG_KEY_n pairs, then strip child
# variables whose names contain KEY/TOKEN/SECRET. The orphaned count makes every git call fail
# with: fatal: missing config key GIT_CONFIG_KEY_0. Drop the orphan so git still works.
if ($env:GIT_CONFIG_COUNT -and -not $env:GIT_CONFIG_KEY_0) {
  Remove-Item Env:GIT_CONFIG_COUNT -ErrorAction SilentlyContinue
}

. (Join-Path $PSScriptRoot 'project-common.ps1')

$root = (Resolve-Path $ProjectRoot).Path
try {
  $gitRoot = (Invoke-Git -Root $root -Arguments @("rev-parse", "--show-toplevel") | Select-Object -First 1)
} catch {
  throw "Not inside a Git worktree. git said: $($_.Exception.Message)"
}
$gitRoot = (Resolve-Path $gitRoot.Trim()).Path

# Validate the coordinator control branch before any write, so a detached HEAD cannot
# leave a partial run directory behind.
$currentBranch = (Invoke-Git -Root $gitRoot -Arguments @("branch", "--show-current") | Select-Object -First 1)
$currentBranch = if ($currentBranch) { $currentBranch.Trim() } else { $null }
if (-not $currentBranch) {
  throw "Cannot create a run from a detached HEAD: $gitRoot. Check out the coordinator control branch first."
}

$deliveryResolution = Resolve-DeliveryBranch -Root $gitRoot -CurrentBranch $currentBranch -DeliveryBranch $DeliveryBranch
$DeliveryBranch = $deliveryResolution.Branch
$deliveryBranchSource = $deliveryResolution.Source

# Invariant 3: the control branch must differ from delivery_branch. bootstrap-project.ps1 refuses in
# this case; create-run only warns, because refusing here would strand an already-bootstrapped
# worktree. The advice is the same: name the intended delivery branch explicitly.
if ($DeliveryBranch -eq $currentBranch) {
  Write-Warning "Coordinator control branch '$currentBranch' equals the resolved delivery branch '$DeliveryBranch' (source: $deliveryBranchSource). Pass -DeliveryBranch <intended> to name the intended delivery branch (for example -DeliveryBranch develop)."
}

$devWork = Join-Path $gitRoot ".dev-work"
if (-not (Test-Path (Join-Path $devWork "manifest.json"))) {
  throw ".dev-work is not initialized. Run bootstrap-project.ps1 first."
}

$activePath = Join-Path $devWork "active-run.json"
$previousActive = $null
if (Test-Path $activePath) {
  $previousActive = Get-Content $activePath -Raw | ConvertFrom-Json
  if ($previousActive.run -and -not $Force) {
    throw "An active run already exists: $($previousActive.run). Close it or use -Force only after reconciliation."
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

# A run slug is a single directory name: reject separators and traversal outright, then also verify
# the fully resolved path (defense in depth). Both checks run before anything is created.
if ($RunSlug -notmatch "^[A-Za-z0-9][A-Za-z0-9._-]*$") {
  throw "Invalid -RunSlug '$RunSlug'. A run slug must match ^[A-Za-z0-9][A-Za-z0-9._-]*$ and must not contain path separators or traversal."
}

$runsRoot = Join-Path $devWork "runs"
$runDir = Join-Path $runsRoot $RunSlug
$runsRootPrefix = [System.IO.Path]::GetFullPath($runsRoot).TrimEnd([char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)) + [System.IO.Path]::DirectorySeparatorChar
$resolvedRunDir = [System.IO.Path]::GetFullPath($runDir)
if (-not $resolvedRunDir.StartsWith($runsRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Refusing to create a run outside '$runsRoot': -RunSlug '$RunSlug' resolves to '$resolvedRunDir'."
}
$lockPath = Join-Path $devWork "coordinator-lock.json"
if (Test-Path $lockPath) {
  $lock = Get-Content $lockPath -Raw | ConvertFrom-Json
  if ($lock.coordinatorTerminalHandle -and $env:ORCA_TERMINAL_HANDLE -and $lock.coordinatorTerminalHandle -ne $env:ORCA_TERMINAL_HANDLE) {
    Write-Warning "Coordinator lock belongs to '$($lock.coordinatorTerminalHandle)', but caller is '$env:ORCA_TERMINAL_HANDLE'; run state will be updated."
  }
}

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
    "dispatch-receipts",
    "dispatch-waves",
    "handoffs",
    "reconnaissance",
    "audits",
    "designs",
    "plans",
    "task-briefs",
    "worker-reports",
    "reviews",
    "verification",
    "evidence",
    "evidence/git"
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
      foreach ($name in @("run-state", "branch-map", "task-map", "degradation-events", "reconciliation")) {
        $src = Join-Path $runDir "$name.json"
        if (Test-Path $src) { Copy-Item $src (Join-Path $archiveDir "$name.$stamp.json") }
      }
      $archivedState = $archiveDir
      # Nothing under the run directory is deleted: everything that is not the archive itself stays
      # in place next to the reset run state, so the warning can say how much is preserved. Both
      # paths are provider-normalized so the prefix comparison cannot be defeated by path spelling.
      $archivePrefix = (Resolve-Path $archiveDir).Path.TrimEnd([char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)) + [System.IO.Path]::DirectorySeparatorChar
      $preservedCount = @(Get-ChildItem -Path (Resolve-Path $runDir).Path -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.FullName.StartsWith($archivePrefix, [System.StringComparison]::OrdinalIgnoreCase) }).Count
      Write-Warning "Reusing run '$RunSlug' with -Force; the previous state was archived under $archiveDir ($preservedCount other files preserved)."
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
    stageDecisions = @{}
    pendingUserDecisions = @()
    createdAt = $now
    updatedAt = $now
  }
  Write-JsonFile (Join-Path $runDir "run-state.json") $state -Depth 30
  Write-JsonFile (Join-Path $runDir "branch-map.json") ([ordered]@{ schemaVersion = 1; branches = @{} }) -Depth 30
  Write-JsonFile (Join-Path $runDir "task-map.json") ([ordered]@{ schemaVersion = 1; tasks = @{} }) -Depth 30
  Write-JsonFile (Join-Path $runDir "degradation-events.json") ([ordered]@{ schemaVersion = 1; events = @() }) -Depth 30

  $active = [ordered]@{
    schemaVersion = 1
    run = $RunSlug
    runDirectory = "runs/$RunSlug"
    orcaRunId = $(if ($OrcaRunId) { $OrcaRunId } else { $null })
    updatedAt = $now
  }
  if ($Force -and $previousActive.run -and $previousActive.run -ne $RunSlug) {
    $archiveDir = Join-Path $devWork "archive"
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    $archiveName = "active-run-{0}.json" -f ([DateTimeOffset]::UtcNow.ToString("yyyyMMdd-HHmmssfffffff"))
    Copy-Item $activePath (Join-Path $archiveDir $archiveName)
    Write-Warning "Replacing active run '$($previousActive.run)' with '$RunSlug'; the previous active-run pointer was archived under $archiveDir and the old run remains on disk."
  }
  Write-JsonFile $activePath $active -Depth 30

  $lockPath = Join-Path $devWork "coordinator-lock.json"
  if (Test-Path $lockPath) {
    $lock = Get-Content $lockPath -Raw | ConvertFrom-Json
    $lock.activeRun = $RunSlug
    $lock | Add-Member -NotePropertyName updatedAt -NotePropertyValue $now -Force
    Write-JsonFile $lockPath $lock -Depth 30
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
