[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = (Get-Location).Path,

  [Parameter(Mandatory = $false)]
  [switch]$ForceLock
)

$ErrorActionPreference = "Stop"

function Write-JsonFile {
  param([string]$Path, [object]$Value)
  $json = $Value | ConvertTo-Json -Depth 20
  [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

$root = (Resolve-Path $ProjectRoot).Path
$skillRoot = Split-Path -Parent $PSScriptRoot
$templateAgents = Join-Path $skillRoot "templates\AGENTS.md"

$gitRoot = (& git -C $root rev-parse --show-toplevel 2>$null)
if (-not $gitRoot) {
  throw "ProjectRoot is not inside a Git worktree: $root"
}
$gitRoot = (Resolve-Path $gitRoot.Trim()).Path

# Validate the coordinator control branch BEFORE any write, so a detached HEAD cannot
# leave a half-initialized .dev-work behind.
$currentBranch = (& git -C $gitRoot branch --show-current 2>$null)
$currentBranch = if ($currentBranch) { $currentBranch.Trim() } else { $null }
if (-not $currentBranch) {
  throw "Coordinator control worktree is in detached HEAD: $gitRoot. Check out the coordinator control branch before bootstrapping."
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
$excludePathRaw = (& git -C $gitRoot rev-parse --git-path info/exclude).Trim()
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
}
$result | ConvertTo-Json -Depth 10
