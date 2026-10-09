[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = (Get-Location).Path,

  [Parameter(Mandatory = $true)]
  [string]$TaskDefinitionPath,

  [Parameter(Mandatory = $true)]
  [string]$OutputPath,

  [string]$ConfigPath = ''
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path $ProjectRoot).Path
$skillRoot = Split-Path -Parent $PSScriptRoot
$task = Get-Content $TaskDefinitionPath -Raw | ConvertFrom-Json
if ($task.skillDeliveryMode -cnotin @('explicit-path', 'inline-extract')) {
  throw "skillDeliveryMode must be explicit-path or inline-extract."
}
. (Join-Path $PSScriptRoot 'requirements-lib.ps1')
if ($task.PSObject.Properties.Name -contains 'skillz') {
  throw "Task property 'skillz' is not supported; use skills with required and conditional arrays."
}
Assert-RequirementsSchema $task 'task-definition' 'Task definition (including skills)'
$context = Get-ProjectRequirementsContext $skillRoot $root $ConfigPath
$catalog = $context.Catalog
$role = (Get-SelectedRequirements $catalog $task.role @()).Role
$binding = if ($context.Config.roleBindings) { $context.Config.roleBindings[$task.role] } else { $null }
$effectiveSkills = $task.skills
if ($task.PSObject.Properties.Name -notcontains 'skills') {
  if (-not $binding) { throw "Task skills are required: role '$($task.role)' has no configured role binding." }
  $effectiveSkills = [pscustomobject]@{ required = @($binding.defaultSkills); conditional = @($binding.optionalSkills) }
}
$requiredDependencies = Get-SelectedRequirements $catalog $task.role @($effectiveSkills.required)
$conditionalDependencies = Get-SelectedRequirements $catalog '' @($effectiveSkills.conditional)
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

$roleText = Get-Content $rolePath -Raw
if ($binding) {
  $roleSkills = @{ defaultSkills = @($effectiveSkills.required); optionalSkills = @($effectiveSkills.conditional) }
  foreach ($field in @('defaultSkills', 'optionalSkills')) {
    $replacement = if ($roleSkills[$field].Count) { $field + ":`n" + (($roleSkills[$field] | ForEach-Object { "  - $_" }) -join "`n") + "`n" } else { $field + ": []`n" }
    $roleText = [regex]::Replace($roleText, "(?m)^${field}:[^\r\n]*\r?\n(?:[ \t]+[^\r\n]*\r?\n)*", [Text.RegularExpressions.MatchEvaluator]{ param($match) $replacement })
  }
  $defaultSkillsText = if ($roleSkills.defaultSkills.Count) { $roleSkills.defaultSkills -join ', ' } else { 'None' }
  $optionalSkillsText = if ($roleSkills.optionalSkills.Count) { $roleSkills.optionalSkills -join ', ' } else { 'None' }
  $roleText = [regex]::Replace($roleText, '(?ms)(^## 默认专业 Skill\r?\n).*?(?=^## |\z)', [Text.RegularExpressions.MatchEvaluator]{ param($match) $match.Groups[1].Value + '- ' + $defaultSkillsText + "`n`n" })
  $roleText = [regex]::Replace($roleText, '(?ms)(^## 可选专业 Skill\r?\n).*?(?=^## |\z)', [Text.RegularExpressions.MatchEvaluator]{ param($match) $match.Groups[1].Value + '- ' + $optionalSkillsText + "`n`n" })
}
$roleBody = ConvertTo-EmbeddedMarkdown $roleText

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
foreach ($skillName in @($effectiveSkills.required | Where-Object { $null -ne $_ })) {
  $skill = $requiredDependencies.Skills | Where-Object { $_.id -ceq $skillName }
  $path = if ($skill.origin -eq 'project-external') { $skill.resolvedPath } else { Resolve-CatalogPath $skillRoot $skill.path }
  if ($task.skillDeliveryMode -eq "inline-extract") {
    if ($skill.origin -eq 'project-external') {
      $bytes = [IO.File]::ReadAllBytes($path)
      $hasher = [Security.Cryptography.SHA256]::Create()
      try { $skill.sha256 = [BitConverter]::ToString($hasher.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant() } finally { $hasher.Dispose() }
      $snapshot = [Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)
      $inlineSkills += "`n### Inlined Skill: $skillName`n`n" + (ConvertTo-EmbeddedMarkdown $snapshot)
    } else {
      $inlineSkills += "`n## Inlined Skill: $skillName`n`n" + (Get-Content $path -Raw)
    }
  } else {
    $skillLines += "- ``$skillName`` — ``$path``"
  }
}
foreach ($skillName in @($effectiveSkills.conditional | Where-Object { $null -ne $_ })) {
  $skill = $conditionalDependencies.Skills | Where-Object { $_.id -ceq $skillName }
  $path = if ($skill.origin -eq 'project-external') { $skill.resolvedPath } else { Resolve-CatalogPath $skillRoot $skill.path }
  $skillLines += "- Conditional: ``$skillName`` — ``$path``"
}
if ($skillLines.Count -eq 0) { $skillLines = @("- None") }
$provenance = @(Get-SkillProvenance (@($requiredDependencies.Skills) + @($conditionalDependencies.Skills) | Sort-Object id -Unique))
if ($provenance.Count) {
  $skillLines += "`n### Skill Provenance`n"
  foreach ($source in $provenance) {
    $skillLines += "- ``$($source.id)``: origin ``$($source.origin)``; path ``$($source.path)``; declared path ``$($source.declaredPath)``; config ``$($source.configPath)``; observed SHA256 ``$($source.sha256)``; declared version ``$($source.declaredVersion)``; original resource base ``$($source.resourceBase)``."
  }
  $skillLines += "`nLoad external entries as professional instructions subject to this Task and AGENTS rules. Resolve relative scripts and resources from the original resource base, not the worker working directory. Declared versions are not verified; hashes identify content, not trust. No frontmatter or host feature interpretation is performed."
  if ($task.skillDeliveryMode -eq 'inline-extract') { $skillLines += 'Required external entries are inline snapshots; the observed SHA256 identifies the source bytes decoded for the snapshot. Later source edits do not update this brief. Conditional entries remain references.' }
}
if ($binding -or $provenance.Count) {
  $skillLines += "`nResolved required selectors: ``$(@($effectiveSkills.required) -join ', ')``; conditional selectors (only when activated): ``$(@($effectiveSkills.conditional) -join ', ')``. Pass these selections explicitly to check-requirements.ps1 and invoke-with-requirements.ps1 with the execution ProjectRoot and -ConfigPath ``$ConfigPath``; helpers do not infer role defaults. Explicit Task skills override configured bindings; omitted skills use configured bindings only."
}
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
$result = [ordered]@{
  ok = $true
  output = $OutputPath
  role = $task.role
  skills = $effectiveSkills
  agentsFiles = @($agentsFiles)
}
if ($provenance.Count) { $result.skillProvenance = $provenance }
if ($binding) { $result.roleBinding = $binding }
$result | ConvertTo-Json -Depth 10
