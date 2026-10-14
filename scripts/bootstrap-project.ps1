#requires -Version 7.0
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

. (Join-Path $PSScriptRoot 'project-common.ps1')

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

$deliveryResolution = Resolve-DeliveryBranch -Root $gitRoot -CurrentBranch $currentBranch -DeliveryBranch $DeliveryBranch
$DeliveryBranch = $deliveryResolution.Branch
$deliveryBranchSource = $deliveryResolution.Source

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
  if (-not $Handle) { return "unknown" }
  if (-not (Get-Command orca -ErrorAction SilentlyContinue)) { return "unknown" }
  try {
    $raw = & orca terminal show --terminal $Handle --json 2>$null
    $probeExit = $LASTEXITCODE
    if (-not $raw) { return "unknown" }
    $parsed = $raw | ConvertFrom-Json
  } catch { return "unknown" }
  if ($parsed.ok -eq $false -and "$($parsed.error.code)" -eq "terminal_handle_stale") { return "dead" }
  if ($probeExit -eq 0 -and $parsed.ok -eq $true) { return "live" }
  return "unknown"
}

# Serialize takeover as well as creation so a contender cannot remove a newly acquired lock.
$mutexKey = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($gitRoot.ToUpperInvariant())))
$mutex = [Threading.Mutex]::new($false, "orca-coordinator-$mutexKey")
$acquired = $false
try {
  try { $acquired = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $acquired = $true }
  if (-not $acquired) { throw "Another bootstrap is acquiring the coordinator lock." }
$devWork = Join-Path $gitRoot ".dev-work"
$lockPath = Join-Path $devWork "coordinator-lock.json"
$lockLiveness = "none"
if (Test-Path $lockPath) {
  $existing = Get-Content -Encoding utf8 $lockPath -Raw | ConvertFrom-Json
  $existingStatus = if ($existing.PSObject.Properties["status"]) { "$($existing.status)" } else { "" }
  if ($existingStatus -eq "released") {
    # A released lock is a deliberate handover (references/coordinator-lock.md, Release step 4),
    # not a live holder: whoever released it may still own the terminal. Never refuse on liveness;
    # warn with the release audit trail, archive the old lock like the dead path, then take over.
    $lockLiveness = "released"
    $releaseRunField = $null
    $releaseRunValue = $null
    foreach ($field in @("previousActiveRun", "activeRun")) {
      $property = $existing.PSObject.Properties[$field]
      if ($property -and "$($property.Value)") { $releaseRunField = $field; $releaseRunValue = "$($property.Value)"; break }
    }
    $releaseFacts = @()
    foreach ($field in @("releasedAt", "releaseReason")) {
      $property = $existing.PSObject.Properties[$field]
      if ($property -and "$($property.Value)") { $releaseFacts += "$field=$($property.Value)" }
    }
    if ($releaseRunValue) { $releaseFacts += "$releaseRunField=$releaseRunValue" }
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
  $archiveDir = Join-Path $devWork "archive"
  if (-not (Test-Path $archiveDir)) { New-Item -ItemType Directory -Path $archiveDir | Out-Null }
  $archiveName = "coordinator-lock-{0}.json" -f ([DateTimeOffset]::UtcNow.ToString("yyyyMMdd-HHmmss"))
  Copy-Item $lockPath (Join-Path $archiveDir $archiveName)
  Remove-Item $lockPath -Force
}

$createdDevWork = $false
if (-not (Test-Path $devWork)) {
  New-Item -ItemType Directory -Path $devWork | Out-Null
  $createdDevWork = $true
}

# CreateNew prevents a competing writer from overwriting an acquired lock.
$lock = [ordered]@{
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
}
$lockJson = $lock | ConvertTo-Json -Depth 20
$lockBytes = [System.Text.UTF8Encoding]::new($false).GetBytes($lockJson + [Environment]::NewLine)
try {
  $lockStream = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
} catch [System.IO.IOException] {
  throw "Lost the coordinator lock race: another process created $lockPath while this bootstrap was acquiring it."
}
try {
  $lockStream.Write($lockBytes, 0, $lockBytes.Length)
} finally {
  $lockStream.Dispose()
}

# --- project writes, only after the lock is held ------------------------------------------
$agentsPath = Join-Path $gitRoot "AGENTS.md"
$createdAgents = $false
if (-not (Test-Path $agentsPath)) {
  Copy-Item $templateAgents $agentsPath
  $createdAgents = $true
}

foreach ($example in @(@{ Source = 'project.env.example'; Target = '.env.example' }, @{ Source = 'project-config.example.json'; Target = 'project-config.example.json' })) {
  $destination = Join-Path $gitRoot $example.Target
  if (-not (Test-Path -LiteralPath $destination)) {
    Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) "templates/$($example.Source)") -Destination $destination
  }
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
$excludeLines = Get-Content -Encoding utf8 $excludePath -ErrorAction SilentlyContinue
foreach ($line in @("/AGENTS.md", "/.dev-work/", "/.env")) {
  if ($excludeLines -notcontains $line) {
    Add-Content -Path $excludePath -Value $line -Encoding UTF8
  }
}

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
} finally {
  if ($acquired) { $mutex.ReleaseMutex() }
  $mutex.Dispose()
}
