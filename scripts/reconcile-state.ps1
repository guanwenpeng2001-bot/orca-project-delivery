[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = (Get-Location).Path
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
$devWork = Join-Path $gitRoot ".dev-work"
$activePath = Join-Path $devWork "active-run.json"
if (-not (Test-Path $activePath)) { throw "No active run." }

$active = Get-Content $activePath -Raw | ConvertFrom-Json
$runDir = Join-Path $devWork ($active.runDirectory -replace "/", "\")
$assignmentsDir = Join-Path $runDir "assignments"
$worktreeText = (& git -C $gitRoot worktree list --porcelain) -join "`n"
$branchLines = (& git -C $gitRoot for-each-ref --format="%(refname:short)|%(objectname)" refs/heads)

# Exact indexes. Substring matching on the porcelain text reports a branch as
# registered when only a longer sibling branch (scout/csv vs scout/csv-export) has a
# worktree, so compare real values instead of a substring.
$branches = @{}
foreach ($line in $branchLines) {
  $parts = $line -split '\|', 2
  if ($parts.Count -eq 2) { $branches[$parts[0].Trim()] = $parts[1].Trim() }
}
$registeredWorktreeBranches = @()
foreach ($line in ($worktreeText -split "`n")) {
  if ($line -match '^branch refs/heads/(.+?)\s*$') { $registeredWorktreeBranches += $Matches[1] }
}

$rows = @()
if (Test-Path $assignmentsDir) {
  foreach ($file in Get-ChildItem $assignmentsDir -Filter *.json) {
    try {
      $assignment = Get-Content $file.FullName -Raw | ConvertFrom-Json
      $workBranch = $assignment.branch.work
      $branchExists = $(if ($workBranch) { $branches.ContainsKey($workBranch) } else { $false })
      $worktreePath = $assignment.branch.worktree
      $rows += [ordered]@{
        taskKey = $assignment.taskKey
        assignmentPath = $file.FullName
        recordedStatus = $assignment.status
        branch = $workBranch
        branchExists = $branchExists
        recordedWorktree = $worktreePath
        worktreeExists = $(if ($worktreePath) { Test-Path $worktreePath } else { $false })
        worktreeRegistered = $(if ($workBranch) { $registeredWorktreeBranches -contains $workBranch } else { $false })
        reportExists = $(if ($assignment.artifacts.reportPath) { Test-Path $assignment.artifacts.reportPath } else { $false })
        orcaRunId = $assignment.orca.runId
        orcaTaskId = $assignment.orca.taskId
        dispatchId = $assignment.orca.dispatchId
        note = "Git/file reconciliation only. Use current orchestration Skill for authoritative Orca lifecycle state."
      }
    } catch {
      $rows += [ordered]@{
        assignmentPath = $file.FullName
        error = $_.Exception.Message
      }
    }
  }
}

$output = [ordered]@{
  schemaVersion = 1
  run = $active.run
  reconciledAt = [DateTimeOffset]::UtcNow.ToString("o")
  projectRoot = $gitRoot
  assignments = $rows
}
$target = Join-Path $runDir "reconciliation.json"
Write-JsonFile $target $output
$output | ConvertTo-Json -Depth 30
