[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = (Get-Location).Path
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
$devWork = Join-Path $gitRoot ".dev-work"
$activePath = Join-Path $devWork "active-run.json"
if (-not (Test-Path $activePath)) { throw "No active run." }

$active = Get-Content $activePath -Raw | ConvertFrom-Json
$runDir = Join-Path $devWork ($active.runDirectory -replace "/", "\")
$assignmentsDir = Join-Path $runDir "assignments"
$worktreeText = (Invoke-Git -Root $gitRoot -Arguments @("worktree", "list", "--porcelain")) -join "`n"
$branchLines = Invoke-Git -Root $gitRoot -Arguments @("for-each-ref", "--format=%(refname:short)|%(objectname)", "refs/heads")

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
Write-JsonFile $target $output -Depth 30
$output | ConvertTo-Json -Depth 30
