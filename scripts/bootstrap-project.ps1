[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = (Get-Location).Path,

  [Parameter(Mandatory = $false)]
  [switch]$ForceLock,

  [Parameter(Mandatory = $false)]
  [string]$DeliveryBranch,

  [Parameter(Mandatory = $false)]
  [switch]$AllowControlEqualsDelivery
)

$ErrorActionPreference = "Stop"

# --- host environment guard -------------------------------------------------
# Some hosts inject GIT_CONFIG_COUNT together with GIT_CONFIG_KEY_n pairs, then strip child
# variables whose names contain KEY/TOKEN/SECRET. The orphaned count makes every git call fail
# with: fatal: missing config key GIT_CONFIG_KEY_0. Drop the orphan so git still works.
if ($env:GIT_CONFIG_COUNT -and -not $env:GIT_CONFIG_KEY_0) {
  Remove-Item Env:GIT_CONFIG_COUNT -ErrorAction SilentlyContinue
}

function Invoke-Git {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )
  $output = & git -C $Root @Arguments 2>&1
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    throw ("git {0} failed (exit {1}) in {2}: {3}" -f ($Arguments -join " "), $exitCode, $Root, (($output | Out-String).Trim()))
  }
  return $output
}
# ---------------------------------------------------------------------------

function Write-JsonFile {
  param([string]$Path, [object]$Value)
  $json = $Value | ConvertTo-Json -Depth 20
  [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

$root = (Resolve-Path $ProjectRoot).Path
$skillRoot = Split-Path -Parent $PSScriptRoot
$templateAgents = Join-Path $skillRoot "templates\AGENTS.md"

try {
  $gitRoot = (Invoke-Git -Root $root -Arguments @("rev-parse", "--show-toplevel") | Select-Object -First 1)
} catch {
  throw "ProjectRoot is not inside a Git worktree: $root. git said: $($_.Exception.Message)"
}
$gitRoot = (Resolve-Path $gitRoot.Trim()).Path

# Validate the coordinator control branch BEFORE any write, so a detached HEAD cannot
# leave a half-initialized .dev-work behind.
$currentBranch = (Invoke-Git -Root $gitRoot -Arguments @("branch", "--show-current") | Select-Object -First 1)
$currentBranch = if ($currentBranch) { $currentBranch.Trim() } else { $null }
if (-not $currentBranch) {
  throw "Coordinator control worktree is in detached HEAD: $gitRoot. Check out the coordinator control branch before bootstrapping."
}

# delivery_branch resolution order, identical to create-run.ps1: an explicit -DeliveryBranch, then
# origin/HEAD, then init.defaultBranch (when that branch exists), then main, then master, then the
# current branch. The source is recorded in the shared vocabulary:
# user | origin-head | init-default | main | master | current.
$deliveryBranchSource = $null
if ($DeliveryBranch) {
  $deliveryBranchSource = "user"
} else {
  # Every probe below is a raw call that captures stderr instead of a throwing Invoke-Git call: a
  # missing ref exits 1 by design.
  # Output is assigned without a pipeline: piping a native call into Select-Object can stop that
  # process early and clobber $LASTEXITCODE, so the exit code is captured first.
  $originHead = & git -C $gitRoot symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>&1
  $originHeadExit = $LASTEXITCODE
  if ($originHeadExit -eq 0 -and $originHead) {
    $originHeadBranch = ("$originHead").Trim() -replace "^origin/", ""
    if ($originHeadBranch) { $DeliveryBranch = $originHeadBranch; $deliveryBranchSource = "origin-head" }
  }
  if (-not $deliveryBranchSource) {
    $initDefault = & git -C $gitRoot config --get init.defaultBranch 2>&1
    $initDefaultExit = $LASTEXITCODE
    if ($initDefaultExit -eq 0 -and $initDefault) {
      $initDefault = ("$initDefault").Trim()
      if ($initDefault) {
        $probe = & git -C $gitRoot show-ref --verify --quiet "refs/heads/$initDefault" 2>&1
        if ($LASTEXITCODE -eq 0) { $DeliveryBranch = $initDefault; $deliveryBranchSource = "init-default" }
      }
    }
  }
  if (-not $deliveryBranchSource) {
    foreach ($candidate in @("main", "master")) {
      $probe = & git -C $gitRoot show-ref --verify --quiet "refs/heads/$candidate" 2>&1
      if ($LASTEXITCODE -eq 0) { $DeliveryBranch = $candidate; $deliveryBranchSource = $candidate; break }
    }
  }
  if (-not $deliveryBranchSource) { $DeliveryBranch = $currentBranch; $deliveryBranchSource = "current" }
}

# Invariant 3: the coordinator control branch must differ from the delivery branch, otherwise
# the run bootstrapped from this control worktree is invalid as soon as it is created.
if ($currentBranch -eq $DeliveryBranch) {
  if (-not $AllowControlEqualsDelivery) {
    throw "Coordinator control branch '$currentBranch' equals the resolved delivery branch '$DeliveryBranch' (source: $deliveryBranchSource). Pass -DeliveryBranch <intended> to name the intended delivery branch (for example -DeliveryBranch develop), or pass -AllowControlEqualsDelivery to accept an invariant 3 violation."
  }
  Write-Warning "Invariant 3 is knowingly violated for this control worktree: coordinator control branch equals the resolved delivery branch '$DeliveryBranch'."
}

function Get-CoordinatorLiveness {
  param([string]$Handle)
  # Orca has no coordinator-lock primitive; the bound terminal handle is the closest
  # authoritative liveness signal. Returns live | dead | unknown.
  if (-not $Handle) { return "unknown" }
  if (-not (Get-Command orca -ErrorAction SilentlyContinue)) { return "unknown" }
  $raw = & orca terminal show --terminal $Handle --json 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $raw) { return "dead" }
  try { return $(if (($raw | ConvertFrom-Json).ok) { "live" } else { "dead" }) } catch { return "unknown" }
}

$agentsPath = Join-Path $gitRoot "AGENTS.md"
$createdAgents = $false
if (-not (Test-Path $agentsPath)) {
  Copy-Item $templateAgents $agentsPath
  $createdAgents = $true
}

$devWork = Join-Path $gitRoot ".dev-work"
$createdDevWork = $false
if (-not (Test-Path $devWork)) {
  New-Item -ItemType Directory -Path $devWork | Out-Null
  $createdDevWork = $true
}

$directories = @(
  "config",
  "runs",
  "runtime",
  "archive"
)
foreach ($dir in $directories) {
  $path = Join-Path $devWork $dir
  if (-not (Test-Path $path)) {
    New-Item -ItemType Directory -Path $path | Out-Null
  }
}

$manifestPath = Join-Path $devWork "manifest.json"
if (-not (Test-Path $manifestPath)) {
  Write-JsonFile $manifestPath ([ordered]@{
    schemaVersion = 1
    managedBy = "orca-project-delivery"
    createdAt = [DateTimeOffset]::UtcNow.ToString("o")
    projectRoot = $gitRoot
  })
}

# Local-only ignore rules. This does not modify the repository's tracked .gitignore.
$excludePathRaw = (Invoke-Git -Root $gitRoot -Arguments @("rev-parse", "--git-path", "info/exclude") | Select-Object -First 1).Trim()
if ([System.IO.Path]::IsPathRooted($excludePathRaw)) {
  $excludePath = $excludePathRaw
} else {
  $excludePath = Join-Path $gitRoot $excludePathRaw
}
$excludeDir = Split-Path -Parent $excludePath
if (-not (Test-Path $excludeDir)) {
  New-Item -ItemType Directory -Path $excludeDir -Force | Out-Null
}
if (-not (Test-Path $excludePath)) {
  New-Item -ItemType File -Path $excludePath | Out-Null
}
$excludeLines = Get-Content $excludePath -ErrorAction SilentlyContinue
foreach ($line in @("/AGENTS.md", "/.dev-work/")) {
  if ($excludeLines -notcontains $line) {
    Add-Content -Path $excludePath -Value $line -Encoding UTF8
  }
}

$lockPath = Join-Path $devWork "coordinator-lock.json"
$lockLiveness = "none"
if (Test-Path $lockPath) {
  $existing = Get-Content $lockPath -Raw | ConvertFrom-Json
  $existingStatus = if ($existing.PSObject.Properties["status"]) { "$($existing.status)" } else { "" }
  if ($existingStatus -eq "released") {
    # A released lock is a deliberate handover (references/coordinator-lock.md, Release step 4),
    # not a live holder: whoever released it may still own the terminal. Never refuse on liveness;
    # warn with the release audit trail, archive the old lock like the dead path, then take over.
    $lockLiveness = "released"
    $releaseFacts = @()
    foreach ($field in @("releasedAt", "releaseReason", "activeRun")) {
      $property = $existing.PSObject.Properties[$field]
      if ($property -and "$($property.Value)") { $releaseFacts += "$field=$($property.Value)" }
    }
    $releaseDetail = if ($releaseFacts.Count) { " (" + ($releaseFacts -join "; ") + ")" } else { "" }
    Write-Warning "Coordinator lock at $lockPath is released$releaseDetail. Taking over; the previous lock is archived."
  } else {
    $lockLiveness = Get-CoordinatorLiveness $existing.coordinatorTerminalHandle
    if (-not $ForceLock) {
      switch ($lockLiveness) {
        "live" { throw "A live coordinator is bound to $($existing.coordinatorTerminalHandle). Stop it, or run scripts/release-coordinator.ps1, before starting another." }
        "unknown" { throw "Coordinator lock exists at $lockPath and liveness is unverifiable. Verify the holder manually, then use -ForceLock (archives the old lock) or release-coordinator.ps1." }
        "dead" { Write-Warning "Stale coordinator lock detected (holder terminal is gone). Taking over; the previous lock is archived." }
      }
    }
  }
  $archiveName = "coordinator-lock-{0}.json" -f ([DateTimeOffset]::UtcNow.ToString("yyyyMMdd-HHmmss"))
  Copy-Item $lockPath (Join-Path (Join-Path $devWork "archive") $archiveName)
}

Write-JsonFile $lockPath ([ordered]@{
  schemaVersion = 1
  status = "active"
  coordinatorTerminalHandle = $env:ORCA_TERMINAL_HANDLE
  coordinatorWorktreeId = $env:ORCA_WORKTREE_ID
  hostProcessId = $PID
  livenessProbe = "orca terminal show --terminal <coordinatorTerminalHandle> --json"
  processId = $PID
  host = [Environment]::MachineName
  user = [Environment]::UserName
  coordinatorControlBranch = $currentBranch
  coordinatorWorktree = $gitRoot
  startedAt = [DateTimeOffset]::UtcNow.ToString("o")
  activeRun = $null
})

$result = [ordered]@{
  ok = $true
  projectRoot = $gitRoot
  coordinatorControlBranch = $currentBranch
  agentsPath = $agentsPath
  agentsCreated = $createdAgents
  devWorkPath = $devWork
  devWorkCreated = $createdDevWork
  manifestPath = $manifestPath
  lockPath = $lockPath
  lockLiveness = $lockLiveness
  gitExcludePath = $excludePath
  deliveryBranch = $DeliveryBranch
  deliveryBranchSource = $deliveryBranchSource
  controlEqualsDeliveryWaived = [bool]$AllowControlEqualsDelivery
}
$result | ConvertTo-Json -Depth 10
