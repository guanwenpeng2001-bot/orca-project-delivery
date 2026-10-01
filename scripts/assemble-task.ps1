[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = (Get-Location).Path,

  [Parameter(Mandatory = $true)]
  [string]$TaskDefinitionPath,

  [Parameter(Mandatory = $true)]
  [string]$OutputPath
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path $ProjectRoot).Path
$skillRoot = Split-Path -Parent $PSScriptRoot
$skillsRoot = Split-Path -Parent $skillRoot
$task = Get-Content $TaskDefinitionPath -Raw | ConvertFrom-Json
$catalog = Get-Content (Join-Path $skillRoot "roles\catalog.json") -Raw | ConvertFrom-Json
$role = $catalog.roles | Where-Object { $_.id -eq $task.role } | Select-Object -First 1
if (-not $role) { throw "Unknown role: $($task.role)" }

$rolePath = Join-Path $skillRoot ($role.path -replace "/", "\")
# Demote the role document's H1 so the embedded contract nests under "## Primary Role".
$roleBody = (Get-Content $rolePath -Raw) -replace '(?m)^# ', '### '

function To-Bullets {
  param($Items)
  if (-not $Items -or @($Items).Count -eq 0) { return "- None" }
  return (@($Items) | ForEach-Object { "- $_" }) -join [Environment]::NewLine
}

function Format-OrNull {
  param($Value, [string]$Fallback = "(assigned at dispatch)")
  if ($null -eq $Value) { return $Fallback }
  $text = [string]$Value
  if ($text.Trim().Length -eq 0) { return $Fallback }
  return $text
}

$skillLines = @()
$inlineSkills = @()
foreach ($skillName in @($task.skills.required)) {
  $path = Join-Path (Join-Path $skillsRoot $skillName) "SKILL.md"
  if (-not (Test-Path $path)) { throw "Required Skill not found: $skillName ($path)" }
  if ($task.skillDeliveryMode -eq "inline-extract") {
    $inlineSkills += "`n## Inlined Skill: $skillName`n`n" + (Get-Content $path -Raw)
  } else {
    $skillLines += "- ``$skillName`` — ``$path``"
  }
}
foreach ($skillName in @($task.skills.conditional)) {
  $path = Join-Path (Join-Path $skillsRoot $skillName) "SKILL.md"
  if (-not (Test-Path $path)) { throw "Conditional Skill not found: $skillName ($path)" }
  $skillLines += "- Conditional: ``$skillName`` — ``$path``"
}
if ($skillLines.Count -eq 0) { $skillLines = @("- None") }

# Demote the contract's H1 and drop its duplicate title; the document already has
# its own "## Orca Worker Contract" heading.
$workerContract = (Get-Content (Join-Path $skillRoot "references\worker-contract.md") -Raw)
$workerContract = $workerContract -replace '(?m)^# Orca Worker Contract\r?\n+', ''

# Resolve AGENTS files. Explicit Task list wins; otherwise include the coordinator/project
# root and the task worktree root when present. Deduplicate by canonical path.
$agentsCandidates = @()
if ($task.PSObject.Properties.Name -contains "applicableAgentsFiles" -and @($task.applicableAgentsFiles).Count -gt 0) {
  $agentsCandidates += @($task.applicableAgentsFiles)
} else {
  $agentsCandidates += (Join-Path $root "AGENTS.md")
  if ($task.branch.worktree) {
    $agentsCandidates += (Join-Path $task.branch.worktree "AGENTS.md")
  }
}
$seen = @{}
$agentsSections = @()
foreach ($candidate in $agentsCandidates) {
  if (-not $candidate) { continue }
  if (-not (Test-Path $candidate)) { continue }
  $resolved = (Resolve-Path $candidate).Path
  $key = $resolved.ToLowerInvariant()
  if ($seen.ContainsKey($key)) { continue }
  $seen[$key] = $true
  $agentsSections += @"
## AGENTS source: ``$resolved``

$(Get-Content $resolved -Raw)
"@
}
if ($agentsSections.Count -eq 0) {
  throw "No applicable AGENTS.md was found. Run bootstrap-project.ps1 or provide applicableAgentsFiles."
}
$agentsBody = $agentsSections -join "`n`n"

$branch = $task.branch
$artifacts = $task.artifacts
$orca = $task.orca

$content = @"
# Assignment: $($task.title)

## Task Objective

$($task.objective)

## Primary Role

- Role: ``$($task.role)``
- Role source: ``$rolePath``

$roleBody

## Required and Conditional Skills

Skill delivery mode: ``$($task.skillDeliveryMode)``

$($skillLines -join [Environment]::NewLine)

$($inlineSkills -join [Environment]::NewLine)

## Inputs and Dependencies

$(To-Bullets $task.inputs)

## Allowed Scope

$(To-Bullets $task.allowedScope)

## Forbidden Scope

$(To-Bullets $task.forbiddenScope)

## Branch and Worktree Contract

- Delivery branch: ``$($branch.delivery)``
- Base branch: ``$($branch.base)``
- Work branch: ``$($branch.work)``
- Worktree: ``$($branch.worktree)``
- Merge target: ``$($branch.mergeTarget)``
- Do not merge the branch yourself.

## Process Artifact Contract

- Report path: ``$($artifacts.reportPath)``
- Evidence path: ``$($artifacts.evidencePath)``
- Do not modify `.dev-work` global state or another Task's artifacts.
- If the sandbox cannot write the shared path, return the complete report to the coordinator.

## Acceptance Criteria

$(To-Bullets $task.acceptance)

## Verification

$(To-Bullets $task.tests)

## Orca Worker Contract

$workerContract

## Orca Assignment Identity

- Run: ``$(Format-OrNull $orca.runId)``
- Task: ``$(Format-OrNull $orca.taskId)``
- Dispatch: ``$(Format-OrNull $orca.dispatchId)``

Use the injected Orca preamble as authority if these placeholders differ.

---

# Applicable Project Rules — AGENTS.md

$agentsBody
"@

$outParent = Split-Path -Parent $OutputPath
if ($outParent -and -not (Test-Path $outParent)) {
  New-Item -ItemType Directory -Path $outParent -Force | Out-Null
}
[System.IO.File]::WriteAllText($OutputPath, $content, [System.Text.UTF8Encoding]::new($false))
[ordered]@{
  ok = $true
  output = $OutputPath
  role = $task.role
  skills = $task.skills
  agentsFiles = @($seen.Keys)
} | ConvertTo-Json -Depth 10
