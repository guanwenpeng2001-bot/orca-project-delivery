#requires -Version 7.0
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
$task = Get-Content -Encoding utf8 $TaskDefinitionPath -Raw | ConvertFrom-Json
if ($task.skillDeliveryMode -cnotin @('explicit-path', 'inline-extract')) {
  throw "skillDeliveryMode must be explicit-path or inline-extract."
}
. (Join-Path $PSScriptRoot 'requirements-lib.ps1')
if ($task.PSObject.Properties.Name -contains 'skillz') {
  throw "Task property 'skillz' is not supported; use skills with required and conditional arrays."
}
Assert-RequirementsSchema $task 'task-definition' 'Task definition (including skills)'

# ------------------------------------------------------- package command checks
# A brief that names a package script with a parameter the script does not declare sends the
# worker into a guaranteed failure (observed: "scripts/verify-package.ps1 -Run nightly"). Check
# every scripts/<name>.ps1 mention in acceptance and tests against the real param blocks;
# mentions of paths outside the package and of variables are left alone. A mention that cannot
# be parsed as a command is checked with a per-line fallback instead of being trusted.
function Resolve-PackageScriptPath {
  param([string]$Name)
  if ($task.branch.worktree -and (Test-Path -LiteralPath $task.branch.worktree -PathType Container)) {
    $candidate = Join-Path $task.branch.worktree "scripts/$Name"
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return (Resolve-Path -LiteralPath $candidate).Path }
  }
  return Join-Path $PSScriptRoot $Name
}
$scriptInfoCache = @{}
function Get-PackageScriptInfo {
  param([string]$Name)
  if ($scriptInfoCache.ContainsKey($Name)) { return $scriptInfoCache[$Name] }
  $path = Resolve-PackageScriptPath $Name
  $info = [pscustomobject]@{
    Path = $path
    Exists = (Test-Path -LiteralPath $path -PathType Leaf)
    Parameters = @()
    CmdletBinding = $false
  }
  if ($info.Exists) {
    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -eq 0 -and $ast.ParamBlock) {
      $info.Parameters = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
      foreach ($attribute in @($ast.ParamBlock.Attributes)) {
        if ($attribute.TypeName.Name -eq 'CmdletBinding') { $info.CmdletBinding = $true }
      }
    }
  }
  $scriptInfoCache[$Name] = $info
  return $info
}

$commandProblems = [Collections.Generic.List[string]]::new()
# Common parameters only. WhatIf/Confirm additionally require SupportsShouldProcess, so accepting
# them unconditionally would let a brief name a flag that still fails at run time.
$commonParameters = @([Management.Automation.PSCmdlet]::CommonParameters)

function Test-BriefCommand {
  param([string]$Text, [string]$Label)
  if (-not $Text) { return }
  $vet = $Text
  $verbatim = $vet.IndexOf('--%')
  if ($verbatim -ge 0) { $vet = $vet.Substring(0, $verbatim) }
  $tokens = $null
  $parseErrors = $null
  $ast = [Management.Automation.Language.Parser]::ParseInput($vet, [ref]$tokens, [ref]$parseErrors)
  $mentions = @()
  if ($parseErrors.Count -eq 0) {
    foreach ($command in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true)) {
      $elements = @($command.CommandElements)
      for ($index = 0; $index -lt $elements.Count; $index++) {
        $text = $elements[$index].Extent.Text.Trim("'", '"')
        $name = $null
        $match = [regex]::Match($text, '^scripts[\\/]([A-Za-z0-9._-]+\.ps1)$')
        if ($match.Success) {
          $name = $match.Groups[1].Value
        } elseif (($text -match '^[A-Za-z0-9._-]+\.ps1$') -and (Test-Path -LiteralPath (Resolve-PackageScriptPath $text) -PathType Leaf)) {
          $name = $text
        }
        if (-not $name) { continue }
        $flags = @()
        for ($next = $index + 1; $next -lt $elements.Count; $next++) {
          if ($elements[$next] -is [Management.Automation.Language.CommandParameterAst]) {
            $flags += $elements[$next].ParameterName
          }
        }
        $mentions += [pscustomobject]@{ Name = $name; Flags = $flags }
      }
    }
  } else {
    foreach ($line in ($vet -split '\r?\n')) {
      foreach ($lineMatch in [regex]::Matches($line, '(?:^|[\s''"(])scripts[\\/]([A-Za-z0-9._-]+\.ps1)')) {
        $tail = $line.Substring($lineMatch.Index + $lineMatch.Length)
        $flags = @([regex]::Matches($tail, '(?<![\w-])-([A-Za-z][A-Za-z0-9]*)') | ForEach-Object { $_.Groups[1].Value })
        $mentions += [pscustomobject]@{ Name = $lineMatch.Groups[1].Value; Flags = $flags }
      }
    }
  }
  foreach ($mention in $mentions) {
    $info = Get-PackageScriptInfo $mention.Name
    if (-not $info.Exists) {
      $commandProblems.Add("$Label`: scripts/$($mention.Name) does not exist in the package scripts directory.")
      continue
    }
    foreach ($flag in $mention.Flags) {
      if ($info.Parameters -contains $flag) { continue }
      if ($info.CmdletBinding -and ($commonParameters -contains $flag)) { continue }
      $declared = if ($info.Parameters.Count) { $info.Parameters -join ', ' } else { '(none)' }
      $commandProblems.Add("$Label`: scripts/$($mention.Name) has no parameter '-$flag' (declared: $declared).")
    }
  }
}

foreach ($group in @(
  @{ Label = 'acceptance'; Items = @($task.acceptance) },
  @{ Label = 'tests'; Items = @($task.tests) }
)) {
  foreach ($item in $group.Items) {
    if ($item -is [string]) { Test-BriefCommand -Text $item -Label $group.Label }
  }
}
if ($commandProblems.Count) {
  throw ("Task definition names package commands that cannot run:`n" + ($commandProblems -join "`n"))
}
$agentSectionSelectors = @($task.agentsSections | Where-Object { $_ })
$usesBriefOptions = ($task.taskKind -eq 'read-only') -or ($task.briefProfile -eq 'review') -or ($agentSectionSelectors.Count -gt 0)
$briefNewLine = if ($usesBriefOptions) { "`n" } else { [Environment]::NewLine }
$isReview = $task.briefProfile -eq 'review'
$includeRole = -not $isReview -or $task.reviewIncludes -contains 'role'
$includeSkills = -not $isReview -or $task.reviewIncludes -contains 'skills'
$includeRequirements = -not $isReview -or $task.reviewIncludes -contains 'requirements'
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

$roleText = Get-Content -Encoding utf8 $rolePath -Raw
$roleNotes = @()
if ($roleText -notmatch '(?m)^## 默认专业 Skill\r?\n') {
  $packageRoles = Get-Content -Encoding utf8 (Join-Path $skillRoot 'roles/catalog.json') -Raw | ConvertFrom-Json
  $packageRole = $packageRoles.roles | Where-Object { $_.id -ceq $task.role }
  if (@($packageRole.defaultSkills).Count) {
    throw "Role '$($task.role)' is missing required default-skill section '## 默认专业 Skill': $rolePath"
  }
  $roleNotes += "Role '$($task.role)': default-skill substitution skipped because catalog defaultSkills is empty and the section is absent."
}
if ($binding) {
  $roleSkills = @{ defaultSkills = @($effectiveSkills.required); optionalSkills = @($effectiveSkills.conditional) }
  foreach ($field in @('defaultSkills', 'optionalSkills')) {
    $replacement = if ($roleSkills[$field].Count) { $field + ":`n" + (($roleSkills[$field] | ForEach-Object { "  - $_" }) -join "`n") + "`n" } else { $field + ": []`n" }
    if ($usesBriefOptions) { $replacement = '' }
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
  return (@($Items) | ForEach-Object { "- $_" }) -join $briefNewLine
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
      $inlineSkills += "`n## Inlined Skill: $skillName`n`n" + (Get-Content -Encoding utf8 $path -Raw)
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

On the execution host, run ``$(Resolve-PackageScriptPath 'check-requirements.ps1') -ProjectRoot <explicit-project-root> -Role $($task.role) -Skills <selected-skill-ids>``. Add ``-ConfigPath <project-relative-config.json>`` only for an explicitly chosen non-secret config file.
File configuration is not current-process availability. Use ``$(Resolve-PackageScriptPath 'invoke-with-requirements.ps1')`` with the same selectors plus ``-Executable <authorized-executable> -Arguments <argument-array>`` for an explicitly authorized local child command. Process environment takes precedence; only declared file variables are added to the child. No parent environment mutation or automatic coordinator configuration copying occurs.
Escalate missing dependencies by name; never print values. These helpers make no API calls and do not install tools. Child programs control their own output and may disclose values.
"@
}

# Drop the contract's duplicate title; the document already has its own
# "## Orca Worker Contract" heading. Remaining headings nest two levels deeper.
$workerContract = (Get-Content -Encoding utf8 (Join-Path $skillRoot "references\worker-contract.md") -Raw)
$workerContract = $workerContract -replace '(?m)^# Orca Worker Contract\r?\n+', ''
if ($task.taskKind -eq 'read-only') {
  $workerContract = $workerContract -replace '(?m)^- Source/deliverable Tasks:[^\r\n]*\r?\n(?:[ \t]+[^\r\n]*\r?\n)*', ''
}
$workerContract = ConvertTo-EmbeddedMarkdown $workerContract

# Resolve AGENTS files. Explicit Task list wins; otherwise include the coordinator/project
# root and the task worktree root when present. Deduplicate by canonical path.
function Select-AgentsSections {
  param([string]$Text, [string[]]$Selectors, [hashtable]$Matched)

  $headings = @()
  $fence = ''
  foreach ($line in [regex]::Matches($Text, '[^\r\n]*(?:\r?\n|\z)')) {
    $value = $line.Value.TrimEnd("`r", "`n")
    if ($fence) {
      if ($value -match ('^ {0,3}' + [regex]::Escape($fence.Substring(0, 1)) + '{' + $fence.Length + ',}[ \t]*$')) { $fence = '' }
      continue
    }
    if ($value -match '^ {0,3}(`{3,}|~{3,})') { $fence = $Matches[1]; continue }
    if ($value -match '^ {0,3}(#{1,6})(?:[ \t]+(.*?)|[ \t]*)$') {
      $level = $Matches[1].Length
      $title = ($Matches[2] -replace '[ \t]+#+[ \t]*$', '').Trim()
      $headings += [pscustomobject]@{ Start = $line.Index; Level = $level; Title = $title }
    }
  }
  $ranges = @()
  for ($index = 0; $index -lt $headings.Count; $index++) {
    $heading = $headings[$index]
    $aliases = @($heading.Title)
    if ($heading.Title -match '^(\d+(?:\.\d+)*)(?:[.)、]|\s)\s*(.*)$') { $aliases += $Matches[1]; $aliases += $Matches[2] }
    $selected = $false
    foreach ($selector in $Selectors) {
      if ($aliases -ccontains $selector) { $Matched[$selector] = $true; $selected = $true }
    }
    if (-not $selected) { continue }
    $end = $Text.Length
    for ($next = $index + 1; $next -lt $headings.Count; $next++) {
      if ($headings[$next].Level -le $heading.Level) { $end = $headings[$next].Start; break }
    }
    $ranges += [pscustomobject]@{ Start = $heading.Start; End = $end }
  }
  $selectedText = ''
  $previousEnd = 0
  foreach ($range in $ranges) {
    if ($range.Start -lt $previousEnd) { continue }
    $selectedText += $Text.Substring($range.Start, $range.End - $range.Start)
    $previousEnd = $range.End
  }
  return $selectedText
}

$matchedAgentsSections = @{}
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
  $agentsText = Get-Content -Encoding utf8 $resolved -Raw
  if ($task.agentsSections -and @($task.agentsSections).Count -gt 0) {
    $agentsText = Select-AgentsSections $agentsText $task.agentsSections $matchedAgentsSections
    if (-not $agentsText) { continue }
  }
  $agentsSections += @"
## AGENTS source: ``$resolved``

$agentsText
"@
}
foreach ($selector in @($task.agentsSections | Where-Object { $_ })) {
  if (-not $matchedAgentsSections.ContainsKey($selector)) { throw "AGENTS.md section '$selector' was not found in applicable AGENTS files." }
}
if ($agentsSections.Count -eq 0) {
  throw "No applicable AGENTS.md was found. Run bootstrap-project.ps1 or provide applicableAgentsFiles."
}
$agentsBody = $agentsSections -join "`n`n"

$branch = $task.branch
$artifacts = $task.artifacts
$orca = $task.orca

$roleSection = @"
## Primary Role

- Role: ``$($task.role)``
- Role source: ``$rolePath``

$roleBody

"@
$skillsSection = @"
## Required and Conditional Skills

Skill delivery mode: ``$($task.skillDeliveryMode)``

$($skillLines -join $briefNewLine)

$($inlineSkills -join $briefNewLine)

"@
$inputSection = @"
## Inputs and Dependencies

$(To-Bullets $task.inputs)

$requirementBody

"@
$roleSection += "`n"
$skillsSection += "`n"
if (-not $includeRole) { $roleSection = '' }
if (-not $includeSkills) { $skillsSection = '' }
if ($isReview) {
  $inputSection = @"
## Review input

- Base SHA: ``$($task.reviewInput.baseSha)``
- Branch: ``$($task.reviewInput.branch)``
- Diff command: ``$($task.reviewInput.diffCommand)``

"@
  if ($task.reviewInput -and $task.reviewInput.PSObject.Properties['coordinatorEvidence'] -and @($task.reviewInput.coordinatorEvidence).Count) {
    $inputSection += "Coordinator-precomputed evidence (audit, do not re-run):`n"
    $inputSection += (($task.reviewInput.coordinatorEvidence | ForEach-Object { "- $_" }) -join "`n")
    $inputSection += "`n`n"
  }
  if ($includeRequirements -and $requirementBody) { $inputSection += "`n$requirementBody`n" }
}
# Verification obligations: worker-side rules that keep review effort proportional to the delta
# (review profile) and stop "verification pending" reports on ordinary tasks (standard profile).
$verificationLines = @(To-Bullets $task.tests)
if ($isReview) {
  if ($task.reviewInput -and $task.reviewInput.PSObject.Properties['deltaPaths'] -and @($task.reviewInput.deltaPaths).Count) {
    $verificationLines += ''
    $verificationLines += 'Delta paths recorded against the reviewed revision:'
    $verificationLines += @($task.reviewInput.deltaPaths | ForEach-Object { "- ``$_``" })
  }
  $verificationLines += @(
    ''
    '### Re-verification scaled by the delta'
    ''
    '- Re-run the acceptance items the delta touches; smoke only the untouched ones.'
    '- Run the full suite only when the delta touches a shared or core file, or when a bullet above names it.'
    '- Record the delta-to-acceptance mapping (path -> item -> command -> result) in the report.'
  )
} else {
  $verificationLines += @(
    ''
    '### Minimum relevant suites'
    ''
    '- Suites this Task names, plus the tests your change touches, are this Task''s verification duty; run them before reporting.'
    '- Run named suites as `scripts/verify-package.ps1 -Suites ''<name>''` (one of: package structure, package runtime, package contracts, project lifecycle). Several suites go in one quoted value, comma-separated, for example `scripts/verify-package.ps1 -Suites ''package contracts,project lifecycle''`; passing them as separate arguments fails. Prerequisites are added automatically; the run prints SUITES requested and SUITES running lines.'
    '- A change that can move assembled brief bytes must include `tests/task-brief-profiles.test.mjs` in its write set and required tests.'
    '- Full package gates run at post-merge and final verification, not here.'
    '- Use -MetadataOnly for metadata or boundary probes; in full mode run at most one representative point.'
  )
}
$verificationBody = $verificationLines -join $briefNewLine

$content = @"
# Assignment: $($task.title)

## Task Objective

$($task.objective)

$roleSection$skillsSection$inputSection
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

$verificationBody

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
  scriptSourceRoot = Split-Path -Parent (Resolve-PackageScriptPath 'verify-package.ps1')
}
if ($roleNotes.Count) { $result.notes = $roleNotes }
if ($provenance.Count) { $result.skillProvenance = $provenance }
if ($binding) { $result.roleBinding = $binding }
$result | ConvertTo-Json -Depth 10
