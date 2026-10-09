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
$skillsRoot = Join-Path $skillRoot 'skills'
$task = Get-Content $TaskDefinitionPath -Raw | ConvertFrom-Json
if ($task.skillDeliveryMode -cnotin @('explicit-path', 'inline-extract')) {
  throw "skillDeliveryMode must be explicit-path or inline-extract."
}
. (Join-Path $PSScriptRoot 'requirements-lib.ps1')
$catalog = Get-RequirementsCatalog $skillRoot
$requiredDependencies = Get-SelectedRequirements $catalog $task.role @($task.skills.required)
$conditionalDependencies = Get-SelectedRequirements $catalog '' @($task.skills.conditional)
$role = $requiredDependencies.Role
$rolePath = Resolve-CatalogPath $skillRoot $role.path

# Prepare a whole Markdown document for embedding inside one of the assignment's own
# "## " sections: demote H1-H3 by two levels in a single pass (so a demoted heading is
# never demoted twice), and turn leading YAML front matter into a fenced ```yaml block so
# it renders as data instead of loose prose. Documents without front matter are unchanged
# apart from the heading levels.
function ConvertTo-EmbeddedMarkdown {
  param([string]$Text)

  $body = $Text
  $frontMatter = $null

  $frontMatterMatch = [regex]::Match($body, '(?s)\A---[ \t]*\r?\n(.*?)\r?\n---[ \t]*(?:\r?\n|\z)')
  if ($frontMatterMatch.Success) {
    $frontMatter = $frontMatterMatch.Groups[1].Value.TrimEnd("`r", "`n")
    $body = $body.Substring($frontMatterMatch.Length)
  }

  $body = [regex]::Replace($body, '(?m)^#{1,3} ', { param($match) '##' + $match.Value })
  $body = $body.TrimStart("`r", "`n")

  if ($null -ne $frontMatter) {
    # LF between the fence lines keeps the generated Markdown LF-only, matching the
    # embedded document bodies.
    $fenced = '```yaml' + "`n" + $frontMatter + "`n" + '```'
    $body = $fenced + "`n`n" + $body
  }

  return $body
}

$roleBody = ConvertTo-EmbeddedMarkdown (Get-Content $rolePath -Raw)

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
$requirementLines = @()
foreach ($group in @(@{ Label = 'Required'; Dependencies = $requiredDependencies }, @{ Label = 'Conditional (only when activated)'; Dependencies = $conditionalDependencies })) {
  foreach ($command in $group.Dependencies.Commands) { $requirementLines += "- $($group.Label) CLI: ``$command``" }
  foreach ($variable in @($group.Dependencies.Variables.Values | Sort-Object name)) { $requirementLines += "- $($group.Label) env: ``$($variable.name)`` — $($variable.purpose); secret: $($variable.secret)" }
  foreach ($api in $group.Dependencies.Apis) { $requirementLines += "- $($group.Label) API: ``$($api.name)`` — $($api.purpose); auth env: ``$($api.authEnv)`` (name check only)" }
}
$requirementBody = ''
if ($requirementLines.Count) {
  $requirementBody = @"
### Declared Requirements

$($requirementLines -join "`n")

On the execution host, run ``$(Join-Path $PSScriptRoot 'check-requirements.ps1') -ProjectRoot <explicit-project-root> -Role $($task.role) -Skills <selected-skill-ids>``. Add ``-ConfigPath <project-relative-config.json>`` only for an explicitly chosen non-secret config file.
File configuration is not current-process availability. Use ``$(Join-Path $PSScriptRoot 'invoke-with-requirements.ps1')`` with the same selectors plus ``-Executable <authorized-executable> -Arguments <argument-array>`` for an explicitly authorized local child command. Process environment takes precedence; only declared file variables are added to the child. No parent environment mutation or automatic coordinator configuration copying occurs.
Escalate missing dependencies by name; never print values. These helpers make no API calls and do not install tools. Child programs control their own output and may disclose values.
"@
}

# Drop the contract's duplicate title; the document already has its own
# "## Orca Worker Contract" heading. Remaining headings nest two levels deeper.
$workerContract = (Get-Content (Join-Path $skillRoot "references\worker-contract.md") -Raw)
$workerContract = $workerContract -replace '(?m)^# Orca Worker Contract\r?\n+', ''
$workerContract = ConvertTo-EmbeddedMarkdown $workerContract

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
# $seen stays case-insensitive purely for deduplication; $agentsFiles keeps the on-disk
# casing of each resolved AGENTS.md for the JSON output.
$agentsFiles = @()
$agentsSections = @()
foreach ($candidate in $agentsCandidates) {
  if (-not $candidate) { continue }
  if (-not (Test-Path $candidate)) { continue }
  $resolved = (Resolve-Path $candidate).Path
  $key = $resolved.ToLowerInvariant()
  if ($seen.ContainsKey($key)) { continue }
  $seen[$key] = $true
  $agentsFiles += (Get-Item -LiteralPath $resolved).FullName
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

$requirementBody

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
  agentsFiles = @($agentsFiles)
} | ConvertTo-Json -Depth 10
