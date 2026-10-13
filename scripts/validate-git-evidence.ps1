#requires -Version 7.0
[CmdletBinding()]
param(
  [string]$ProjectRoot = (Get-Location).Path,
  [string]$EvidencePath,
  [string]$Run,
  [ValidateSet('sourceRegistered', 'review', 'preMerge', 'postMerge', 'final', 'audit')]
  [string]$Phase = 'audit'
)

$ErrorActionPreference = 'Stop'
$problems = [Collections.Generic.List[string]]::new()
$documents = @{}
$jsonInputs = @{}
$assignmentsLoaded = $false
$assignments = @()
$assignmentsByTaskKey = [Collections.Generic.Dictionary[string, Collections.Generic.List[object]]]::new([StringComparer]::Ordinal)
$knownCommits = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$knownAncestorPairs = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)

function Assert-Evidence([bool]$Condition, [string]$Message) {
  if (-not $Condition) { $script:problems.Add($Message) }
}

function Read-Json([string]$Path) {
  $cacheKey = [IO.Path]::GetFullPath($Path)
  if ($script:jsonInputs.ContainsKey($cacheKey)) { return $script:jsonInputs[$cacheKey].Document }
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing evidence file $Path; rebuild evidence or mark UNVERIFIABLE." }
  try {
    $raw = [IO.File]::ReadAllText($Path)
    $document = $raw | ConvertFrom-Json -AsHashtable
    $script:jsonInputs[$cacheKey] = @{ Raw = $raw; Document = $document }
    return $document
  } catch { throw "Invalid JSON in ${Path}: $($_.Exception.Message)" }
}

function Initialize-Assignments {
  if ($script:assignmentsLoaded) { return }
  $directory = Join-Path $script:runDirectory 'assignments'
  if (Test-Path -LiteralPath $directory -PathType Container) {
    $script:assignments = @(Get-ChildItem -LiteralPath $directory -Filter '*.json' -File | ForEach-Object { Read-Json $_.FullName })
    foreach ($assignment in $script:assignments) {
      # Invalid/missing task keys still flow through the original assignment checks.
      if ($null -eq $assignment.taskKey) { continue }
      $key = [string]$assignment.taskKey
      if (-not $script:assignmentsByTaskKey.ContainsKey($key)) {
        $script:assignmentsByTaskKey[$key] = [Collections.Generic.List[object]]::new()
      }
      $script:assignmentsByTaskKey[$key].Add($assignment)
    }
  }
  $script:assignmentsLoaded = $true
}

function Resolve-EvidencePath([string]$Path, [string]$Base) {
  if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
  return [IO.Path]::GetFullPath((Join-Path $Base $Path))
}

function Invoke-GitRead([string]$Root, [string[]]$Arguments, [switch]$Probe) {
  $start = [Diagnostics.ProcessStartInfo]::new()
  $start.FileName = 'git'
  $start.UseShellExecute = $false
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  foreach ($argument in @('--no-optional-locks', '-C', $Root) + $Arguments) { $start.ArgumentList.Add($argument) }
  $start.Environment['GIT_OPTIONAL_LOCKS'] = '0'
  $start.Environment['GIT_NO_LAZY_FETCH'] = '1'
  foreach ($key in @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR', 'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES', 'GIT_NAMESPACE')) { [void]$start.Environment.Remove($key) }
  if ($start.Environment['GIT_CONFIG_COUNT'] -and -not $start.Environment['GIT_CONFIG_KEY_0']) { [void]$start.Environment.Remove('GIT_CONFIG_COUNT') }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $start
  try {
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(30000)) { $process.Kill($true); throw 'Read-only Git command timed out.' }
    $output = $stdout.GetAwaiter().GetResult().TrimEnd("`r", "`n")
    $errorText = $stderr.GetAwaiter().GetResult()
    if ($Probe) { return $process.ExitCode -eq 0 }
    if ($process.ExitCode -ne 0) { throw "git $($Arguments -join ' ') failed: $errorText" }
    return $output
  } finally { $process.Dispose() }
}

function Test-Commit([string]$Sha, [string]$Label) {
  if ($Sha -cnotmatch '^[0-9a-f]{40}$') { Assert-Evidence $false "$Label fails pattern for a 40-character lowercase SHA"; return }
  if ($script:knownCommits.Contains($Sha)) { return }
  $exists = Invoke-GitRead $script:root @('cat-file', '-e', "$Sha`^{commit}") -Probe
  Assert-Evidence $exists "$Label commit $Sha does not exist"
  if ($exists) { [void]$script:knownCommits.Add($Sha) }
}

function Test-RecordedCommits($Value, [string]$Label) {
  if ($Value -is [Collections.IDictionary]) {
    foreach ($key in $Value.Keys) {
      $child = $Value[$key]
      if ($key -in @('commitSha', 'reportedCommit', 'targetCommitSha', 'sourceHeadSha', 'resultCommitSha') -and $null -ne $child) { Test-Commit $child "$Label.$key" }
      else { Test-RecordedCommits $child "$Label.$key" }
    }
  } elseif ($Value -is [array]) {
    for ($index = 0; $index -lt $Value.Count; $index++) { Test-RecordedCommits $Value[$index] "$Label[$index]" }
  }
}

function Test-EvidencePathInRun([string]$Path) {
  if (-not $script:runDirectory) { return }
  $fullPath = [IO.Path]::GetFullPath($Path)
  $expectedRoot = [IO.Path]::GetFullPath((Join-Path $script:runDirectory 'evidence/git'))
  $prefix = $expectedRoot + [IO.Path]::DirectorySeparatorChar
  Assert-Evidence ($fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or $fullPath -ceq $expectedRoot) "Evidence file must live under runs/$($script:runName)/evidence/git: $Path"
}

function Get-Evidence([string]$Path) {
  $Path = [IO.Path]::GetFullPath($Path)
  Test-EvidencePathInRun $Path
  if ($script:documents.ContainsKey($Path)) { return $script:documents[$Path] }
  $document = Read-Json $Path
  $validationErrors = @()
  $valid = Test-Json -Json $script:jsonInputs[$Path].Raw -Schema $script:schema -ErrorAction SilentlyContinue -ErrorVariable validationErrors
  if (-not $valid) { throw "schema validation failed in ${Path}: $($validationErrors -join '; ')" }
  Assert-Evidence ($document.run -ceq $script:runName) "Evidence run '$($document.run)' does not match '$script:runName': $Path"
  Test-RecordedCommits $document $Path
  $script:documents[$Path] = $document
  return $document
}

function Test-Ancestor([string]$Ancestor, [string]$Descendant, [string]$Label) {
  if ($Ancestor -and $Descendant) {
    # Keys are immutable commit SHAs; only successful probes are cached so
    # failures re-probe per occurrence and keep their per-occurrence errors.
    $pairKey = $Ancestor + ' ' + $Descendant
    if (-not $script:knownAncestorPairs.Contains($pairKey)) {
      if (Invoke-GitRead $script:root @('merge-base', '--is-ancestor', $Ancestor, $Descendant) -Probe) {
        [void]$script:knownAncestorPairs.Add($pairKey)
      }
    }
    Assert-Evidence ($script:knownAncestorPairs.Contains($pairKey)) "$Label $Ancestor is not an ancestor of $Descendant"
  }
}

function Get-BranchHead([string]$Branch) {
  return Invoke-GitRead $script:root @('rev-parse', '--verify', "refs/heads/$Branch`^{commit}")
}

function Get-BranchHeadOrNull([string]$Branch) {
  # A recorded work branch may already be reclaimed. Absence is an unknown, not a defect.
  try { return (Get-BranchHead $Branch) } catch { return $null }
}

function Test-WorkLanded($Assignment) {
  # Whether the Task's work has reached the delivery branch is a Git fact, independent of the
  # self-reported assignment status. Unknown or unresolvable branches are treated as not-landed:
  # a missing work branch, or a mergeTarget that is not a real branch, must leave a historical
  # run readable rather than inventing an obligation it cannot satisfy.
  $work = [string]$Assignment.branch.work
  $target = [string]$Assignment.branch.mergeTarget
  if ([string]::IsNullOrWhiteSpace($work) -or [string]::IsNullOrWhiteSpace($target)) { return $false }
  $workHead = Get-BranchHeadOrNull $work
  if (-not $workHead) { return $false }
  if (-not (Get-BranchHeadOrNull $target)) { return $false }
  return (Invoke-GitRead $script:root @('merge-base', '--is-ancestor', $workHead, $target) -Probe)
}

function Get-BranchWorktree([string]$Branch) {
  $listing = Invoke-GitRead $script:root @('-c', 'core.quotePath=false', 'worktree', 'list', '--porcelain')
  $worktree = $null
  foreach ($line in ($listing -split "`n")) {
    if ($line.StartsWith('worktree ')) { $worktree = $line.Substring(9).TrimEnd("`r") }
    if ($line.TrimEnd("`r") -ceq "branch refs/heads/$Branch") { return $worktree }
  }
  throw "No checked-out worktree for branch $Branch"
}

function Test-CleanWorktree([string]$Path, [string]$Label, [string]$ExpectedHead) {
  $common = Invoke-GitRead $Path @('rev-parse', '--path-format=absolute', '--git-common-dir')
  Assert-Evidence ([IO.Path]::GetFullPath($common) -eq $script:commonDirectory) "$Label belongs to another repository"
  $head = Invoke-GitRead $Path @('rev-parse', 'HEAD')
  if ($ExpectedHead) { Assert-Evidence ($head -ceq $ExpectedHead) "$Label HEAD does not equal recorded commit" }
  $status = Invoke-GitRead $Path @('-c', 'core.fsmonitor=false', 'status', '--porcelain', '--untracked-files=all')
  Assert-Evidence ([string]::IsNullOrEmpty($status)) "$Label is dirty"
}

function Test-Observation($Checks, [string]$Command, [string]$Observed, [string]$Commit) {
  $matching = @($Checks | Where-Object { $_.kind -ceq 'observation' -and $_.command -ceq $Command -and $_.observed -ceq $Observed -and $_.commitSha -ceq $Commit -and $_.exitCode -eq 0 })
  Assert-Evidence ($matching.Count -gt 0) "Missing self-consistent rev-parse observation or clean status: $Command at $Commit"
}

function Test-Checks($Checks, [string]$Commit, [string]$Branch, [string]$Label) {
  Assert-Evidence (@($Checks).Count -gt 0) "$Label checks are required"
  foreach ($check in $Checks) { Assert-Evidence ($check.exitCode -eq 0) "$Label check failed: $($check.command)" }
  Test-Observation $Checks "git rev-parse $Branch" $Commit $Commit
  Test-Observation $Checks 'git status --short' '' $Commit
  $verification = @($Checks | Where-Object { $_.kind -ceq 'verification' -and $_.commitSha -ceq $Commit -and $_.exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($_.observed) })
  Assert-Evidence ($verification.Count -gt 0) "$Label requires verification checks bound to commit $Commit"
  foreach ($check in @($Checks | Where-Object kind -CEQ 'verification')) { Assert-Evidence ($check.commitSha -ceq $Commit) "$Label verification commit does not equal $Commit" }
}

function Test-MergeCommand([string]$Command, [string]$SourceBranch) {
  # The record must be the single non-interactive merge of the reviewed branch that actually ran.
  # Options that shape history or supply a message are legitimate: a conflict-free three-way merge
  # needs --no-ff or -m to produce the very merge commit the advanced-clean-merge outcome requires,
  # so demanding one exact string rejected true records and rewarded invented ones. What is still
  # rejected is anything that is not one merge invocation, names another ref, or would block an
  # unattended coordinator on a merge-message editor.
  if ([string]::IsNullOrWhiteSpace($Command)) { return $false }
  if ($Command -cmatch '[;&|<>$`]') { return $false }
  # A message may contain spaces; drop quoted spans so they cannot be read as refs.
  $stripped = $Command -replace '"[^"]*"', 'MESSAGE' -replace "'[^']*'", 'MESSAGE'
  $tokens = @($stripped -split '\s+' | Where-Object { $_ -ne '' })
  if ($tokens.Count -lt 3 -or $tokens[0] -cne 'git' -or $tokens[1] -cne 'merge') { return $false }
  $positional = [Collections.Generic.List[string]]::new()
  $hasMessageFlag = $false
  $index = 2
  while ($index -lt $tokens.Count) {
    $token = $tokens[$index]
    if ($token -in @('-m', '--message', '-F', '--file')) {
      # These take a separate value, which may be an unquoted word that looks like a ref.
      $hasMessageFlag = $true
      $index += 2
      continue
    }
    if ($token -eq '--no-edit' -or $token -eq 'MESSAGE' -or $token -like '-m*' -or $token -like '-F*' -or $token -like '--message=*' -or $token -like '--file=*') {
      $hasMessageFlag = $true
      $index++
      continue
    }
    if ($token.StartsWith('-')) { $index++; continue }
    $positional.Add($token)
    $index++
  }
  if (-not $hasMessageFlag) { return $false }
  return ($positional.Count -eq 1 -and $positional[0] -ceq $SourceBranch)
}

function Test-TaskEvidence($Document, [string]$TaskPhase) {
  $taskKey = $Document.subject.taskKey
  $readOnlyTask = $false
  Initialize-Assignments
  if ($script:assignmentsByTaskKey.ContainsKey($taskKey)) {
    foreach ($assignment in $script:assignmentsByTaskKey[$taskKey]) {
      if ($assignment.branch -and $assignment.branch.Contains('mergeTarget') -and $null -eq $assignment.branch.mergeTarget) { $readOnlyTask = $true }
    }
  }
  if ($TaskPhase -ceq 'sourceRegistered') { return }
  if ($TaskPhase -in @('audit', 'final') -and $Document.state -ceq 'source-registered') { return }
  Assert-Evidence ($Document.state -in @('reviewed', 'integrated')) "$taskKey requires reviewed or integrated state"
  Assert-Evidence (@($Document.reviews).Count -gt 0) "$taskKey requires reviews"
  foreach ($review in $Document.reviews) {
    Assert-Evidence ($review.reviewer.taskId -cne $Document.source.workerDone.taskId -and $review.reviewer.dispatchId -cne $Document.source.workerDone.dispatchId) "$taskKey review independence violated"
    $report = Resolve-EvidencePath $review.reportPath $script:devWork
    Assert-Evidence (Test-Path -LiteralPath $report -PathType Leaf) "$taskKey review report missing: $report"
    Test-Ancestor $review.baseline.commitSha $review.target.commitSha "$taskKey review baseline"
    if (-not $readOnlyTask) { Assert-Evidence ($review.target.commitSha -cne $review.baseline.commitSha) "$taskKey review target equals baseline" }
    if ($review.verdict -ceq 'APPROVED') { Assert-Evidence (-not $review.target.dirty) "$taskKey APPROVED target is dirty" }
  }
  if ($TaskPhase -ceq 'review') { return }
  $integration = $Document.integration
  if ($readOnlyTask) { Assert-Evidence (-not $integration) "$taskKey read-only task cannot have integration evidence"; return }
  if ($TaskPhase -in @('audit', 'final') -and $Document.state -cne 'integrated' -and -not $integration) { return }
  Assert-Evidence ($null -ne $integration) "$taskKey integration is required"
  if (-not $integration) { return }
  $latestReview = @($Document.reviews)[-1]
  Assert-Evidence ($latestReview.verdict -ceq 'APPROVED') "$taskKey latest review must be APPROVED"
  Assert-Evidence ($integration.review.reviewTaskKey -ceq $latestReview.reviewTaskKey -and $integration.review.targetCommitSha -ceq $latestReview.target.commitSha) "$taskKey integration.review does not bind the latest APPROVED review"
  Assert-Evidence ($integration.sourceBranch -ceq $latestReview.target.branch) "$taskKey sourceBranch does not match reviewed branch"
  $targetSha = $integration.review.targetCommitSha
  Assert-Evidence ($integration.admission.sourceHeadSha -ceq $targetSha) "$taskKey admission sourceHeadSha does not equal approved SHA"
  Assert-Evidence ($integration.admission.sourceWorktreeClean -eq $true -and $integration.admission.deliveryWorktreeClean -eq $true) "$taskKey admission requires clean source and delivery trees"
  $deliveryBranch = $integration.baselineBefore.branch
  if ($script:deliveryBranch) { Assert-Evidence ($deliveryBranch -ceq $script:deliveryBranch) "$taskKey delivery branch differs from run-state" }
  if ($TaskPhase -ceq 'preMerge') {
    Assert-Evidence ($Document.state -ceq 'reviewed') "$taskKey preMerge requires reviewed state"
    Assert-Evidence ((Get-BranchHead $integration.sourceBranch) -ceq $targetSha) "$taskKey approved source HEAD drifted; review again"
    Test-CleanWorktree (Get-BranchWorktree $integration.sourceBranch) 'source worktree' $targetSha
    Test-CleanWorktree (Get-BranchWorktree $deliveryBranch) 'delivery worktree' $integration.baselineBefore.commitSha
    Assert-Evidence ((Get-BranchHead $deliveryBranch) -ceq $integration.baselineBefore.commitSha) "$taskKey baselineBefore does not equal delivery branch HEAD"
    return
  }
  if ($TaskPhase -ceq 'postMerge') { Assert-Evidence ($Document.state -ceq 'integrated') "$taskKey postMerge requires integrated state" }
  if ($Document.state -cne 'integrated') { return }
  $headAfter = $integration.headAfter.commitSha
  $baselineBefore = $integration.baselineBefore.commitSha
  Assert-Evidence ($integration.headAfter.branch -ceq $deliveryBranch) "$taskKey headAfter branch differs from baselineBefore"
  if ($TaskPhase -ceq 'postMerge') {
    Assert-Evidence ((Get-BranchHead $deliveryBranch) -ceq $headAfter) "$taskKey headAfter does not equal delivery branch HEAD"
    Test-CleanWorktree (Get-BranchWorktree $deliveryBranch) 'delivery worktree' $headAfter
  }
  Assert-Evidence ($integration.outcome -cne 'rejected') "$taskKey rejected integration cannot be integrated or covered"
  Assert-Evidence ($integration.reviewedSourcePresent -eq $true) "$taskKey reviewedSourcePresent must be true"
  Test-Ancestor $baselineBefore $headAfter "$taskKey baselineBefore"
  Test-Ancestor $targetSha $headAfter "$taskKey reviewed target"
  $merge = $integration.mergeEvidence
  Assert-Evidence ($merge.exitCode -eq 0 -and $merge.conflictFree -eq $true) "$taskKey mergeEvidence must record a successful conflict-free admitted merge"
  Assert-Evidence (Test-MergeCommand $merge.command $integration.sourceBranch) "$taskKey mergeEvidence command must be a single non-interactive merge of the reviewed branch"
  Assert-Evidence ($integration.sourceBranch -cmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*$') "$taskKey mergeEvidence source branch cannot contain shell syntax"
  $resolution = $integration.resolution
  if ($integration.outcome -ceq 'advanced-with-resolution') {
    Assert-Evidence ($null -ne $resolution) "$taskKey advanced-with-resolution requires resolution"
    if ($resolution) {
      Assert-Evidence ($resolution.review.targetCommitSha -ceq $resolution.resultCommitSha) "$taskKey resolution.review.targetCommitSha differs from resultCommitSha"
      Assert-Evidence ($resolution.review.targetCommitSha -ceq $targetSha -and $resolution.review.reviewTaskKey -ceq $integration.review.reviewTaskKey) "$taskKey resolution.review differs from integration.review"
      Test-Ancestor $resolution.resultCommitSha $headAfter "$taskKey resolution result"
    }
  } else { Assert-Evidence ($null -eq $resolution) "$taskKey resolution only applies to advanced-with-resolution" }
  switch -CaseSensitive ($integration.outcome) {
    'unchanged' {
      Assert-Evidence ($headAfter -ceq $baselineBefore -and -not [string]::IsNullOrWhiteSpace($integration.explanation)) "$taskKey unchanged requires equal commits and explanation"
    }
    'advanced-fast-forward' { Assert-Evidence ($headAfter -ceq $targetSha -and $headAfter -cne $baselineBefore) "$taskKey invalid advanced-fast-forward commits" }
    'advanced-clean-merge' {
      $parents = (Invoke-GitRead $script:root @('show', '-s', '--format=%P', $headAfter)) -split ' '
      Assert-Evidence ($headAfter -cne $targetSha -and $headAfter -cne $baselineBefore -and $parents.Count -eq 2 -and $parents[0] -ceq $baselineBefore -and $parents[1] -ceq $targetSha) "$taskKey advanced-clean-merge requires the recorded merge parents"
    }
    'advanced-with-resolution' { Assert-Evidence ($headAfter -cne $baselineBefore) "$taskKey resolution did not advance delivery" }
  }
  Test-Checks $integration.checks $headAfter $deliveryBranch "$taskKey integration"
  Test-Observation $integration.checks "git rev-parse $($integration.sourceBranch)" $targetSha $targetSha
  Test-Observation $integration.checks "git rev-parse $deliveryBranch" $baselineBefore $baselineBefore
  Test-Observation $integration.checks 'git status --short' '' $targetSha
  Test-Observation $integration.checks 'git status --short' '' $baselineBefore
}

function Get-RunEvidence {
  $directory = Join-Path $script:runDirectory 'evidence/git'
  if (Test-Path -LiteralPath $directory -PathType Container) {
    foreach ($file in Get-ChildItem -LiteralPath $directory -Filter '*.json' -File -Recurse) {
      [pscustomobject]@{ Path = $file.FullName; Document = (Get-Evidence $file.FullName) }
    }
  }
}

function Test-SupersededAssignment($Assignment, $Assignments, $EnteredStatuses, [string]$RequestedPhase) {
  $label = "Assignment $($Assignment.taskKey) supersededBy"
  $key = $Assignment.supersededBy
  if ($key -isnot [string] -or [string]::IsNullOrWhiteSpace($key) -or $key -ceq $Assignment.taskKey) {
    Assert-Evidence $false "$label must name a different logical task in this run"
    return
  }
  $matches = @(if ($script:assignmentsByTaskKey.ContainsKey($key)) { $script:assignmentsByTaskKey[$key].ToArray() })
  if ($matches.Count -ne 1) {
    Assert-Evidence $false "$label must identify exactly one existing assignment in this run"
    return
  }
  $successor = $matches[0]
  if ($successor.status -cnotin $EnteredStatuses -or [string]::IsNullOrWhiteSpace($successor.branch.mergeTarget)) {
    Assert-Evidence $false "$label must identify a formal task that entered the evidence lifecycle"
    return
  }
  Assert-Evidence ($successor.branch.mergeTarget -ceq $Assignment.branch.mergeTarget) "$label delivery branch mismatch"
  $path = $successor.evidence.gitEvidencePath
  if (-not $path) { $path = "runs/$script:runName/evidence/git/$key.json" }
  $evidence = Get-Evidence (Resolve-EvidencePath $path $script:devWork)
  Assert-Evidence ($evidence.subject.kind -ceq 'task' -and $evidence.subject.taskKey -ceq $key) "$label evidence task identity mismatch"
  if ($RequestedPhase -cin @('sourceRegistered', 'review', 'preMerge')) {
    Assert-Evidence ($evidence.state -cin @('reviewed', 'integrated')) "$label requires reviewed or integrated successor evidence"
    if ($evidence.state -ceq 'reviewed') { Test-TaskEvidence $evidence 'review' }
  } else {
    Assert-Evidence ($evidence.state -ceq 'integrated') "$label requires integrated successor evidence"
  }
  if ($evidence.state -ceq 'integrated') {
    Assert-Evidence ($evidence.integration.headAfter.branch -ceq $successor.branch.mergeTarget) "$label integrated delivery branch mismatch"
    Test-TaskEvidence $evidence 'audit'
  }
}

function Test-Assignments($Entries, [string]$CoverageTaskKey) {
  Initialize-Assignments
  $assignments = $script:assignments
  $enteredStatuses = @('review', 'completed', 'integrating', 'integrated')
  $legalStatuses = @('planned', 'starting', 'active', 'review', 'completed', 'integrating', 'integrated', 'superseded', 'failed', 'abandoned', 'unverifiable')
  foreach ($assignment in $assignments) {
    $formal = -not [string]::IsNullOrWhiteSpace($assignment.branch.mergeTarget)
    if ($formal -and $null -ne $assignment.status -and -not ($assignment.status -is [string] -and $assignment.status -cin $legalStatuses)) {
      Assert-Evidence $false "Assignment $($assignment.taskKey) status '$($assignment.status)' is outside the assignment lifecycle; use one of: $($legalStatuses -join ', ')"
    }
    if ($formal -and $assignment.status -ceq 'superseded') {
      Test-SupersededAssignment $assignment $assignments $enteredStatuses $script:Phase
      continue
    }
    $entered = $assignment.status -in $enteredStatuses
    # Work that actually reached the delivery branch owes a record whatever the self-reported
    # status says. A status label is a local workflow record and must never be able to void the
    # evidence obligation for an integration that really landed. Superseded rounds are excluded:
    # their own record is deliberately waived and the successor's integrated evidence carries it.
    $landed = $formal -and $assignment.status -cne 'superseded' -and (Test-WorkLanded $assignment)
    $owes = $entered -or $landed
    $path = $assignment.evidence.gitEvidencePath
    if ($formal -and $owes) {
      if (-not $path) { $path = "runs/$script:runName/evidence/git/$($assignment.taskKey).json" }
      $resolved = Resolve-EvidencePath $path $script:devWork
      Assert-Evidence (Test-Path -LiteralPath $resolved -PathType Leaf) "Assignment $($assignment.taskKey) gitEvidencePath missing: $resolved; rebuild evidence or mark UNVERIFIABLE"
      if (Test-Path -LiteralPath $resolved -PathType Leaf) {
        $evidence = Get-Evidence $resolved
        Assert-Evidence ($evidence.subject.kind -ceq 'task' -and $evidence.subject.taskKey -ceq $assignment.taskKey) "Assignment gitEvidencePath task identity mismatch"
        if ($script:Phase -ceq 'final' -and $owes) { Assert-Evidence ($evidence.state -ceq 'integrated') "Final coverage lacks intended integrated task $($assignment.taskKey); UNVERIFIABLE" }
        if (-not $CoverageTaskKey -or $assignment.taskKey -ceq $CoverageTaskKey) {
          Assert-Evidence (@($Entries | Where-Object { [IO.Path]::GetFullPath($_.Path) -eq $resolved }).Count -eq 1) 'Assignment gitEvidencePath must be in the run evidence/git directory'
        }
      }
    }
  }
}

function Test-RunFinal($Document, $Entries, [bool]$Current) {
  $finals = @($Entries | Where-Object { $_.Document.subject.kind -ceq 'run' })
  Assert-Evidence ($finals.Count -eq 1) 'run-final evidence must be unique'
  if ($finals.Count -eq 1) {
    $canonicalFinal = [IO.Path]::GetFullPath((Join-Path $script:runDirectory 'evidence/git/run-final-verification.json'))
    Assert-Evidence ([IO.Path]::GetFullPath($finals[0].Path) -eq $canonicalFinal) 'run-final must use the unique canonical file'
    Assert-Evidence ([object]::ReferenceEquals($Document, $finals[0].Document)) 'Selected run-final is outside the unique run evidence set'
  }
  $integrated = @($Entries | Where-Object { $_.Document.subject.kind -ceq 'task' -and $_.Document.state -ceq 'integrated' })
  $keys = @($integrated | ForEach-Object { $_.Document.subject.taskKey })
  Assert-Evidence (@($keys | Select-Object -Unique).Count -eq $keys.Count) 'Duplicate task evidence in coverage'
  Assert-Evidence ($Document.status -ceq 'verified' -and $Document.verdict -ceq 'READY') 'run-final must be verified and READY'
  Assert-Evidence (@($Document.coverage.uncoveredTaskKeys).Count -eq 0) 'Final coverage contains uncovered tasks'
  $coverage = @($Document.coverage.integratedTaskKeys)
  $inputPaths = @($Document.inputs.integratedEvidencePaths)
  if ($Current -or $script:Phase -ceq 'audit') {
    Assert-Evidence ($coverage.Count -gt 0) 'Final coverage integratedTaskKeys must not be empty'
    Assert-Evidence ($inputPaths.Count -gt 0) 'Final coverage integratedEvidencePaths must not be empty'
  }
  Assert-Evidence (($keys.Count -eq $coverage.Count) -and @($keys | Where-Object { $coverage -cnotcontains $_ }).Count -eq 0) 'Final coverage must contain every integrated task exactly once'
  $inputKeys = [Collections.Generic.List[string]]::new()
  foreach ($inputPath in $Document.inputs.integratedEvidencePaths) {
    $resolved = Resolve-EvidencePath $inputPath $script:runDirectory
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { Assert-Evidence $false "integratedEvidencePaths missing file: $resolved"; continue }
    $inputDocument = Get-Evidence $resolved
    Assert-Evidence ($inputDocument.subject.kind -ceq 'task' -and $inputDocument.state -ceq 'integrated') 'integratedEvidencePaths must refer to integrated task evidence'
    $inputKeys.Add($inputDocument.subject.taskKey)
    Assert-Evidence (@($integrated | Where-Object { [IO.Path]::GetFullPath($_.Path) -eq $resolved }).Count -eq 1) 'integratedEvidencePaths must refer to this run evidence/git directory'
  }
  Assert-Evidence ($inputKeys.Count -eq $keys.Count -and @($keys | Where-Object { $inputKeys -cnotcontains $_ }).Count -eq 0 -and @($inputKeys | Select-Object -Unique).Count -eq $inputKeys.Count) 'integratedEvidencePaths coverage is incomplete or duplicated'
  foreach ($entry in $integrated) {
    Test-TaskEvidence $entry.Document 'audit'
    Assert-Evidence ($entry.Document.integration.headAfter.branch -ceq $Document.target.branch) 'Integrated delivery branch differs from final target branch'
    Test-Ancestor $entry.Document.integration.headAfter.commitSha $Document.target.commitSha 'Historical headAfter'
  }
  if ($script:deliveryBranch) { Assert-Evidence ($Document.target.branch -ceq $script:deliveryBranch) 'Final target branch differs from run-state' }
  Test-Checks $Document.checks $Document.target.commitSha $Document.target.branch 'run-final'
  if ($Current) {
    Assert-Evidence ((Get-BranchHead $Document.target.branch) -ceq $Document.target.commitSha) 'Final target does not equal delivery branch HEAD'
    Test-CleanWorktree $Document.worktree 'verification worktree' $Document.target.commitSha
  }
}

$status = 'PASS'
$reason = $null
try {
  if ($EvidencePath -and $Run) { throw 'Use either -EvidencePath or -Run, not both.' }
  $root = [IO.Path]::GetFullPath($ProjectRoot)
  $devWork = Join-Path $root '.dev-work'
  $schema = [IO.File]::ReadAllText((Join-Path (Split-Path -Parent $PSScriptRoot) 'schemas/evidence.schema.json'))
  $runName = $Run
  $selected = $null
  if ($EvidencePath) {
    $EvidencePath = Resolve-EvidencePath $EvidencePath $root
    $selected = Read-Json $EvidencePath
    $runName = $selected.run
  } elseif (-not $runName) {
    $activePath = Join-Path $devWork 'active-run.json'
    if (Test-Path -LiteralPath $activePath -PathType Leaf) { $runName = (Read-Json $activePath).run }
    if (-not $runName) { $status = 'NOT_APPLICABLE'; $reason = 'No active run.' }
  }
  if ($status -cne 'NOT_APPLICABLE') {
    if ($runName -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { throw 'Invalid run name.' }
    $runDirectory = Join-Path $devWork "runs/$runName"
    if (-not (Test-Path -LiteralPath $runDirectory -PathType Container)) { throw "Run directory missing: $runDirectory; UNVERIFIABLE" }
    $commonDirectory = [IO.Path]::GetFullPath((Invoke-GitRead $root @('rev-parse', '--path-format=absolute', '--git-common-dir')))
    $deliveryBranch = $null
    $statePath = Join-Path $runDirectory 'run-state.json'
    if (Test-Path -LiteralPath $statePath -PathType Leaf) { $deliveryBranch = (Read-Json $statePath).deliveryBranch }
    if ($EvidencePath) {
      $selected = Get-Evidence $EvidencePath
      if ($selected.subject.kind -ceq 'task') {
        $entries = @([pscustomobject]@{ Path = [IO.Path]::GetFullPath($EvidencePath); Document = $selected })
        Test-Assignments $entries $selected.subject.taskKey
        Test-TaskEvidence $selected $Phase
      }
      else {
        if ($Phase -notin @('final', 'audit')) { throw 'Run evidence only supports final or audit phase.' }
        $entries = @(Get-RunEvidence)
        Test-Assignments $entries $selected.subject.taskKey
        Test-RunFinal $selected $entries ($Phase -ceq 'final')
      }
    } else {
      $entries = @(Get-RunEvidence)
      Test-Assignments $entries
      $tasks = @($entries | Where-Object { $_.Document.subject.kind -ceq 'task' })
      if ($tasks.Count -eq 0 -and $entries.Count -eq 0 -and $problems.Count -eq 0) {
        $status = 'NOT_APPLICABLE'; $reason = 'No Task has entered the evidence lifecycle in this run.'
      } elseif ($Phase -ceq 'final') {
        $finals = @($entries | Where-Object { $_.Document.subject.kind -ceq 'run' })
        Assert-Evidence ($finals.Count -eq 1) 'Final evidence must be unique; rebuild evidence or mark UNVERIFIABLE'
        if ($finals.Count -eq 1) { Test-RunFinal $finals[0].Document $entries $true }
      } else {
        foreach ($entry in $tasks) { Test-TaskEvidence $entry.Document $Phase }
        if ($Phase -ceq 'audit') {
          foreach ($entry in @($entries | Where-Object { $_.Document.subject.kind -ceq 'run' })) { Test-RunFinal $entry.Document $entries $false }
        }
      }
    }
  }
} catch { $problems.Add($_.Exception.Message) }
if ($problems.Count -gt 0) { $status = 'FAIL'; $reason = 'Evidence validation failed.' }
[ordered]@{ status = $status; phase = $Phase; errors = @($problems.ToArray()); reason = $reason } | ConvertTo-Json -Depth 8
if ($status -ceq 'FAIL') { exit 1 }
exit 0
