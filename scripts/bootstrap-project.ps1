[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = (Get-Location).Path,

  [Parameter(Mandatory = $false)]
  [switch]$ForceLock,

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

# Resolve the candidate delivery branch in the same order as create-run.ps1 does: there is no
# explicit -DeliveryBranch here, so it is main, else master, else the current branch.
$deliveryBranch = $null
$deliveryBranchSource = $null
foreach ($candidate in @("main", "master")) {
  # Existence probe: a missing ref exits 1 by design, so this stays a raw call that captures
  # stderr instead of a throwing Invoke-Git call.
  $probe = & git -C $gitRoot show-ref --verify --quiet "refs/heads/$candidate" 2>&1
  if ($LASTEXITCODE -eq 0) { $deliveryBranch = $candidate; $deliveryBranchSource = $candidate; break }
}
if (-not $deliveryBranch) { $deliveryBranch = $currentBranch; $deliveryBranchSource = "current" }

# Invariant 3: the coordinator control branch must differ from the delivery branch, otherwise
# the run bootstrapped from this control worktree is invalid as soon as it is created.
if ($currentBranch -eq $deliveryBranch) {
  if (-not $AllowControlEqualsDelivery) {
    throw "Coordinator control branch equals the resolved delivery branch '$deliveryBranch'. Create/checkout a control branch first (for example 'coord/<run-slug>'), or pass -AllowControlEqualsDelivery to accept an invariant 3 violation."
  }
  Write-Warning "Invariant 3 is knowingly violated for this control worktree: coordinator control branch equals the resolved delivery branch '$deliveryBranch'."
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
  $lockLiveness = Get-CoordinatorLiveness $existing.coordinatorTerminalHandle
  if (-not $ForceLock) {
    switch ($lockLiveness) {
      "live" { throw "A live coordinator is bound to $($existing.coordinatorTerminalHandle). Stop it, or run scripts/release-coordinator.ps1, before starting another." }
      "unknown" { throw "Coordinator lock exists at $lockPath and liveness is unverifiable. Verify the holder manually, then use -ForceLock (archives the old lock) or release-coordinator.ps1." }
      "dead" { Write-Warning "Stale coordinator lock detected (holder terminal is gone). Taking over; the previous lock is archived." }
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
  deliveryBranch = $deliveryBranch
  deliveryBranchSource = $deliveryBranchSource
  controlEqualsDeliveryWaived = [bool]$AllowControlEqualsDelivery
}
$result | ConvertTo-Json -Depth 10
