function Test-GitEvidence {
  Invoke-Check 'evidence/worker-done-id-format' {
    $document = New-TaskEvidenceDocument 'format-run' 'format-task' 'format-task' '<worktree>' $null
    $document.source.reportedCommit = $null
    $schema = [IO.File]::ReadAllText((Join-Path $stagedPackage 'schemas/evidence.schema.json'))
    Assert-Condition (Test-Json -Json ($document | ConvertTo-Json -Depth 100) -Schema $schema) 'Valid 12-hex workerDone IDs must pass'
    foreach ($case in @(
      @{ Field = 'messageId'; Value = 'msg_scope-parity-fix-done' }
      @{ Field = 'messageId'; Value = 'msg_ABCDEF012345' }
      @{ Field = 'taskId'; Value = 'task_123' }
      @{ Field = 'dispatchId'; Value = 'ctx_00000000000g' }
    )) {
      $invalid = Copy-EvidenceDocument $document
      $invalid.source.workerDone[$case.Field] = $case.Value
      Assert-Condition (-not (Test-Json -Json ($invalid | ConvertTo-Json -Depth 100) -Schema $schema -ErrorAction SilentlyContinue)) "Invalid workerDone $($case.Field) accepted: $($case.Value)"
    }
  }
  Invoke-Check 'evidence/assignment-status-schema' {
    $assignment = Read-PackageJson 'templates/dev-work/assignment.json'
    $schema = [IO.File]::ReadAllText((Join-Path $stagedPackage 'schemas/assignment.schema.json'))
    foreach ($status in @('integrating', 'integrated', 'superseded')) {
      $assignment.status = $status
      $assignment.supersededBy = 'logical-task'
      $assignment.supersedes = 'earlier-round'
      Assert-Condition (Test-Json -Json ($assignment | ConvertTo-Json -Depth 100) -Schema $schema -ErrorAction SilentlyContinue) "Assignment status $status must pass schema"
    }
    $assignment.supersededBy = 42
    Assert-Condition (-not (Test-Json -Json ($assignment | ConvertTo-Json -Depth 100) -Schema $schema -ErrorAction SilentlyContinue)) 'Non-string supersededBy accepted'
  }
  foreach ($supersededCase in @('valid', 'missing-pointer', 'missing-task', 'missing-evidence', 'not-integrated', 'not-entered', 'duplicate-task', 'self', 'cycle', 'other-run', 'identity-mismatch', 'invalid-integration')) {
    Invoke-Check "evidence/superseded-$supersededCase" {
      $fixture = New-EvidenceProject "superseded-$supersededCase"
      $taskCommit = New-FixtureCommit $fixture.TaskWorktree 'feature.txt' "task work`n" 'Task commit'
      $null = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'merge', '--no-edit', $fixture.TaskBranch)
      $document = New-TaskEvidenceDocument $fixture.RunSlug $fixture.TaskBranch $fixture.TaskBranch $fixture.TaskWorktree $taskCommit
      Add-ReviewEvidence $document $taskCommit $fixture.BaselineCommit
      Add-AdmissionEvidence $document $taskCommit $fixture.BaselineCommit
      Complete-IntegrationEvidence $document $taskCommit 'advanced-fast-forward' "git merge --no-edit $($fixture.TaskBranch)"
      $evidencePath = Join-Path $fixture.EvidenceDirectory "$($fixture.TaskBranch).json"
      Write-AssignmentFixture $fixture
      $assignmentDirectory = Join-Path $fixture.ProjectRoot ".dev-work/runs/$($fixture.RunSlug)/assignments"
      $successorPath = Join-Path $assignmentDirectory "$($fixture.TaskBranch).json"
      $successor = [IO.File]::ReadAllText($successorPath) | ConvertFrom-Json -AsHashtable
      $rework = Copy-EvidenceDocument $successor
      $rework.taskKey = 'rework-round'
      $rework.status = 'superseded'
      $rework.supersededBy = $fixture.TaskBranch
      $rework.evidence.gitEvidencePath = "runs/$($fixture.RunSlug)/evidence/git/rework-round.json"
      $diagnostic = 'supersededBy'
      switch ($supersededCase) {
        'missing-pointer' { $rework.Remove('supersededBy') }
        'missing-task' { $rework.supersededBy = 'absent-task' }
        'missing-evidence' { $successor.evidence.gitEvidencePath = "runs/$($fixture.RunSlug)/evidence/git/missing.json"; $diagnostic = 'Missing evidence file|gitEvidencePath missing' }
        'duplicate-task' { Write-EvidenceJson (Join-Path $assignmentDirectory 'duplicate.json') $successor }
        'identity-mismatch' { $document.subject.taskKey = 'different-task'; $diagnostic = 'identity mismatch' }
        'not-integrated' { $document.state = 'reviewed'; $document.Remove('integration') }
        'not-entered' { $successor.status = 'planned' }
        'self' { $rework.supersededBy = $rework.taskKey }
        'cycle' { $successor.status = 'superseded'; $successor.supersededBy = $rework.taskKey }
        'other-run' { $successor.evidence.gitEvidencePath = 'runs/other-run/evidence/git/foreign.json'; $diagnostic = 'must live under' }
        'invalid-integration' { $document.integration.mergeEvidence.exitCode = 1; $diagnostic = 'mergeEvidence' }
      }
      Write-EvidenceJson $evidencePath $document
      if ($supersededCase -ceq 'other-run') {
        $foreignPath = Join-Path $fixture.ProjectRoot ".dev-work/$($successor.evidence.gitEvidencePath)"
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $foreignPath))
        Write-EvidenceJson $foreignPath $document
      }
      Write-EvidenceJson $successorPath $successor
      Write-EvidenceJson (Join-Path $assignmentDirectory 'rework-round.json') $rework
      $expected = if ($supersededCase -ceq 'valid') { 'PASS' } else { 'FAIL' }
      foreach ($selector in @('task', 'run')) {
        $arguments = if ($selector -ceq 'task') { @('-EvidencePath', $evidencePath) } else { @('-Run', $fixture.RunSlug) }
        Assert-EvidenceStatus (Invoke-EvidenceValidator ($arguments + @('-Phase', 'audit', '-ProjectRoot', $fixture.ProjectRoot))) $expected "superseded $supersededCase $selector" $diagnostic
      }
      if ($supersededCase -ceq 'valid') {
        $finalPath = Join-Path $fixture.EvidenceDirectory 'run-final-verification.json'
        Write-EvidenceJson $finalPath (New-RunFinalDocument $fixture.RunSlug $taskCommit $fixture.DeliveryWorktree @($fixture.TaskBranch))
        Assert-EvidenceStatus (Invoke-EvidenceValidator @('-Run', $fixture.RunSlug, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'superseded final coverage'
        $script:mutationFixtures['superseded'] = @{ fixture = $fixture; rework = $rework; assignmentDirectory = $assignmentDirectory }
        $rework.Remove('supersededBy')
        $rework.Remove('evidence')
        Write-EvidenceJson (Join-Path $assignmentDirectory 'rework-round.json') $rework
        Assert-EvidenceStatus (Invoke-EvidenceValidator @('-Run', $fixture.RunSlug, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'missing supersededBy without own evidence pointer' 'supersededBy'
        $rework.supersededBy = $fixture.TaskBranch
        Write-EvidenceJson (Join-Path $assignmentDirectory 'rework-round.json') $rework
        Assert-EvidenceStatus (Invoke-EvidenceValidator @('-Run', $fixture.RunSlug, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'valid supersededBy without own evidence pointer'
      }
    }
  }
  Invoke-Check 'evidence/positive-full-chain' {
    $fixture = New-EvidenceProject 'chain'
    $taskCommit = New-FixtureCommit $fixture.TaskWorktree 'feature.txt' "task work`n" 'Task commit'
    $evidencePath = Join-Path $fixture.EvidenceDirectory 'evidence-contract.json'
    $document = New-TaskEvidenceDocument $fixture.RunSlug 'evidence-contract' $fixture.TaskBranch $fixture.TaskWorktree $taskCommit
    Write-EvidenceJson $evidencePath $document
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'sourceRegistered', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'sourceRegistered phase'
    Add-ReviewEvidence $document $taskCommit $fixture.BaselineCommit
    Write-EvidenceJson $evidencePath $document
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'review', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'review phase without integration'
    Add-AdmissionEvidence $document $taskCommit $fixture.BaselineCommit
    Write-EvidenceJson $evidencePath $document
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'preMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'preMerge phase'
    $null = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'merge', '--no-edit', 'evidence-contract')
    $headAfter = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'rev-parse', 'HEAD')
    Complete-IntegrationEvidence $document $headAfter 'advanced-fast-forward' 'git merge --no-edit evidence-contract'
    Write-EvidenceJson $evidencePath $document
    # Read-only proof: the heaviest phase must not touch a single file in the fixture.
    $snapshot = Get-FileTreeSnapshot @($fixture.ProjectRoot, $fixture.TaskWorktree, $fixture.DeliveryWorktree)
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'postMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'postMerge phase'
    $afterSnapshot = Get-FileTreeSnapshot @($fixture.ProjectRoot, $fixture.TaskWorktree, $fixture.DeliveryWorktree)
    Assert-Condition (-not (Compare-Object $snapshot $afterSnapshot)) 'Validator wrote to the fixture while validating postMerge'
    # A read-only reporting task carries review evidence but no integration duty.
    $readOnlyDocument = New-TaskEvidenceDocument $fixture.RunSlug 'read-only-report' 'evidence-contract' $fixture.TaskWorktree $taskCommit
    Add-ReviewEvidence $readOnlyDocument $taskCommit $taskCommit
    $assignmentDirectory = Join-Path $fixture.ProjectRoot ".dev-work/runs/$($fixture.RunSlug)/assignments"
    [void][IO.Directory]::CreateDirectory($assignmentDirectory)
    Write-EvidenceJson (Join-Path $assignmentDirectory 'read-only-report.json') @{ taskKey = 'read-only-report'; role = 'code-reviewer'; status = 'completed'; branch = @{ mergeTarget = $null } }
    Write-EvidenceJson (Join-Path $fixture.EvidenceDirectory 'read-only-report.json') $readOnlyDocument
    [IO.File]::WriteAllText((Join-Path $fixture.ProjectRoot ".dev-work/runs/$($fixture.RunSlug)/reviews/read-only-report.md"), "# Read-only report`n", $utf8)
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', (Join-Path $fixture.EvidenceDirectory 'read-only-report.json'), '-Phase', 'review', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'read-only task with unchanged review baseline'
    $verificationWorktree = Join-Path $script:temporaryRoot 'chain-verification'
    $null = Invoke-FixtureGit @('-C', $fixture.ProjectRoot, 'worktree', 'add', '--quiet', '--detach', $verificationWorktree, 'main')
    $runFinalPath = Join-Path $fixture.EvidenceDirectory 'run-final-verification.json'
    Write-EvidenceJson $runFinalPath (New-RunFinalDocument $fixture.RunSlug $headAfter $verificationWorktree @('evidence-contract'))
    Write-AssignmentFixture $fixture
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $runFinalPath, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'final phase (run-final document)'
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-Run', $fixture.RunSlug, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'final phase (run scope with read-only task present)'
    # Historical re-validation: main advanced past headAfter; audit and final must
    # check time-invariant relations only, never equate history with current main.
    $null = New-FixtureCommit $fixture.DeliveryWorktree 'later.txt' "later main work`n" 'Later main commit'
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'audit', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'audit phase after main advanced'
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'final phase on historical task evidence'
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $runFinalPath, '-Phase', 'audit', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'historical run-final after main advanced'
    $latestMain = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'rev-parse', 'HEAD')
    $null = Invoke-FixtureGit @('-C', $verificationWorktree, 'checkout', '--detach', $latestMain)
    Write-EvidenceJson $runFinalPath (New-RunFinalDocument $fixture.RunSlug $latestMain $verificationWorktree @('evidence-contract'))
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-Run', $fixture.RunSlug, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'latest final covering historical headAfter'
  }
  Invoke-Check 'evidence/positive-clean-merge' {
    $fixture = New-EvidenceProject 'clean-merge'
    $taskCommit = New-FixtureCommit $fixture.TaskWorktree 'feature.txt' "task work`n" 'Task commit'
    $mainAdvance = New-FixtureCommit $fixture.DeliveryWorktree 'other.txt' "main advance`n" 'Main advance commit'
    $evidencePath = Join-Path $fixture.EvidenceDirectory 'evidence-contract.json'
    $document = New-TaskEvidenceDocument $fixture.RunSlug 'evidence-contract' $fixture.TaskBranch $fixture.TaskWorktree $taskCommit
    Add-ReviewEvidence $document $taskCommit $fixture.BaselineCommit
    Add-AdmissionEvidence $document $taskCommit $mainAdvance
    Write-EvidenceJson $evidencePath $document
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'preMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'clean-merge preMerge phase'
    $null = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'merge', '--no-edit', 'evidence-contract')
    $mergeHead = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'rev-parse', 'HEAD')
    Complete-IntegrationEvidence $document $mergeHead 'advanced-clean-merge' 'git merge --no-edit evidence-contract'
    Write-EvidenceJson $evidencePath $document
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'postMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'clean-merge postMerge phase (QA-5)'
    $broken = Copy-EvidenceDocument $document
    $broken.integration.mergeEvidence.conflictFree = $false
    $brokenPath = Join-Path $fixture.EvidenceDirectory 'clean-merge-broken-evidence.json'
    Write-EvidenceJson $brokenPath $broken
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $brokenPath, '-Phase', 'postMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'three-way merge without complete merge evidence' 'mergeEvidence'
    $unresolved = Copy-EvidenceDocument $document
    $unresolved.integration.outcome = 'advanced-with-resolution'
    $unresolvedPath = Join-Path $fixture.EvidenceDirectory 'clean-merge-unresolved.json'
    Write-EvidenceJson $unresolvedPath $unresolved
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $unresolvedPath, '-Phase', 'postMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'clean-merge outcome claiming a missing resolution' 'requires resolution'
  }
  Invoke-Check 'evidence/positive-conflict-resolution' {
    $fixture = New-EvidenceProject 'resolution'
    $taskCommit = New-FixtureCommit $fixture.TaskWorktree 'shared.txt' "task resolution`n" 'Task commit'
    $mainAdvance = New-FixtureCommit $fixture.DeliveryWorktree 'shared.txt' "main resolution`n" 'Main advance commit'
    $evidencePath = Join-Path $fixture.EvidenceDirectory 'evidence-contract.json'
    $document = New-TaskEvidenceDocument $fixture.RunSlug 'evidence-contract' $fixture.TaskBranch $fixture.TaskWorktree $taskCommit
    Add-ReviewEvidence $document $taskCommit $fixture.BaselineCommit
    Add-AdmissionEvidence $document $taskCommit $mainAdvance
    Write-EvidenceJson $evidencePath $document
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'preMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'resolution preMerge phase'
    $conflict = Invoke-Child $script:git @('-C', $fixture.DeliveryWorktree, 'merge', '--no-edit', 'evidence-contract')
    Assert-Condition ($conflict.ExitCode -ne 0) 'Expected the conflicting merge to fail'
    $null = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'merge', '--abort')
    $resolverWorktree = Join-Path $script:temporaryRoot 'resolution-resolver'
    $null = Invoke-FixtureGit @('-C', $fixture.ProjectRoot, 'worktree', 'add', '--quiet', '-b', 'merge-resolution', $resolverWorktree, 'evidence-contract')
    $innerConflict = Invoke-Child $script:git @('-C', $resolverWorktree, 'merge', '--no-edit', 'main')
    Assert-Condition ($innerConflict.ExitCode -ne 0) 'Expected the resolver merge to conflict'
    [IO.File]::WriteAllText((Join-Path $resolverWorktree 'shared.txt'), "merged resolution`n", $utf8)
    $null = Invoke-FixtureGit @('-C', $resolverWorktree, 'add', 'shared.txt')
    $null = Invoke-FixtureGit @('-C', $resolverWorktree, 'commit', '-m', 'Resolve the conflicting merge')
    $resolutionCommit = Invoke-FixtureGit @('-C', $resolverWorktree, 'rev-parse', 'HEAD')
    Add-ResolutionReviewEvidence $document $resolutionCommit
    $document.integration.sourceBranch = 'merge-resolution'
    $document.integration.review = [ordered]@{ reviewTaskKey = 'review-merge-resolution'; targetCommitSha = $resolutionCommit }
    $document.integration.admission.sourceHeadSha = $resolutionCommit
    Write-EvidenceJson $evidencePath $document
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'preMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'resolution re-admission preMerge phase'
    $null = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'merge', '--no-edit', 'merge-resolution')
    $headAfter = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'rev-parse', 'HEAD')
    Complete-IntegrationEvidence $document $headAfter 'advanced-with-resolution' 'git merge --no-edit merge-resolution'
    $document.integration.resolution = [ordered]@{
      resolverTaskKey = 'merge-resolution'
      resultCommitSha = $resolutionCommit
      review = [ordered]@{ reviewTaskKey = 'review-merge-resolution'; targetCommitSha = $resolutionCommit }
    }
    Write-EvidenceJson $evidencePath $document
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'postMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'resolution postMerge phase'
    $mismatched = Copy-EvidenceDocument $document
    $mismatched.integration.resolution.review.targetCommitSha = $taskCommit
    $mismatchedPath = Join-Path $fixture.EvidenceDirectory 'resolution-review-mismatch.json'
    Write-EvidenceJson $mismatchedPath $mismatched
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $mismatchedPath, '-Phase', 'postMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'resolution review target mismatch' 'resolution.review.targetCommitSha'
    $sideWorktree = Join-Path $script:temporaryRoot 'resolution-side'
    $null = Invoke-FixtureGit @('-C', $fixture.ProjectRoot, 'worktree', 'add', '--quiet', '-b', 'side-branch', $sideWorktree, 'main')
    $sideCommit = New-FixtureCommit $sideWorktree 'side.txt' "side work`n" 'Side branch commit'
    $nonAncestor = Copy-EvidenceDocument $document
    $nonAncestor.integration.resolution.resultCommitSha = $sideCommit
    $nonAncestor.integration.resolution.review.targetCommitSha = $sideCommit
    $nonAncestorPath = Join-Path $fixture.EvidenceDirectory 'resolution-not-ancestor.json'
    Write-EvidenceJson $nonAncestorPath $nonAncestor
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $nonAncestorPath, '-Phase', 'postMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'resolution result not an ancestor of headAfter' 'is not an ancestor'
  }
  Invoke-Check 'evidence/not-applicable-scope' {
    $fixture = New-EvidenceProject 'not-applicable'
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-Run', $fixture.RunSlug, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'NOT_APPLICABLE' 'run without an evidence lifecycle'
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'NOT_APPLICABLE' 'no active run'
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-Run', 'missing-run', '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'explicit missing run' 'Run directory missing'
    Remove-Item -LiteralPath $fixture.EvidenceDirectory
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-Run', $fixture.RunSlug, '-Phase', 'audit', '-ProjectRoot', $fixture.ProjectRoot)) 'NOT_APPLICABLE' 'legacy run without evidence directory'
    Write-AssignmentFixture $fixture
    $assignmentPath = Join-Path $fixture.ProjectRoot ".dev-work/runs/$($fixture.RunSlug)/assignments/$($fixture.TaskBranch).json"
    $legacyAssignment = [IO.File]::ReadAllText($assignmentPath) | ConvertFrom-Json -AsHashtable
    $legacyAssignment.Remove('evidence')
    Write-EvidenceJson $assignmentPath $legacyAssignment
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-Run', $fixture.RunSlug, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'legacy formal task without rebuilt evidence' 'UNVERIFIABLE'
  }
  Invoke-Check 'evidence/negative-evidence-mutations' {
    $fixture = New-EvidenceProject 'mutations'
    $taskCommit = New-FixtureCommit $fixture.TaskWorktree 'feature.txt' "task work`n" 'Task commit'
    $null = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'merge', '--no-edit', 'evidence-contract')
    $headAfter = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'rev-parse', 'HEAD')
    $document = New-TaskEvidenceDocument $fixture.RunSlug 'evidence-contract' $fixture.TaskBranch $fixture.TaskWorktree $taskCommit
    Add-ReviewEvidence $document $taskCommit $fixture.BaselineCommit
    Add-AdmissionEvidence $document $taskCommit $fixture.BaselineCommit
    Complete-IntegrationEvidence $document $headAfter 'advanced-fast-forward' 'git merge --no-edit evidence-contract'
    $evidencePath = Join-Path $fixture.EvidenceDirectory 'evidence-contract.json'
    Write-EvidenceJson $evidencePath $document
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'postMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'mutations baseline evidence'
    $sideWorktree = Join-Path $script:temporaryRoot 'mutations-side'
    $null = Invoke-FixtureGit @('-C', $fixture.ProjectRoot, 'worktree', 'add', '--quiet', '-b', 'side-branch', $sideWorktree, 'main')
    $sideCommit = New-FixtureCommit $sideWorktree 'side.txt' "side work`n" 'Side branch commit'
    $cases = @(
      @{ Name = 'schema-version'; Fragment = 'schemaVersion'; Change = { param($d) $d.schemaVersion = 2 } }
      @{ Name = 'sha-format'; Fragment = '/source/reportedCommit'; Change = { param($d) $d.source.reportedCommit = 'not-a-commit-sha' } }
      @{ Name = 'unknown-commit'; Fragment = 'does not exist'; Change = { param($d) $d.reviews[0].target.commitSha = '1234567890123456789012345678901234567890' } }
      @{ Name = 'reviewer-not-independent'; Fragment = 'independence'; Change = { param($d) $d.reviews[0].reviewer.taskId = 'task_000000000001'; $d.reviews[0].reviewer.dispatchId = 'ctx_000000000001' } }
      @{ Name = 'approved-without-target-sha'; Fragment = 'Required properties.*commitSha'; Change = { param($d) $d.reviews[0].target.Remove('commitSha') } }
      @{ Name = 'target-equals-baseline'; Fragment = 'target equals baseline'; Change = { param($d) $d.reviews[0].target.commitSha = $d.reviews[0].baseline.commitSha } }
      @{ Name = 'baseline-not-ancestor'; Fragment = 'is not an ancestor'; Change = { param($d) $d.reviews[0].baseline.commitSha = $sideCommit } }
      @{ Name = 'head-after-mismatch'; Fragment = 'headAfter does not equal'; Change = { param($d) $d.integration.headAfter.commitSha = $d.integration.baselineBefore.commitSha } }
      @{ Name = 'merge-evidence-not-clean'; Fragment = 'mergeEvidence'; Change = { param($d) $d.integration.mergeEvidence.conflictFree = $false } }
      @{ Name = 'resolution-missing'; Fragment = 'requires resolution'; Change = { param($d) $d.integration.outcome = 'advanced-with-resolution' } }
      @{ Name = 'final-verification-field'; Fragment = 'finalVerification'; Change = { param($d) $d.finalVerification = @{ status = 'verified' } } }
      @{ Name = 'checks-not-self-consistent'; Fragment = 'rev-parse observation'; Change = { param($d) $d.integration.checks[0].observed = $d.integration.baselineBefore.commitSha } }
      @{ Name = 'uppercase-sha'; Fragment = 'reportedCommit'; Change = { param($d) $d.source.reportedCommit = 'ABCDEF0123456789ABCDEF0123456789ABCDEF01' } }
      @{ Name = 'missing-dispatch'; Fragment = 'dispatchId'; Change = { param($d) $d.source.workerDone.Remove('dispatchId') } }
      @{ Name = 'reviewer-same-task'; Fragment = 'independence'; Change = { param($d) $d.reviews[0].reviewer.taskId = $d.source.workerDone.taskId } }
      @{ Name = 'reviewer-same-dispatch'; Fragment = 'independence'; Change = { param($d) $d.reviews[0].reviewer.dispatchId = $d.source.workerDone.dispatchId } }
      @{ Name = 'missing-report'; Fragment = 'report missing'; Change = { param($d) $d.reviews[0].reportPath = 'missing-report.md' } }
      @{ Name = 'later-review-rejects'; Fragment = 'latest review'; Change = { param($d) $latest = Copy-EvidenceDocument $d.reviews[0]; $latest.verdict = 'CHANGES_REQUIRED'; $d.reviews += @($latest) } }
      @{ Name = 'missing-merge-command'; Fragment = 'command'; Change = { param($d) $d.integration.mergeEvidence.Remove('command') } }
      @{ Name = 'failed-merge'; Fragment = 'mergeEvidence'; Change = { param($d) $d.integration.mergeEvidence.exitCode = 1 } }
      @{ Name = 'interactive-merge'; Fragment = 'mergeEvidence'; Change = { param($d) $d.integration.mergeEvidence.command = 'git merge evidence-contract' } }
      @{ Name = 'missing-verification'; Fragment = 'verification'; Change = { param($d) $d.integration.checks = @($d.integration.checks | Where-Object kind -CEQ 'observation') } }
      @{ Name = 'old-verification-sha'; Fragment = 'verification'; Change = { param($d) $d.integration.checks[-1].commitSha = $d.integration.baselineBefore.commitSha } }
      @{ Name = 'failed-verification'; Fragment = 'check failed'; Change = { param($d) $d.integration.checks[-1].exitCode = 1 } }
      @{ Name = 'postmerge-incomplete-state'; Fragment = 'integrated state'; Change = { param($d) $d.state = 'reviewed' } }
      @{ Name = 'invalid-task-state'; Fragment = 'state'; Change = { param($d) $d.state = 'final' } }
    )
    foreach ($case in $cases) {
      $mutated = Copy-EvidenceDocument $document
      $null = & $case.Change $mutated
      $mutatedPath = Join-Path $fixture.EvidenceDirectory "mutation-$($case.Name).json"
      Write-EvidenceJson $mutatedPath $mutated
      Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $mutatedPath, '-Phase', 'postMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' "mutation $($case.Name)" $case.Fragment
    }
  }
  Invoke-Check 'evidence/negative-premerge-conditions' {
    $fixture = New-EvidenceProject 'pre-merge'
    $taskCommit = New-FixtureCommit $fixture.TaskWorktree 'feature.txt' "task work`n" 'Task commit'
    $evidencePath = Join-Path $fixture.EvidenceDirectory 'evidence-contract.json'
    $document = New-TaskEvidenceDocument $fixture.RunSlug 'evidence-contract' $fixture.TaskBranch $fixture.TaskWorktree $taskCommit
    Add-ReviewEvidence $document $taskCommit $fixture.BaselineCommit
    Add-AdmissionEvidence $document $taskCommit $fixture.BaselineCommit
    Write-EvidenceJson $evidencePath $document
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'preMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'pre-merge baseline admission'
    $null = New-FixtureCommit $fixture.TaskWorktree 'drift.txt' "unapproved drift`n" 'Unapproved drift commit'
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'preMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'approved-target drift' 'drifted'
    $null = Invoke-FixtureGit @('-C', $fixture.TaskWorktree, 'reset', '--hard', $taskCommit)
    [IO.File]::WriteAllText((Join-Path $fixture.TaskWorktree 'stray-source.txt'), 'stray', $utf8)
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'preMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'dirty source worktree' 'source worktree is dirty'
    Remove-Item -LiteralPath (Join-Path $fixture.TaskWorktree 'stray-source.txt')
    [IO.File]::WriteAllText((Join-Path $fixture.DeliveryWorktree 'stray-delivery.txt'), 'stray', $utf8)
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'preMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'dirty delivery worktree' 'delivery worktree is dirty'
    Remove-Item -LiteralPath (Join-Path $fixture.DeliveryWorktree 'stray-delivery.txt')
  }
  Invoke-Check 'evidence/negative-final-conditions' {
    $fixture = New-EvidenceProject 'final-negative'
    $taskCommit = New-FixtureCommit $fixture.TaskWorktree 'feature.txt' "task work`n" 'Task commit'
    $null = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'merge', '--no-edit', 'evidence-contract')
    $headAfter = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'rev-parse', 'HEAD')
    $document = New-TaskEvidenceDocument $fixture.RunSlug 'evidence-contract' $fixture.TaskBranch $fixture.TaskWorktree $taskCommit
    Add-ReviewEvidence $document $taskCommit $fixture.BaselineCommit
    Add-AdmissionEvidence $document $taskCommit $fixture.BaselineCommit
    Complete-IntegrationEvidence $document $headAfter 'advanced-fast-forward' 'git merge --no-edit evidence-contract'
    $evidencePath = Join-Path $fixture.EvidenceDirectory 'evidence-contract.json'
    Write-EvidenceJson $evidencePath $document
    $verificationWorktree = Join-Path $script:temporaryRoot 'final-negative-verification'
    $null = Invoke-FixtureGit @('-C', $fixture.ProjectRoot, 'worktree', 'add', '--quiet', '--detach', $verificationWorktree, 'main')
    $runFinalPath = Join-Path $fixture.EvidenceDirectory 'run-final-verification.json'
    $runFinalDocument = New-RunFinalDocument $fixture.RunSlug $headAfter $verificationWorktree @('evidence-contract')
    Write-EvidenceJson $runFinalPath $runFinalDocument
    Write-AssignmentFixture $fixture
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $runFinalPath, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'final baseline'
    $runFinalJson = [IO.File]::ReadAllText($runFinalPath, $utf8)
    $mutated = Copy-EvidenceDocument $runFinalDocument
    $mutated.coverage.integratedTaskKeys = @()
    Write-EvidenceJson $runFinalPath $mutated
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $runFinalPath, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'coverage missing the integrated task' 'coverage'
    $mutated = Copy-EvidenceDocument $runFinalDocument
    $mutated.inputs.integratedEvidencePaths = @('evidence/git/missing-task.json')
    Write-EvidenceJson $runFinalPath $mutated
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $runFinalPath, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'integrated evidence path missing' 'integratedEvidencePaths'
    [IO.File]::WriteAllText($runFinalPath, $runFinalJson, $utf8)
    [IO.File]::WriteAllText((Join-Path $verificationWorktree 'stray-verification.txt'), 'stray', $utf8)
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $runFinalPath, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'dirty verification worktree' 'verification worktree is dirty'
    Remove-Item -LiteralPath (Join-Path $verificationWorktree 'stray-verification.txt')
    Write-EvidenceJson (Join-Path $fixture.EvidenceDirectory 'run-final-verification-backup.json') (Copy-EvidenceDocument $runFinalDocument)
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $runFinalPath, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'duplicate run-final document' 'unique'
    Remove-Item -LiteralPath (Join-Path $fixture.EvidenceDirectory 'run-final-verification-backup.json')
    $sideWorktree = Join-Path $script:temporaryRoot 'final-negative-side'
    $null = Invoke-FixtureGit @('-C', $fixture.ProjectRoot, 'worktree', 'add', '--quiet', '-b', 'side-branch', $sideWorktree, 'main')
    $sideCommit = New-FixtureCommit $sideWorktree 'side.txt' "side work`n" 'Side branch commit'
    $taskEvidenceJson = [IO.File]::ReadAllText($evidencePath, $utf8)
    $mutatedTask = Copy-EvidenceDocument $document
    $mutatedTask.integration.headAfter.commitSha = $sideCommit
    $mutatedTask.integration.checks[0].observed = $sideCommit
    Write-EvidenceJson $evidencePath $mutatedTask
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $runFinalPath, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'integrated headAfter not an ancestor of the final target' 'is not an ancestor'
    [IO.File]::WriteAllText($evidencePath, $taskEvidenceJson, $utf8)
    Write-AssignmentFixture $fixture "runs/$($fixture.RunSlug)/evidence/git/missing-evidence.json"
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-Run', $fixture.RunSlug, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'assignment evidence path missing' 'gitEvidencePath'
    Write-AssignmentFixture $fixture
    Remove-Item -LiteralPath $runFinalPath
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-Run', $fixture.RunSlug, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'integrated tasks without run-final evidence' 'UNVERIFIABLE'
    [IO.File]::WriteAllText($runFinalPath, $runFinalJson, $utf8)
    $null = New-FixtureCommit $fixture.DeliveryWorktree 'advance.txt' "final advance`n" 'Final main advance'
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $runFinalPath, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'final target not current main' 'target does not equal'
  }
  Invoke-Check 'evidence/positive-unchanged-outcome' {
    $fixture = New-EvidenceProject 'unchanged-outcome'
    $taskCommit = New-FixtureCommit $fixture.TaskWorktree 'feature.txt' "task work`n" 'Task commit'
    $null = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'merge', '--no-edit', 'evidence-contract')
    $afterMerge = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'rev-parse', 'HEAD')
    $evidencePath = Join-Path $fixture.EvidenceDirectory 'evidence-contract.json'
    $document = New-TaskEvidenceDocument $fixture.RunSlug 'evidence-contract' $fixture.TaskBranch $fixture.TaskWorktree $taskCommit
    Add-ReviewEvidence $document $taskCommit $fixture.BaselineCommit
    Add-AdmissionEvidence $document $taskCommit $afterMerge
    Complete-IntegrationEvidence $document $afterMerge 'unchanged' 'git merge --no-edit evidence-contract'
    $document.integration.explanation = 'Already up to date: the reviewed target was already an ancestor of main.'
    Write-EvidenceJson $evidencePath $document
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'postMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' 'unchanged outcome postMerge'
  }
  Invoke-Check 'evidence/negative-unchanged-outcome' {
    $fixture = New-EvidenceProject 'unchanged-negative'
    $taskCommit = New-FixtureCommit $fixture.TaskWorktree 'feature.txt' "task work`n" 'Task commit'
    $null = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'merge', '--no-edit', 'evidence-contract')
    $afterMerge = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'rev-parse', 'HEAD')
    $evidencePath = Join-Path $fixture.EvidenceDirectory 'evidence-contract.json'
    $document = New-TaskEvidenceDocument $fixture.RunSlug 'evidence-contract' $fixture.TaskBranch $fixture.TaskWorktree $taskCommit
    Add-ReviewEvidence $document $taskCommit $fixture.BaselineCommit
    Add-AdmissionEvidence $document $taskCommit $fixture.BaselineCommit
    Complete-IntegrationEvidence $document $afterMerge 'unchanged' 'git merge --no-edit evidence-contract'
    $document.integration.explanation = 'Claimed unchanged but headAfter differs from baselineBefore.'
    Write-EvidenceJson $evidencePath $document
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'postMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'unchanged with unequal commits' 'unchanged requires equal commits and explanation'
    $equalDoc = New-TaskEvidenceDocument $fixture.RunSlug 'evidence-contract-equal' $fixture.TaskBranch $fixture.TaskWorktree $taskCommit
    Add-ReviewEvidence $equalDoc $taskCommit $fixture.BaselineCommit
    Add-AdmissionEvidence $equalDoc $taskCommit $afterMerge
    Complete-IntegrationEvidence $equalDoc $afterMerge 'unchanged' 'git merge --no-edit evidence-contract'
    $equalDoc.integration.baselineBefore.commitSha = $afterMerge
    $equalDoc.integration.headAfter.commitSha = $afterMerge
    $equalDoc.integration.checks[0].observed = $afterMerge
    $equalDoc.integration.checks[0].commitSha = $afterMerge
    $equalDoc.integration.checks[4].observed = $afterMerge
    $equalDoc.integration.checks[4].commitSha = $afterMerge
    $equalDoc.subject.taskKey = 'evidence-contract-equal'
    $noExplanationPath = Join-Path $fixture.EvidenceDirectory 'unchanged-no-explanation.json'
    Write-EvidenceJson $noExplanationPath $equalDoc
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $noExplanationPath, '-Phase', 'postMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'unchanged without explanation' 'unchanged requires equal commits and explanation'
  }
  Invoke-Check 'evidence/negative-clean-merge-parent-binding' {
    $fixture = New-EvidenceProject 'parent-binding'
    $taskCommit = New-FixtureCommit $fixture.TaskWorktree 'feature.txt' "task work`n" 'Task commit'
    $mainAdvance = New-FixtureCommit $fixture.DeliveryWorktree 'other.txt' "main advance`n" 'Main advance commit'
    $null = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'checkout', '-q', '-b', 'other-main')
    $null = New-FixtureCommit $fixture.DeliveryWorktree 'side.txt' "side`n" 'Side on other-main'
    $null = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'merge', '--no-edit', 'evidence-contract')
    $wrongMerge = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'rev-parse', 'HEAD')
    $null = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'checkout', '-q', 'main')
    $null = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'merge', '--no-edit', 'other-main')
    $null = Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'merge', '--no-edit', 'evidence-contract')
    $evidencePath = Join-Path $fixture.EvidenceDirectory 'evidence-contract.json'
    $document = New-TaskEvidenceDocument $fixture.RunSlug 'evidence-contract' $fixture.TaskBranch $fixture.TaskWorktree $taskCommit
    Add-ReviewEvidence $document $taskCommit $fixture.BaselineCommit
    Add-AdmissionEvidence $document $taskCommit $mainAdvance
    Complete-IntegrationEvidence $document $wrongMerge 'advanced-clean-merge' 'git merge --no-edit evidence-contract'
    Write-EvidenceJson $evidencePath $document
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'postMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'wrong merge parents for clean-merge' 'requires the recorded merge parents'
    $parents = (Invoke-FixtureGit @('-C', $fixture.DeliveryWorktree, 'show', '-s', '--format=%P', $wrongMerge)) -split ' '
    $swapped = Copy-EvidenceDocument $document
    $swapped.integration.baselineBefore.commitSha = $parents[1]
    $swapped.integration.review.targetCommitSha = $parents[0]
    $swappedPath = Join-Path $fixture.EvidenceDirectory 'parent-order-swapped.json'
    Write-EvidenceJson $swappedPath $swapped
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $swappedPath, '-Phase', 'postMerge', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'swapped recorded parents' 'requires the recorded merge parents'
    $script:mutationFixtures['parent-binding'] = @{ fixture = $fixture; evidencePath = $evidencePath }
  }
  Invoke-Check 'evidence/evidence-path-run-scope-and-assignments' {
    $fixture = New-EvidenceProject 'scope-parity' 'scope-run-a' 'formal-task'
    $taskCommit = New-FixtureCommit $fixture.TaskWorktree 'feature.txt' "task work`n" 'Task commit'
    $evidencePath = Join-Path $fixture.EvidenceDirectory 'formal-task.json'
    $document = New-TaskEvidenceDocument $fixture.RunSlug 'formal-task' $fixture.TaskBranch $fixture.TaskWorktree $taskCommit
    Add-ReviewEvidence $document $taskCommit $fixture.BaselineCommit
    Write-EvidenceJson $evidencePath $document
    $runBDirectory = Join-Path $fixture.ProjectRoot '.dev-work/runs/scope-run-b'
    $runBEvidence = Join-Path $runBDirectory 'evidence/git'
    [void][IO.Directory]::CreateDirectory($runBEvidence)
    [void][IO.Directory]::CreateDirectory((Join-Path $runBDirectory 'reviews'))
    [IO.File]::WriteAllText((Join-Path $runBDirectory 'reviews/formal-task.md'), "# Review`n", $utf8)
    [IO.File]::WriteAllText((Join-Path $runBDirectory 'run-state.json'), '{"deliveryBranch":"main"}', $utf8)
    $misplaced = Copy-EvidenceDocument $document
    $misplaced.run = 'scope-run-b'
    $misplacedPath = Join-Path $fixture.EvidenceDirectory 'misplaced-run-field.json'
    Write-EvidenceJson $misplacedPath $misplaced
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $misplacedPath, '-Phase', 'review', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'evidence file outside declared run directory' 'must live under runs/scope-run-b/evidence/git'
    Remove-Item -LiteralPath $misplacedPath -Force
    $secondTask = Join-Path $script:temporaryRoot 'scope-parity-second-task'
    $null = Invoke-FixtureGit @('-C', $fixture.ProjectRoot, 'worktree', 'add', '--quiet', '-b', 'other-formal', $secondTask, 'main')
    $null = New-FixtureCommit $secondTask 'other.txt' "other`n" 'Other formal task'
    $assignmentsDirectory = Join-Path $fixture.ProjectRoot '.dev-work/runs/scope-run-a/assignments'
    [void][IO.Directory]::CreateDirectory($assignmentsDirectory)
    Write-EvidenceJson (Join-Path $assignmentsDirectory 'other-formal.json') ([ordered]@{
      schemaVersion = 1; taskKey = 'other-formal'; role = 'software-implementer'; status = 'review'
      branch = [ordered]@{ base = 'main'; work = 'other-formal'; mergeTarget = 'main'; worktree = $secondTask }
      evidence = [ordered]@{ gitEvidencePath = 'runs/scope-run-a/evidence/git/other-formal.json' }
    })
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-Run', 'scope-run-a', '-Phase', 'review', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' '-Run mode missing second formal evidence' 'gitEvidencePath missing'
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'review', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' '-EvidencePath mode must match assignment coverage' 'gitEvidencePath missing'
    Remove-Item -LiteralPath (Join-Path $assignmentsDirectory 'other-formal.json') -Force
    $otherWorktree = Join-Path $script:temporaryRoot 'scope-parity-other-integrated'
    $null = Invoke-FixtureGit @('-C', $fixture.ProjectRoot, 'worktree', 'add', '--quiet', '-b', 'other-formal-integrated', $otherWorktree, 'main')
    $otherCommit = New-FixtureCommit $otherWorktree 'integrated.txt' "integrated`n" 'Integrated other task'
    [IO.File]::WriteAllText((Join-Path $fixture.ProjectRoot '.dev-work/runs/scope-run-a/reviews/other-formal-integrated.md'), "# Review`n", $utf8)
    $otherEvidencePath = Join-Path $fixture.EvidenceDirectory 'other-formal-integrated.json'
    $otherDocument = New-TaskEvidenceDocument $fixture.RunSlug 'other-formal-integrated' 'other-formal-integrated' $otherWorktree $otherCommit
    Add-ReviewEvidence $otherDocument $otherCommit $fixture.BaselineCommit
    Add-AdmissionEvidence $otherDocument $otherCommit $fixture.BaselineCommit
    Complete-IntegrationEvidence $otherDocument $otherCommit 'advanced-fast-forward' 'git merge --no-edit other-formal-integrated'
    Write-EvidenceJson $otherEvidencePath $otherDocument
    Write-EvidenceJson (Join-Path $assignmentsDirectory 'other-formal-integrated.json') ([ordered]@{
      schemaVersion = 1; taskKey = 'other-formal-integrated'; role = 'software-implementer'; status = 'integrated'
      branch = [ordered]@{ base = 'main'; work = 'other-formal-integrated'; mergeTarget = 'main'; worktree = $otherWorktree }
      evidence = [ordered]@{ gitEvidencePath = "runs/$($fixture.RunSlug)/evidence/git/other-formal-integrated.json" }
    })
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-Run', 'scope-run-a', '-Phase', 'review', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' '-Run with integrated peer evidence present'
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'review', '-ProjectRoot', $fixture.ProjectRoot)) 'PASS' '-EvidencePath parity when integrated peer evidence exists'
    Remove-Item -LiteralPath $otherEvidencePath -Force
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'review', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' '-EvidencePath still requires peer gitEvidencePath file' 'other-formal-integrated gitEvidencePath missing'
    Write-EvidenceJson $otherEvidencePath $otherDocument
    $script:mutationFixtures['scope-parity'] = @{ fixture = $fixture; evidencePath = $evidencePath }
  }
  Invoke-Check 'evidence/negative-vacuous-run-final' {
    $fixture = New-EvidenceProject 'vacuous-final'
    $verificationWorktree = Join-Path $script:temporaryRoot 'vacuous-final-verification'
    $null = Invoke-FixtureGit @('-C', $fixture.ProjectRoot, 'worktree', 'add', '--quiet', '--detach', $verificationWorktree, 'main')
    $head = Invoke-FixtureGit @('-C', $verificationWorktree, 'rev-parse', 'HEAD')
    $runFinalPath = Join-Path $fixture.EvidenceDirectory 'run-final-verification.json'
    Write-EvidenceJson $runFinalPath (New-RunFinalDocument $fixture.RunSlug $head $verificationWorktree @())
    [IO.File]::WriteAllText((Join-Path $fixture.ProjectRoot ".dev-work/runs/$($fixture.RunSlug)/run-state.json"), '{"deliveryBranch":"main"}', $utf8)
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-Run', $fixture.RunSlug, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'vacuous final with empty coverage' 'integratedTaskKeys must not be empty'
    Assert-EvidenceStatus (Invoke-EvidenceValidator @('-Run', $fixture.RunSlug, '-Phase', 'audit', '-ProjectRoot', $fixture.ProjectRoot)) 'FAIL' 'vacuous run-final audit with empty coverage' 'integratedTaskKeys must not be empty'
  }
  Invoke-Check 'evidence/ancestor-probe-success-cache' {
    $fixture = New-EvidenceProject 'ancestor-cache'
    $descendant = New-FixtureCommit $fixture.TaskWorktree 'feature.txt' "task work`n" 'Task commit'
    $validatorPath = Join-Path $stagedPackage 'scripts/validate-git-evidence.ps1'
    $tokens = $null
    $parseErrors = $null
    $syntax = [Management.Automation.Language.Parser]::ParseFile($validatorPath, [ref]$tokens, [ref]$parseErrors)
    Assert-Condition ($parseErrors.Count -eq 0) 'Ancestor regression validator parse failed'
    $entrypoint = @($syntax.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.TryStatementAst] })[0]
    $definitions = [IO.File]::ReadAllText($validatorPath, $utf8).Substring(0, $entrypoint.Extent.StartOffset)
    $gitRead = $syntax.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Invoke-GitRead' }, $true)
    $definitions = $definitions.Insert($gitRead.Body.Extent.StartOffset + 1, "`n  if (`$Arguments[0] -ceq 'merge-base') { `$script:ancestorProbeCount++ }`n")
    $probePath = Join-Path $script:temporaryRoot 'ancestor-probe.ps1'
    [IO.File]::WriteAllText($probePath, ($definitions + @'
$script:root = $ProjectRoot
$script:ancestorProbeCount = 0
$baseline = Get-BranchHead 'main'
$target = Get-BranchHead 'evidence-contract'
Test-Ancestor $baseline $target 'forward first'
Test-Ancestor $baseline $target 'forward repeated'
Assert-Condition ($script:ancestorProbeCount -eq 1) "Successful pair must probe once; actual=$script:ancestorProbeCount"
Test-Ancestor $target $baseline 'reverse first'
Test-Ancestor $target $baseline 'reverse repeated'
Test-Ancestor $baseline $target 'forward after failures'
Assert-Condition ($script:ancestorProbeCount -eq 3) "Reverse failures must probe twice without evicting success; actual=$script:ancestorProbeCount"
$expectedErrors = @("reverse first $target is not an ancestor of $baseline", "reverse repeated $target is not an ancestor of $baseline")
Assert-Condition (($problems.ToArray() -join "`n") -ceq ($expectedErrors -join "`n")) 'Failed pair labels, count and order changed'
'@), $utf8)
    & $probePath -ProjectRoot $fixture.ProjectRoot
    & $probePath -ProjectRoot $fixture.ProjectRoot
  }
}
