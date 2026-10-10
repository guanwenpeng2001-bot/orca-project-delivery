#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = (Get-Location).Path,

  [Parameter(Mandatory = $false)]
  [string]$Run,

  [Parameter(Mandatory = $true)]
  [string]$TaskDefinitionPath,

  [Parameter(Mandatory = $true)]
  [string]$BriefPath,

  [Parameter(Mandatory = $true)]
  [string]$ReceiptPath,

  [Parameter(Mandatory = $false)]
  [ValidateSet('planned', 'starting', 'active', 'review', 'completed', 'integrating', 'integrated', 'superseded', 'failed', 'abandoned', 'unverifiable')]
  [string]$Status = 'active',

  [Parameter(Mandatory = $false)]
  [string]$Stage,

  [Parameter(Mandatory = $false)]
  [switch]$ForceReDispatch,

  [Parameter(Mandatory = $false)]
  [switch]$SkipPostValidation
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

# --- host environment guard -------------------------------------------------
# Some hosts inject GIT_CONFIG_COUNT together with GIT_CONFIG_KEY_n pairs, then strip child
# variables whose names contain KEY/TOKEN/SECRET. The orphaned count makes every git call fail
# with: fatal: missing config key GIT_CONFIG_KEY_0. Drop the orphan so git still works.
if ($env:GIT_CONFIG_COUNT -and -not $env:GIT_CONFIG_KEY_0) {
  Remove-Item Env:GIT_CONFIG_COUNT -ErrorAction SilentlyContinue
}

. (Join-Path $PSScriptRoot 'project-common.ps1')

# The coordinator still runs worker-start itself: command lines for the orchestration runtime
# belong to the installed runtime's own documentation, not to this package. This script records
# the receipt that call returned as the run's ledger: one assignment file, one task-map entry,
# one branch-map entry, a refreshed run-state and a refreshed coordinator lock. Refusals happen
# before any write, so a rejected dispatch never leaves a half-recorded run behind.

$warnings = @()

function Read-JsonDocument {
  param([string]$Path, [string]$Label)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label not found: $Path" }
  try {
    return (Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -ErrorAction Stop)
  } catch {
    throw "$Label is not readable JSON at $Path`: $($_.Exception.Message)"
  }
}

function Get-ComparablePathText {
  param([string]$Text)
  # Receipt ids carry a topology prefix ("<id>::<path>"); the path after it is the placement.
  $value = "$Text".Trim()
  if ($value.Contains('::')) { $value = $value.Substring($value.IndexOf('::') + 2) }
  return $value.Replace('\', '/').TrimEnd('/')
}

function Test-SamePathText {
  param([string]$Left, [string]$Right)
  return ((Get-ComparablePathText $Left) -ieq (Get-ComparablePathText $Right))
}

function Test-AbsolutePathText {
  param([string]$Text)
  return ($Text -match '^(?:[A-Za-z]:[\\/]|\\\\|/)')
}

function Get-TextOrNull {
  param([object]$Value)
  if ($null -eq $Value) { return $null }
  return "$Value"
}

function Get-ProfileField {
  param([object]$Value, [string]$Name)
  if (-not $Value) { return $null }
  $property = $Value.PSObject.Properties[$Name]
  if (-not $property) { return $null }
  return (Get-TextOrNull $property.Value)
}

function Convert-LaunchProfile {
  param([object]$Value)
  return [ordered]@{
    agent = (Get-ProfileField $Value 'agent')
    model = (Get-ProfileField $Value 'model')
    effort = (Get-ProfileField $Value 'effort')
  }
}

$root = (Resolve-Path $ProjectRoot).Path
try {
  $gitRoot = (Invoke-Git -Root $root -Arguments @('rev-parse', '--show-toplevel') | Select-Object -First 1)
} catch {
  throw "Not inside a Git worktree. git said: $($_.Exception.Message)"
}
$gitRoot = (Resolve-Path $gitRoot.Trim()).Path
$devWork = Join-Path $gitRoot '.dev-work'

# ------------------------------------------------------------- run documents
$active = Read-JsonDocument -Path (Join-Path $devWork 'active-run.json') -Label 'active-run'
if ($Run -and ($Run -cne "$($active.run)")) {
  throw "Active run is '$($active.run)'; -Run '$Run' is not the active run. Reconcile the active run first."
}
$runSlug = "$($active.run)"
$runDir = Join-Path $devWork ($active.runDirectory -replace '/', '\')
$statePath = Join-Path $runDir 'run-state.json'
$state = Read-JsonDocument -Path $statePath -Label 'run-state'
$lockPath = Join-Path $devWork 'coordinator-lock.json'
$lock = Read-JsonDocument -Path $lockPath -Label 'coordinator-lock'
$taskMapPath = Join-Path $runDir 'task-map.json'
$taskMap = Read-JsonDocument -Path $taskMapPath -Label 'task-map'
$branchMapPath = Join-Path $runDir 'branch-map.json'
$branchMap = Read-JsonDocument -Path $branchMapPath -Label 'branch-map'

# Invariant 1 keeps one coordinator control worktree per project; recording a dispatch anywhere
# else would write the run ledger from a tree the run does not own.
if (-not (Test-SamePathText "$($state.coordinatorWorktree)" $gitRoot)) {
  throw "dispatch-task.ps1 must run in the coordinator control worktree '$($state.coordinatorWorktree)' (here: '$gitRoot')."
}
if ("$($lock.status)" -cne 'active') {
  throw "Coordinator lock status is '$($lock.status)'; reacquire the lock before recording dispatches."
}
if ($taskMap.tasks -isnot [System.Management.Automation.PSCustomObject]) {
  throw "task-map.json 'tasks' is not an object; repair $taskMapPath before dispatching."
}
if ($branchMap.branches -isnot [System.Management.Automation.PSCustomObject]) {
  throw "branch-map.json 'branches' is not an object; repair $branchMapPath before dispatching."
}

# ------------------------------------------------------------ task definition
$definition = Read-JsonDocument -Path $TaskDefinitionPath -Label 'task definition'
$missing = @()
if (-not "$($definition.taskKey)") { $missing += 'taskKey' }
if (-not "$($definition.role)") { $missing += 'role' }
if (-not $definition.skills -or -not ($definition.skills.required -is [array]) -or -not ($definition.skills.conditional -is [array])) {
  $missing += 'skills.required and skills.conditional (arrays)'
}
if (-not $definition.branch) {
  $missing += 'branch'
} else {
  foreach ($name in @('base', 'work', 'worktree')) {
    if (-not ("$($definition.branch.$name)".Trim())) { $missing += "branch.$name" }
  }
  if (-not $definition.branch.PSObject.Properties['mergeTarget']) { $missing += 'branch.mergeTarget' }
}
if (-not $definition.artifacts) {
  $missing += 'artifacts'
} else {
  foreach ($name in @('reportPath', 'evidencePath')) {
    if (-not $definition.artifacts.PSObject.Properties[$name]) { $missing += "artifacts.$name" }
  }
}
if ($missing.Count) {
  throw "Task definition $TaskDefinitionPath is incomplete: $($missing -join ', '). Complete it (templates/task-definition.json) and run scripts/assemble-task.ps1 before dispatching."
}
$taskKey = "$($definition.taskKey)"

if (-not (Test-Path -LiteralPath $BriefPath -PathType Leaf)) {
  throw "Worker brief not found: $BriefPath. Assemble it with scripts/assemble-task.ps1 before dispatching."
}

# ---------------------------------------------------------- dispatch receipt
$receipt = Read-JsonDocument -Path $ReceiptPath -Label 'dispatch receipt'
if ($receipt.ok -ne $true) {
  throw "Dispatch receipt reports ok=$($receipt.ok); an unsuccessful dispatch is not recorded. Inspect $ReceiptPath, apply its recovery block, and re-run the dispatch."
}
$result = $receipt.result
if (-not $result) { throw "Dispatch receipt has no result block: $ReceiptPath" }
$taskId = "$($result.taskId)"
if ($taskId -notmatch '^task_[A-Za-z0-9]+$') {
  throw "Dispatch receipt taskId '$taskId' has an unexpected shape; refusing to record it from $ReceiptPath."
}
$dispatchId = "$($result.dispatchId)"
if ($dispatchId -notmatch '^ctx_[A-Za-z0-9_-]+$') {
  throw "Dispatch receipt dispatchId '$dispatchId' has an unexpected shape; refusing to record it from $ReceiptPath."
}

$turnStart = Get-TextOrNull $result.turnStart
if ($turnStart -and ($turnStart -cne 'observed')) {
  $warnings += "Receipt turnStart is '$turnStart' (not 'observed'); confirm the worker is actually running before relying on this dispatch."
}

$orcaRunId = Get-TextOrNull $result.runId
if ($orcaRunId -and "$($state.orcaRunId)" -and ($orcaRunId -cne "$($state.orcaRunId)")) {
  throw "Dispatch receipt runId '$orcaRunId' does not match run-state orcaRunId '$($state.orcaRunId)'."
}

# -------------------------------------------------------- runtime verification
$requestedProfile = Convert-LaunchProfile $result.launch.requested
$effectiveProfile = Convert-LaunchProfile $result.launch.effective
$hasProfiles = [bool]($result.launch -and $result.launch.PSObject.Properties['requested'] -and $result.launch.PSObject.Properties['effective'])
$verificationStatus = 'unverified'
$verificationNote = "Dispatch receipt $dispatchId has no launch.requested/effective block."
$fallbackReason = $null
if ($hasProfiles) {
  $differences = @()
  foreach ($field in @('agent', 'model', 'effort')) {
    if ($requestedProfile[$field] -cne $effectiveProfile[$field]) {
      $differences += "$field requested=$($requestedProfile[$field]) effective=$($effectiveProfile[$field])"
    }
  }
  if ($differences.Count) {
    $verificationStatus = 'mismatch'
    $verificationNote = "Worker-start receipt $dispatchId launch.effective differs from launch.requested: $($differences -join '; ')."
    $fallbackReason = $verificationNote
    $warnings += "Runtime launch differs from the request: $($differences -join '; ')."
  } else {
    $verificationStatus = 'verified'
    $verificationNote = "Worker-start receipt $dispatchId launch.requested matches launch.effective."
  }
} else {
  $warnings += "Dispatch receipt $dispatchId has no launch.requested/effective block; runtime verification recorded as 'unverified'."
}

$modeProfile = $null
if ($result.mode) {
  $modeProfile = [ordered]@{
    mode = (Get-ProfileField $result.mode 'mode')
    preferred = (Get-ProfileField $result.mode 'preferred')
    reason = (Get-ProfileField $result.mode 'reason')
    detail = (Get-ProfileField $result.mode 'detail')
  }
} else {
  $warnings += "Dispatch receipt $dispatchId has no mode block; dispatch visibility cannot be reported from this receipt."
}

# ------------------------------------------------------------- placement proof
$worktreeEffect = $null
$terminalEffect = $null
foreach ($effect in @($result.effects)) {
  if (-not $effect) { continue }
  if (-not $worktreeEffect -and ("$($effect.kind)" -ceq 'worktree')) { $worktreeEffect = $effect }
  if (-not $terminalEffect -and ("$($effect.kind)" -ceq 'terminal')) { $terminalEffect = $effect }
}
if (-not $worktreeEffect) {
  throw "Dispatch receipt has no worktree effect, so placement cannot be proven. Re-dispatch with an explicit --worktree and record that receipt."
}
$receiptWorktree = Get-ComparablePathText "$($worktreeEffect.id)"
if (-not $receiptWorktree) { throw "Dispatch receipt worktree effect has no location: $ReceiptPath" }
if ($receiptWorktree -ieq (Get-ComparablePathText "$($state.coordinatorWorktree)")) {
  throw "Refusing to record a worker placed in the coordinator control worktree '$receiptWorktree'. Re-run the dispatch with an explicit --worktree under the run workspace."
}
$definitionWorktree = "$($definition.branch.worktree)"
if ((Test-AbsolutePathText $definitionWorktree) -and -not (Test-SamePathText $receiptWorktree $definitionWorktree)) {
  throw "Dispatch receipt worktree '$receiptWorktree' does not match the task definition worktree '$definitionWorktree'."
}
if (-not (Test-AbsolutePathText $definitionWorktree)) {
  $warnings += "Task definition branch.worktree is descriptive ('$definitionWorktree'); the receipt placement '$receiptWorktree' is recorded as authoritative."
}

$terminalSurface = $null
$terminalHandle = $null
if ($terminalEffect) {
  $terminalHandle = Get-TextOrNull $terminalEffect.id
  $terminalSurface = Get-TextOrNull $terminalEffect.surface
} else {
  $warnings += "Dispatch receipt has no terminal effect; the dispatch has no recorded session handle."
}
if ($terminalSurface -ceq 'background') {
  $warnings += "The worker runs as a background session (surface=background); say so when reporting progress so the user does not look for a terminal that was never opened."
}

# ------------------------------------------------------------ duplicate guard
$assignmentsDir = Join-Path $runDir 'assignments'
if (-not (Test-Path -LiteralPath $assignmentsDir)) { New-Item -ItemType Directory -Path $assignmentsDir | Out-Null }
$assignmentPath = Join-Path $assignmentsDir "$taskKey.json"
$previousDispatches = @()
if (Test-Path -LiteralPath $assignmentPath -PathType Leaf) {
  $existing = Read-JsonDocument -Path $assignmentPath -Label "assignment '$taskKey'"
  $existingStatus = "$($existing.status)"
  $existingDispatchId = ''
  if ($existing.orca) { $existingDispatchId = "$($existing.orca.dispatchId)" }
  if ($existingDispatchId -and ($existingDispatchId -ceq $dispatchId)) {
    $warnings += "Assignment '$taskKey' already records dispatch $dispatchId; refreshing it in place."
  } elseif (@('starting', 'active', 'review', 'completed', 'integrating') -ccontains $existingStatus) {
    if (-not $ForceReDispatch) {
      throw "Task '$taskKey' already has a live dispatch (dispatchId=$existingDispatchId, status=$existingStatus). Wait for it to settle, or pass -ForceReDispatch to record the replacement and keep the previous dispatch id in runtime.previousDispatches."
    }
    $warnings += "Replacing live dispatch $existingDispatchId (status=$existingStatus) for task '$taskKey' under -ForceReDispatch."
  }
  if ($existingDispatchId -and ($existingDispatchId -cne $dispatchId)) {
    foreach ($entry in @($existing.runtime.previousDispatches)) { if ($entry) { $previousDispatches += $entry } }
    $previousDispatches += [ordered]@{
      taskId = Get-TextOrNull $existing.orca.taskId
      dispatchId = $existingDispatchId
      status = $existingStatus
      replacedAt = (Get-Item -LiteralPath $assignmentPath).LastWriteTimeUtc.ToString('o')
    }
  }
}

# --------------------------------------------------------------- ledger build
$now = [DateTimeOffset]::UtcNow.ToString('o')
$requiredSkills = @()
if ($definition.skills.required) { $requiredSkills = @($definition.skills.required | ForEach-Object { "$_" }) }
$conditionalSkills = @()
if ($definition.skills.conditional) { $conditionalSkills = @($definition.skills.conditional | ForEach-Object { "$_" }) }

$assignment = [ordered]@{
  schemaVersion = 1
  taskKey = $taskKey
  role = "$($definition.role)"
  skills = [ordered]@{
    required = $requiredSkills
    conditional = $conditionalSkills
  }
  runtime = [ordered]@{
    requested = $requestedProfile
    effective = $effectiveProfile
    verification = [ordered]@{
      status = $verificationStatus
      evidence = $verificationNote
    }
    turnStart = $turnStart
    mode = $modeProfile
    surface = $terminalSurface
    terminalHandle = $terminalHandle
    skillDeliveryMode = (Get-TextOrNull $definition.skillDeliveryMode)
  }
  branch = [ordered]@{
    base = "$($definition.branch.base)"
    work = "$($definition.branch.work)"
    mergeTarget = $definition.branch.mergeTarget
    worktree = $receiptWorktree
  }
  artifacts = [ordered]@{
    reportPath = "$($definition.artifacts.reportPath)"
    evidencePath = "$($definition.artifacts.evidencePath)"
  }
  evidence = [ordered]@{
    gitEvidencePath = "runs/$runSlug/evidence/git/$taskKey.json"
  }
  orca = [ordered]@{
    runId = $orcaRunId
    taskId = $taskId
    dispatchId = $dispatchId
  }
  status = $Status
  fallbackReason = $fallbackReason
}
if ($previousDispatches.Count) { $assignment['runtime']['previousDispatches'] = @($previousDispatches) }

# Schema gate before any write: a document the state consumers cannot parse must never
# reach assignments/, because a skipped assignment silently disables later coverage checks.
$assignmentJson = $assignment | ConvertTo-Json -Depth 30
$schemaPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'schemas/assignment.schema.json'
$schemaText = [IO.File]::ReadAllText($schemaPath)
$schemaErrors = @()
$valid = Test-Json -Json $assignmentJson -Schema $schemaText -ErrorAction SilentlyContinue -ErrorVariable schemaErrors
if (-not $valid) {
  throw "Generated assignment for '$taskKey' failed schema validation ($schemaPath): $((@($schemaErrors) | ForEach-Object { $_.ToString() }) -join ' | ')"
}
$null = ConvertFrom-Json -InputObject $assignmentJson -ErrorAction Stop

# task-map drift: entries outside 'tasks' are the fingerprint of an improvised dispatch ledger
# and are never read by the run contract.
$strayKeys = @($taskMap.PSObject.Properties.Name | Where-Object { $_ -cnotin @('schemaVersion', 'tasks') })
if ($strayKeys.Count) {
  $warnings += "task-map.json has top-level keys outside 'tasks': $($strayKeys -join ', '). Move them under tasks; the run contract does not read them."
}
$caseVariant = @($taskMap.tasks.PSObject.Properties.Name | Where-Object { ($_ -ieq $taskKey) -and ($_ -cne $taskKey) })
if ($caseVariant.Count) { $warnings += "task-map.json has a case-variant key '$($caseVariant[0])' for '$taskKey'." }
$taskEntry = [pscustomobject][ordered]@{ taskId = $taskId; assignment = "assignments/$taskKey.json" }
Add-Member -InputObject $taskMap.tasks -NotePropertyName $taskKey -NotePropertyValue $taskEntry -Force

$branchEntry = [ordered]@{
  branch = "$($definition.branch.work)"
  base = "$($definition.branch.base)"
  mergeTarget = $definition.branch.mergeTarget
}
# A worker may already have created the real branch; a placeholder in the task definition must
# not overwrite a recorded branch name.
$existingBranchEntry = $branchMap.branches.PSObject.Properties[$taskKey]
if ($existingBranchEntry) {
  $existingBranch = Get-TextOrNull $existingBranchEntry.Value.branch
  if ($existingBranch -and -not $existingBranch.StartsWith('(') -and ("$($definition.branch.work)".StartsWith('(') -or -not ("$($definition.branch.work)".Trim()))) {
    $branchEntry.branch = $existingBranch
  }
}
$branchEntry.worktree = $receiptWorktree
Add-Member -InputObject $branchMap.branches -NotePropertyName $taskKey -NotePropertyValue ([pscustomobject]$branchEntry) -Force

$state.updatedAt = $now
if ($Stage) { $state.stage = $Stage }

# ------------------------------------------------------------------- writes
Write-JsonFile -Path $assignmentPath -Value $assignment -Depth 30
Write-JsonFile -Path $taskMapPath -Value $taskMap -Depth 30
Write-JsonFile -Path $branchMapPath -Value $branchMap -Depth 30
Write-JsonFile -Path $statePath -Value $state -Depth 30
$lock.updatedAt = $now
Write-JsonFile -Path $lockPath -Value $lock -Depth 30

$postValidation = [ordered]@{ executed = $false; ok = $null; exitCode = $null }
if (-not $SkipPostValidation) {
  $validator = Join-Path $PSScriptRoot 'validate-run.ps1'
  try {
    $postOutput = & pwsh -NoProfile -NonInteractive -File $validator -ProjectRoot $gitRoot -SkipPackageChecks 2>&1
    $postExit = $LASTEXITCODE
    $postValidation = [ordered]@{ executed = $true; ok = ($postExit -eq 0); exitCode = $postExit }
    if ($postExit -ne 0) {
      $warnings += "Post-write validate-run.ps1 reports problems (exit $postExit): $((@($postOutput) | Out-String).Trim())"
    }
  } catch {
    $postValidation = [ordered]@{ executed = $false; ok = $false; exitCode = $null }
    $warnings += "Post-write validate-run.ps1 could not run: $($_.Exception.Message)"
  }
}

$output = [ordered]@{
  ok = $true
  run = $runSlug
  taskKey = $taskKey
  status = $Status
  stage = "$($state.stage)"
  orca = [ordered]@{ runId = $orcaRunId; taskId = $taskId; dispatchId = $dispatchId }
  worktree = $receiptWorktree
  runtimeVerification = $verificationStatus
  assignmentPath = $assignmentPath
  postValidation = $postValidation
  warnings = @($warnings)
}
$output | ConvertTo-Json -Depth 10
