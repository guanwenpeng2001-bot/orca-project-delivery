function New-EvidenceProject {
  param([string]$Name, [string]$RunSlug = 'evidence-run', [string]$TaskBranch = 'evidence-contract')
  $projectRoot = Join-Path $script:temporaryRoot "$Name-project"
  $null = Invoke-FixtureGit @('init', '--initial-branch', 'main', '--template=', $projectRoot)
  $null = Invoke-FixtureGit @('-C', $projectRoot, 'config', 'user.name', 'Package Verification')
  $null = Invoke-FixtureGit @('-C', $projectRoot, 'config', 'user.email', 'verify@example.invalid')
  $baselineCommit = New-FixtureCommit $projectRoot 'repository.txt' "baseline $Name`n" 'Baseline commit'
  $null = Invoke-FixtureGit @('-C', $projectRoot, 'checkout', '-q', '-b', 'verification-control')
  $deliveryWorktree = Join-Path $script:temporaryRoot "$Name-delivery"
  $null = Invoke-FixtureGit @('-C', $projectRoot, 'worktree', 'add', '--quiet', $deliveryWorktree, 'main')
  $taskWorktree = Join-Path $script:temporaryRoot "$Name-task"
  $null = Invoke-FixtureGit @('-C', $projectRoot, 'worktree', 'add', '--quiet', '-b', $TaskBranch, $taskWorktree, 'main')
  $evidenceDirectory = Join-Path $projectRoot ".dev-work/runs/$RunSlug/evidence/git"
  $reviewsDirectory = Join-Path $projectRoot ".dev-work/runs/$RunSlug/reviews"
  [void][IO.Directory]::CreateDirectory($evidenceDirectory)
  [void][IO.Directory]::CreateDirectory($reviewsDirectory)
  [IO.File]::WriteAllText((Join-Path $reviewsDirectory "$TaskBranch.md"), "# Review report`n", $utf8)
  return [pscustomobject]@{
    ProjectRoot = $projectRoot
    DeliveryWorktree = $deliveryWorktree
    TaskWorktree = $taskWorktree
    EvidenceDirectory = $evidenceDirectory
    RunSlug = $RunSlug
    TaskBranch = $TaskBranch
    BaselineCommit = $baselineCommit
  }
}

function Write-EvidenceJson {
  param([string]$Path, [object]$Document)
  [IO.File]::WriteAllText($Path, ($Document | ConvertTo-Json -Depth 100), $utf8)
}

function Copy-EvidenceDocument {
  param([object]$Document)
  $Document | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
}

function New-TaskEvidenceDocument {
  param([string]$RunSlug, [string]$TaskKey, [string]$TaskBranch, [string]$TaskWorktree, [string]$TaskCommit)
  [ordered]@{
    schemaVersion = 1
    run = $RunSlug
    subject = [ordered]@{ kind = 'task'; taskKey = $TaskKey }
    state = 'source-registered'
    source = [ordered]@{
      branch = $TaskBranch
      worktree = $TaskWorktree
      reportedCommit = $TaskCommit
      workerDone = [ordered]@{ messageId = 'msg_000000000001'; taskId = 'task_000000000001'; dispatchId = 'ctx_000000000001' }
    }
  }
}

function Add-ReviewEvidence {
  param([object]$Document, [string]$TargetCommit, [string]$BaselineCommit)
  $Document.state = 'reviewed'
  $review = [ordered]@{
    reviewTaskKey = 'review-evidence-contract'
    reviewer = [ordered]@{ taskId = 'task_review_0001'; dispatchId = 'ctx_review_0001' }
    verdict = 'APPROVED'
    reportPath = "runs/$($Document.run)/reviews/$($Document.subject.taskKey).md"
    target = [ordered]@{ branch = $Document.source.branch; commitSha = $TargetCommit; dirty = $false }
    baseline = [ordered]@{ branch = 'main'; commitSha = $BaselineCommit }
    recordedAt = '2026-10-08T10:10:00Z'
  }
  $Document.reviews = @($review)
}

function Add-ResolutionReviewEvidence {
  param([object]$Document, [string]$ResolutionCommit)
  $second = [ordered]@{
    reviewTaskKey = 'review-merge-resolution'
    reviewer = [ordered]@{ taskId = 'task_review_0002'; dispatchId = 'ctx_review_0002' }
    verdict = 'APPROVED'
    reportPath = "runs/$($Document.run)/reviews/$($Document.subject.taskKey).md"
    target = [ordered]@{ branch = 'merge-resolution'; commitSha = $ResolutionCommit; dirty = $false }
    baseline = [ordered]@{ branch = 'main'; commitSha = $Document.integration.baselineBefore.commitSha }
    recordedAt = '2026-10-08T10:15:00Z'
  }
  $Document.reviews = @(@($Document.reviews) + @($second))
}

function Add-AdmissionEvidence {
  param([object]$Document, [string]$ApprovedCommit, [string]$MainCommit)
  $Document.integration = [ordered]@{
    sourceBranch = $Document.source.branch
    review = [ordered]@{ reviewTaskKey = 'review-evidence-contract'; targetCommitSha = $ApprovedCommit }
    admission = [ordered]@{ sourceHeadSha = $ApprovedCommit; sourceWorktreeClean = $true; deliveryWorktreeClean = $true; checkedAt = '2026-10-08T10:20:00Z' }
    baselineBefore = [ordered]@{ branch = 'main'; commitSha = $MainCommit }
  }
}

function Complete-IntegrationEvidence {
  param([object]$Document, [string]$HeadAfter, [string]$Outcome, [string]$MergeCommand)
  $Document.state = 'integrated'
  $Document.integration.headAfter = [ordered]@{ branch = 'main'; commitSha = $HeadAfter }
  $Document.integration.reviewedSourcePresent = $true
  $Document.integration.outcome = $Outcome
  $Document.integration.mergeEvidence = [ordered]@{ command = $MergeCommand; exitCode = 0; conflictFree = $true }
  $Document.integration.resolution = $null
  $null = Invoke-FixtureGit @('-C', $Document.source.worktree, 'diff', '--check', $Document.integration.baselineBefore.commitSha, $HeadAfter)
  $approved = $Document.integration.review.targetCommitSha
  $baseline = $Document.integration.baselineBefore.commitSha
  $Document.integration.checks = @(
    [ordered]@{ kind = 'observation'; command = 'git rev-parse main'; exitCode = 0; observed = $HeadAfter; commitSha = $HeadAfter; at = '2026-10-08T10:30:00Z' }
    [ordered]@{ kind = 'observation'; command = 'git status --short'; exitCode = 0; observed = ''; commitSha = $HeadAfter; at = '2026-10-08T10:30:01Z' }
    [ordered]@{ kind = 'observation'; command = "git rev-parse $($Document.integration.sourceBranch)"; exitCode = 0; observed = $approved; commitSha = $approved; at = '2026-10-08T10:20:00Z' }
    [ordered]@{ kind = 'observation'; command = 'git rev-parse main'; exitCode = 0; observed = $baseline; commitSha = $baseline; at = '2026-10-08T10:20:00Z' }
    [ordered]@{ kind = 'observation'; command = 'git status --short'; exitCode = 0; observed = ''; commitSha = $approved; at = '2026-10-08T10:20:00Z' }
    [ordered]@{ kind = 'observation'; command = 'git status --short'; exitCode = 0; observed = ''; commitSha = $baseline; at = '2026-10-08T10:20:00Z' }
    [ordered]@{ kind = 'verification'; command = "git diff --check $baseline $HeadAfter"; exitCode = 0; observed = 'No whitespace errors'; commitSha = $HeadAfter; at = '2026-10-08T10:30:01Z' }
  )
  $Document.integration.recordedAt = '2026-10-08T10:30:02Z'
}

function New-RunFinalDocument {
  param([string]$RunSlug, [string]$TargetCommit, [string]$VerificationWorktree, [string[]]$TaskKeys)
  $null = Invoke-FixtureGit @('-C', $VerificationWorktree, 'cat-file', '-e', $TargetCommit)
  [ordered]@{
    schemaVersion = 1
    run = $RunSlug
    subject = [ordered]@{ kind = 'run' }
    target = [ordered]@{ branch = 'main'; commitSha = $TargetCommit }
    worktree = $VerificationWorktree
    status = 'verified'
    coverage = [ordered]@{ integratedTaskKeys = @($TaskKeys); uncoveredTaskKeys = @() }
    inputs = [ordered]@{ integratedEvidencePaths = @($TaskKeys | ForEach-Object { "evidence/git/$_.json" }) }
    checks = @(
      [ordered]@{ kind = 'observation'; command = 'git rev-parse main'; exitCode = 0; observed = $TargetCommit; commitSha = $TargetCommit; at = '2026-10-08T11:00:00Z' }
      [ordered]@{ kind = 'observation'; command = 'git status --short'; exitCode = 0; observed = ''; commitSha = $TargetCommit; at = '2026-10-08T11:00:01Z' }
      [ordered]@{ kind = 'verification'; command = "git cat-file -e $TargetCommit"; exitCode = 0; observed = 'Commit exists'; commitSha = $TargetCommit; at = '2026-10-08T11:00:01Z' }
    )
    verdict = 'READY'
    recordedAt = '2026-10-08T11:00:02Z'
  }
}

function Write-AssignmentFixture {
  param([object]$Fixture, [string]$GitEvidencePath = "runs/$($Fixture.RunSlug)/evidence/git/$($Fixture.TaskBranch).json")
  $assignmentsDirectory = Join-Path $Fixture.ProjectRoot ".dev-work/runs/$($Fixture.RunSlug)/assignments"
  [void][IO.Directory]::CreateDirectory($assignmentsDirectory)
  $assignment = [ordered]@{
    schemaVersion = 1
    taskKey = $Fixture.TaskBranch
    role = 'software-implementer'
    skills = [ordered]@{ required = @('test-driven-development', 'integration-verification'); conditional = @() }
    runtime = [ordered]@{ requested = [ordered]@{ agent = 'claude' }; effective = [ordered]@{ agent = 'claude' } }
    branch = [ordered]@{ base = 'main'; work = $Fixture.TaskBranch; mergeTarget = 'main'; worktree = $Fixture.TaskWorktree }
    artifacts = [ordered]@{ reportPath = "runs/$($Fixture.RunSlug)/worker-reports/$($Fixture.TaskBranch).md"; evidencePath = "runs/$($Fixture.RunSlug)/evidence/$($Fixture.TaskBranch)" }
    evidence = [ordered]@{ gitEvidencePath = $GitEvidencePath }
    orca = [ordered]@{ runId = $null; taskId = $null; dispatchId = $null }
    status = 'completed'
  }
  Write-EvidenceJson (Join-Path $assignmentsDirectory "$($Fixture.TaskBranch).json") $assignment
}

function Invoke-EvidenceValidator {
  param([string[]]$Arguments)
  Invoke-PackageScript 'validate-git-evidence.ps1' $Arguments
}

function Assert-EvidenceStatus {
  param([object]$Result, [string]$Expected, [string]$Context, [string]$Diagnostic)
  $document = $null
  try { $document = $Result.Stdout | ConvertFrom-Json } catch {}
  Assert-Condition ($null -ne $document -and $document.status) "No structured JSON status for ${Context}: $($Result.Stdout) $($Result.Stderr)"
  Assert-Condition ($document.status -ceq $Expected) "${Context}: expected status $Expected, got '$($document.status)'; errors: $(@($document.errors) -join ' | ')"
  Assert-Condition ([bool]$document.phase) "${Context}: phase echo missing from output"
  if ($Expected -ceq 'FAIL') {
    Assert-Condition ($Result.ExitCode -eq 1) "${Context}: expected exit 1, got $($Result.ExitCode)"
    Assert-Condition (@($document.errors).Count -gt 0) "${Context}: FAIL without errors[]"
    if ($Diagnostic) {
      Assert-Condition ((@($document.errors) -join ' | ') -match $Diagnostic) "${Context}: expected a diagnostic matching /$Diagnostic/, got: $(@($document.errors) -join ' | ')"
    }
  } else {
    Assert-Condition ($Result.ExitCode -eq 0) "${Context}: expected exit 0, got $($Result.ExitCode)"
    Assert-Condition (@($document.errors).Count -eq 0) "${Context}: $($Expected) with errors[]: $(@($document.errors) -join ' | ')"
    if ($Expected -ceq 'NOT_APPLICABLE') { Assert-Condition ([bool]$document.reason) "${Context}: NOT_APPLICABLE without reason" }
  }
}
