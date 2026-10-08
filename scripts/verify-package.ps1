#requires -Version 7.0
<##
Offline package acceptance. Requires PowerShell 7, Git and the declared sibling
skills (or their installed copies under $HOME/.agents/skills). The package under
test is read-only; all runtime fixtures and copies live in one temporary root.
##>
[CmdletBinding()]
param([string]$PackageRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$passed = 0
$failed = 0
$temporaryRoot = $null
$utf8 = [Text.UTF8Encoding]::new($false, $true)

function Assert-Condition([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Invoke-Check([string]$CheckName, [scriptblock]$Check) {
  try {
    & $Check
    $script:passed++
    Write-Host "PASS $CheckName"
  } catch {
    $script:failed++
    Write-Host "FAIL ${CheckName}: $($_.Exception.Message)"
  }
}

function Read-PackageJson([string]$RelativePath) {
  Get-Content -LiteralPath (Join-Path $script:root $RelativePath) -Raw | ConvertFrom-Json -AsHashtable
}

# The sole vocabulary declaration is exempt from scanning, by its AST extent only.
$forbiddenAgentIds = @(
  'claude-agent-teams', 'codebuddy', 'openclaude', 'codex', 'autohand', 'opencode',
  'opencode2', 'mimo-code', 'pi', 'omp', 'qoder', 'gemini', 'antigravity', 'aider',
  'goose', 'amp', 'kilo', 'kiro', 'crush', 'aug', 'cline', 'codebuff', 'freebuff',
  'command-code', 'continue', 'cursor', 'droid', 'kimi', 'mistral-vibe', 'qwen-code',
  'rovo', 'hermes', 'openclaw', 'copilot', 'grok', 'devin', 'ante', 'trae', 'muse',
  'zcode', 'prime-agent', 'dsh'
)

function Assert-Rejected([string]$Name, [scriptblock]$Action, [string]$Diagnostic) {
  $caught = $null
  try { & $Action } catch { $caught = $_.Exception.Message }
  Assert-Condition ($null -ne $caught -and $caught.Contains($Diagnostic)) "Negative case $Name did not produce $Diagnostic (actual: $caught)"
  Write-Host "REJECTED $Name : $caught"
}

function Assert-ModelRouting($Routing, $Catalog) {
  $ids = @($Catalog.roles.id)
  Assert-Condition ($ids.Count -eq 12 -and @($ids | Select-Object -Unique).Count -eq 12) 'routing: expected 12 unique catalog roles'
  Assert-Condition ($Routing.agent -ceq 'claude') 'routing: agent must be claude'
  Assert-Condition ($Routing.roles -is [Collections.IDictionary]) 'routing: roles must be a map'
  Assert-Condition (-not (Compare-Object ($ids | Sort-Object) (@($Routing.roles.Keys) | Sort-Object) -CaseSensitive)) 'routing: role sets differ'
  $tiers = @($Routing.vocabulary.modelLadder)
  $efforts = @($Routing.vocabulary.effortLevels)
  Assert-Condition (($tiers -join ',') -ceq 'haiku,sonnet,opus,fable') 'routing: invalid model ladder'
  Assert-Condition (($efforts -join ',') -ceq 'low,medium,high,xhigh,max') 'routing: invalid effort levels'
  foreach ($id in $ids) {
    $route = $Routing.roles[$id]
    Assert-Condition ($route.chain -is [array] -and $route.chain.Count -gt 0) "routing: $id chain must be nonempty"
    foreach ($indexName in @('floor', 'default')) {
      $index = $route[$indexName]
      Assert-Condition ($index -is [int] -or $index -is [long]) "routing: $id $indexName must be an integer"
    }
    Assert-Condition ($route.floor -ge 0 -and $route.floor -le $route.default -and $route.default -lt $route.chain.Count) "routing: $id invalid floor/default bounds"
    $previous = -1
    foreach ($step in $route.chain) {
      Assert-Condition ($tiers -ccontains $step.tier -and $efforts -ccontains $step.effort) "routing: $id unknown tier/effort"
      $rank = [array]::IndexOf($tiers, $step.tier) * $efforts.Count + [array]::IndexOf($efforts, $step.effort)
      Assert-Condition ($rank -gt $previous) "routing: $id chain is not strictly increasing"
      $previous = $rank
    }
  }
}

function Assert-RoleSelection($Selection, $Catalog) {
  Assert-Condition ($Selection.deliverableRoutes -is [Collections.IDictionary] -and $Selection.deliverableRoutes.Count -gt 0) 'selection: empty or invalid routes'
  foreach ($deliverable in $Selection.deliverableRoutes.Keys) {
    Assert-Condition (@($Catalog.roles.id) -ccontains $Selection.deliverableRoutes[$deliverable]) "selection: $deliverable selects unknown role"
  }
}

function Assert-ClaudeText([string]$Content, [string]$Extension, [string]$Source) {
  $segments = @($Content)
  if ($Extension -eq '.ps1') {
    $tokens = $null
    $errors = $null
    $syntax = [Management.Automation.Language.Parser]::ParseInput($Content, [ref]$tokens, [ref]$errors)
    Assert-Condition ($errors.Count -eq 0) "agent scanner: invalid PowerShell in $Source"
    $exemption = $null
    if ($Source -ceq 'scripts/verify-package.ps1') {
      $declarations = @($syntax.FindAll({ param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -ceq '$forbiddenAgentIds'
      }, $true))
      Assert-Condition ($declarations.Count -eq 1) 'agent scanner: expected exactly one vocabulary declaration'
      $exemption = $declarations[0].Right.Extent
    }
    # Token offsets retain comments and all string forms, while excluding keywords.
    $segments = @(foreach ($token in $tokens) {
      if ($token.Kind -notin @('Comment', 'StringLiteral', 'StringExpandable', 'HereStringLiteral', 'HereStringExpandable', 'Generic')) { continue }
      if ($exemption -and $token.Extent.StartOffset -ge $exemption.StartOffset -and $token.Extent.EndOffset -le $exemption.EndOffset) { continue }
      # The common-parameter enum is language configuration, not an agent name.
      if ($token.Text -ceq ('Con' + 'tinue') -and $Content.Substring(0, $token.Extent.StartOffset) -match '-ErrorAction\s+$') { continue }
      $token.Text
    })
  }
  $pattern = '(?i)(?<![a-z0-9_-])(' + (($forbiddenAgentIds | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')(?![a-z0-9_])'
  foreach ($segment in $segments) {
    foreach ($match in [regex]::Matches($segment, $pattern)) {
      # Only this ordinary English imperative is disambiguated; quoted IDs still fail.
      $ordinaryProse = $Extension -eq '.md' -and $match.Value -ieq ('con' + 'tinue') -and
        $segment.Substring($match.Index) -match ('^Con' + 'tinue (processing|working|with|to)\b') -and
        ($match.Index -eq 0 -or $segment[$match.Index - 1] -notin @('`', '"', "'"))
      Assert-Condition $ordinaryProse "agent reference: $Source contains $($match.Value)"
    }
  }
}

function Assert-AbsentPaths([string]$Directory, [string[]]$Paths) {
  foreach ($relative in $Paths) {
    Assert-Condition (-not (Test-Path -LiteralPath (Join-Path $Directory $relative))) "forbidden path: $relative"
  }
}

function Resolve-SkillFile([string]$Sibling, [string]$Installed) {
  if (Test-Path -LiteralPath $Sibling -PathType Leaf) { return [pscustomobject]@{ Path = $Sibling; Origin = 'package-sibling' } }
  if (Test-Path -LiteralPath $Installed -PathType Leaf) { return [pscustomobject]@{ Path = $Installed; Origin = 'installed-home' } }
  throw "skill file missing: tried $Sibling and $Installed"
}

function Get-PackageFiles([string]$Directory) {
  foreach ($entry in Get-ChildItem -LiteralPath $Directory -Force) {
    if ($entry.Name -in @('.git', '.dev-work')) { continue }
    Assert-Condition (-not ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)) "Unsupported linked package entry: $($entry.FullName)"
    if ($entry.PSIsContainer) { Get-PackageFiles $entry.FullName } else { $entry }
  }
}

function Invoke-Child {
  param([string]$Executable, [string[]]$Arguments, [switch]$DirtyGit, [string]$InputText = '')
  $start = [Diagnostics.ProcessStartInfo]::new()
  $start.FileName = $Executable
  $start.WorkingDirectory = $script:temporaryRoot
  $start.UseShellExecute = $false
  $start.CreateNoWindow = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  $start.RedirectStandardInput = $true
  foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
  # Isolate fixture Git from host repository/config injection; dirty cases add
  # the exact orphaned count only in the child, never in the harness process.
  foreach ($key in @($start.Environment.Keys)) {
    if ($key -like 'GIT_*' -or $key -like 'ORCA_*') { [void]$start.Environment.Remove($key) }
  }
  $start.Environment['GIT_CONFIG_NOSYSTEM'] = '1'
  $start.Environment['GIT_CONFIG_GLOBAL'] = (Join-Path $script:temporaryRoot 'empty-git-config')
  $start.Environment['GIT_TERMINAL_PROMPT'] = '0'
  if ($DirtyGit) { $start.Environment['GIT_CONFIG_COUNT'] = '2' }
  Write-Host ('COMMAND ' + $Executable + ' ' + (($Arguments | ForEach-Object { "'" + $_.Replace("'", "''") + "'" }) -join ' '))
  if ($DirtyGit) { Write-Host 'ENV GIT_CONFIG_COUNT=2; GIT_CONFIG_KEY_0 absent (child only)' }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $start
  try {
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.StandardInput.Write($InputText)
    $process.StandardInput.Close()
    if (-not $process.WaitForExit(60000)) {
      $process.Kill($true)
      $process.WaitForExit()
      throw "Child timed out after 60 seconds: $Executable"
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    Write-Host "EXIT $($process.ExitCode)"
    if ($stdout.Trim()) { Write-Host $stdout.TrimEnd() }
    if ($stderr.Trim()) { Write-Host $stderr.TrimEnd() }
    return [pscustomobject]@{ ExitCode = $process.ExitCode; Stdout = $stdout; Stderr = $stderr }
  } finally { $process.Dispose() }
}

function Invoke-FixtureGit([string[]]$Arguments, [string]$InputText = '') {
  $result = Invoke-Child $script:git $Arguments -InputText $InputText
  Assert-Condition ($result.ExitCode -eq 0) "Fixture Git failed: $($result.Stderr)"
  return $result.Stdout.Trim()
}

function New-FixtureRepository([string]$Name, [switch]$Delivery) {
  $repository = Join-Path $script:temporaryRoot $Name
  Write-Host "TEMP repository: $repository"
  $branch = if ($Delivery) { 'main' } else { 'verification-control' }
  $null = Invoke-FixtureGit @('init', '--initial-branch', $branch, '--template=', $repository)
  # Plumbing avoids checkout, index changes, hooks, and user signing settings.
  $tree = Invoke-FixtureGit @('-C', $repository, 'hash-object', '-t', 'tree', '-w', '--stdin')
  $commit = Invoke-FixtureGit @('-C', $repository, '-c', 'user.name=Package Verification', '-c', 'user.email=verify@example.invalid', 'commit-tree', $tree, '-m', 'Temporary verification fixture')
  $null = Invoke-FixtureGit @('-C', $repository, 'update-ref', "refs/heads/$branch", $commit)
  if (-not $Delivery) { $null = Invoke-FixtureGit @('-C', $repository, 'update-ref', 'refs/heads/main', $commit) }
  return $repository
}

function New-FixtureCommit {
  param([string]$Worktree, [string]$FileName, [string]$Content, [string]$Message)
  [IO.File]::WriteAllText((Join-Path $Worktree $FileName), $Content, $utf8)
  $null = Invoke-FixtureGit @('-C', $Worktree, 'add', $FileName)
  $null = Invoke-FixtureGit @('-C', $Worktree, 'commit', '-m', $Message)
  return Invoke-FixtureGit @('-C', $Worktree, 'rev-parse', 'HEAD')
}

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

function Get-FileTreeSnapshot {
  param([string[]]$Roots)
  $entries = foreach ($rootDirectory in $Roots) {
    foreach ($file in Get-ChildItem -LiteralPath $rootDirectory -Recurse -Force -File) {
      $file.FullName + ':' + (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
  }
  return @($entries | Sort-Object)
}

function Invoke-PackageScript([string]$Name, [string[]]$Arguments, [switch]$DirtyGit) {
  Invoke-Child $script:pwsh (@('-NoProfile', '-NonInteractive', '-File', (Join-Path $script:stagedPackage "scripts/$Name")) + $Arguments) -DirtyGit:$DirtyGit
}

function Assert-OkResult($Result) {
  Assert-Condition ($Result.ExitCode -eq 0) "Expected exit 0, got $($Result.ExitCode): $($Result.Stderr) $($Result.Stdout)"
  $document = $Result.Stdout | ConvertFrom-Json
  Assert-Condition ($document.ok -eq $true) "Expected ok:true: $($Result.Stdout)"
}

try {
  $root = (Resolve-Path -LiteralPath $PackageRoot).Path
  Assert-Condition (Test-Path -LiteralPath $root -PathType Container) "Not a package directory: $root"
  Write-Host "PACKAGE $root"
  $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('orca-package-verification-' + [guid]::NewGuid().ToString('N'))
  [void][IO.Directory]::CreateDirectory($temporaryRoot)
  Write-Host "TEMP root: $temporaryRoot"
  [IO.File]::WriteAllText((Join-Path $temporaryRoot 'empty-git-config'), '', $utf8)
  $pwsh = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
  $git = (Get-Command git -CommandType Application | Select-Object -First 1).Source
  $files = @(Get-PackageFiles $root)
  $scripts = @('assemble-task.ps1', 'bootstrap-project.ps1', 'create-run.ps1', 'probe-claude-capabilities.ps1', 'reconcile-state.ps1', 'release-coordinator.ps1', 'validate-run.ps1', 'validate-git-evidence.ps1')
  foreach ($name in $scripts + @('verify-package.ps1')) {
    Invoke-Check "parse/$name" {
      $path = Join-Path $root "scripts/$name"
      Assert-Condition (Test-Path -LiteralPath $path -PathType Leaf) "Missing script: $path"
      $tokens = $null
      $parseErrors = $null
      [void][Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors)
      Assert-Condition ($parseErrors.Count -eq 0) (($parseErrors | ForEach-Object Message) -join '; ')
    }
  }
  Invoke-Check 'encoding/utf8-no-bom-lf' {
    $violations = @(foreach ($file in $files) {
      $bytes = [IO.File]::ReadAllBytes($file.FullName)
      try { $content = $utf8.GetString($bytes) } catch { "$($file.FullName): invalid UTF-8"; continue }
      if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xef -and $bytes[1] -eq 0xbb -and $bytes[2] -eq 0xbf) { "$($file.FullName): BOM" }
      if ($content.Contains("`r")) { "$($file.FullName): CR" }
    })
    Assert-Condition ($violations.Count -eq 0) ($violations -join '; ')
    Write-Host "ENCODING $($files.Count) package files checked (excluding .git and .dev-work)"
  }
  Invoke-Check 'routing/model-routing-schema' {
    Assert-ModelRouting (Read-PackageJson 'routing/model-routing.json') (Read-PackageJson 'roles/catalog.json')
  }
  Invoke-Check 'routing/role-selection-valid' {
    Assert-RoleSelection (Read-PackageJson 'routing/role-selection.json') (Read-PackageJson 'roles/catalog.json')
  }
  Invoke-Check 'package/claude-only' {
    Assert-AbsentPaths $root @('agents', 'adapters')
    Assert-Condition ($forbiddenAgentIds.Count -eq 42) 'Expected 42 excluded agent IDs'
    foreach ($file in $files) {
      $relative = [IO.Path]::GetRelativePath($root, $file.FullName).Replace('\', '/')
      if ($relative -ceq 'CHANGELOG.md') { continue }
      Assert-ClaudeText ([IO.File]::ReadAllText($file.FullName, $utf8)) $file.Extension $relative
    }
  }
  Invoke-Check 'package/no-mirror-tables' {
    Assert-AbsentPaths $root @('agents/role-compatibility.json', 'routing/agent-selection.json')
  }
  Invoke-Check 'metadata/entry-outline' {
    $entryPath = Join-Path $root 'SKILL.md'
    $lines = [IO.File]::ReadAllLines($entryPath, $utf8)
    Assert-Condition ($lines.Count -le 250) "Entry has $($lines.Count) lines; limit is 250"
    $expected = @('Purpose', 'Coordinator-only guard', 'System boundaries', 'Required invariants', 'Bootstrap', 'Workflow selection', 'Dynamic reconnaissance', 'Role and Skill routing', 'Model and effort routing', 'Skill delivery', 'Task and branch creation', 'Worker input order', 'Execution loop', 'Review and integration', 'Degradation and handoff', 'Completion', 'Do not do')
    $headings = @($lines | Where-Object { $_.StartsWith('## ') } | ForEach-Object { $_.Substring(3) })
    Assert-Condition (($headings -join '|') -ceq ($expected -join '|')) 'Entry must contain all 17 sections in order'
    Write-Host "ENTRY $($lines.Count) lines; 17 sections"
  }
  Invoke-Check 'metadata/role-paths' {
    foreach ($role in (Read-PackageJson 'roles/catalog.json').roles) {
      Assert-Condition (-not [string]::IsNullOrWhiteSpace($role.path)) "Role $($role.id) has no path"
      $path = Join-Path $root $role.path
      Assert-Condition (Test-Path -LiteralPath $path -PathType Leaf) "Role $($role.id) missing at $path"
    }
  }
  $resolvedSkills = [Collections.Generic.List[object]]::new()
  Invoke-Check 'metadata/skill-paths' {
    $missing = [Collections.Generic.List[string]]::new()
    foreach ($skill in (Read-PackageJson 'routing/skill-catalog.json').skills) {
      Assert-Condition ($skill.id -match '^[a-z0-9][a-z0-9-]*$') "Invalid skill ID: $($skill.id)"
      $expected = "../$($skill.id)/SKILL.md"
      Assert-Condition ($skill.path.Replace('\', '/') -ceq $expected) "Unexpected catalog path for $($skill.id): $($skill.path)"
      $sibling = [IO.Path]::GetFullPath((Join-Path $root $expected))
      $installed = [IO.Path]::GetFullPath((Join-Path ([Environment]::GetFolderPath('UserProfile')) ".agents/skills/$($skill.id)/SKILL.md"))
      try { $resolved = Resolve-SkillFile $sibling $installed }
      catch { $missing.Add("$($skill.id): $($_.Exception.Message)"); continue }
      $resolvedSkills.Add([pscustomobject]@{ Id = $skill.id; Path = $resolved.Path; Origin = $resolved.Origin })
      Write-Host "SKILL $($skill.id): $($resolved.Origin) $($resolved.Path)"
    }
    Assert-Condition ($missing.Count -eq 0) ($missing -join '; ')
  }
  Invoke-Check 'metadata/manifest-counts-and-version' {
    $manifest = Read-PackageJson 'PACKAGE-MANIFEST.json'
    $version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
    Assert-Condition ($manifest.version -ceq $version) "Manifest version $($manifest.version) differs from VERSION $version"
    $counts = @{
      roles = @((Read-PackageJson 'roles/catalog.json').roles).Count
      professionalSkills = @((Read-PackageJson 'routing/skill-catalog.json').skills).Count
      workflows = @(Get-ChildItem -LiteralPath (Join-Path $root 'workflows') -Filter '*.md' -File).Count
    }
    Assert-Condition ($version -ceq '2.0.0') 'Expected release 2.0.0'
    Assert-Condition (-not $manifest.deliverables.Contains('orcaAgents') -and -not $manifest.Contains('inPlaceFixes')) 'Obsolete manifest fields remain'
    Assert-Condition ($counts.roles -eq 12 -and $counts.professionalSkills -eq 16 -and $counts.workflows -eq 4) 'Expected 12 roles, 16 professional skills, 4 workflows'
    foreach ($key in $counts.Keys) {
      Assert-Condition ($manifest.deliverables.Contains($key) -and $manifest.deliverables[$key] -eq $counts[$key]) "Manifest $key declared $($manifest.deliverables[$key]), actual $($counts[$key])"
      Write-Host "COUNT $key=$($counts[$key])"
    }
  }
  Invoke-Check 'regression/routing-contracts' {
    $catalog = Read-PackageJson 'roles/catalog.json'
    Assert-ModelRouting (Read-PackageJson 'routing/model-routing.json') $catalog
    $mutations = [ordered]@{
      'missing-role' = { param($document) $document.roles.Remove('codebase-scout') }
      'extra-role' = { param($document) $document.roles['unknown-role'] = $document.roles['codebase-scout'] }
      'empty-chain' = { param($document) $document.roles['codebase-scout'].chain = @() }
      'unknown-tier' = { param($document) $document.roles['codebase-scout'].chain[0].tier = 'unknown-tier' }
      'unknown-effort' = { param($document) $document.roles['codebase-scout'].chain[0].effort = 'unknown-effort' }
      'duplicate-step' = { param($document) $document.roles['codebase-scout'].chain[1] = $document.roles['codebase-scout'].chain[0] }
      'descending-tier' = { param($document) $document.roles['codebase-scout'].chain[0].tier = 'fable' }
      'negative-floor' = { param($document) $document.roles['codebase-scout'].floor = -1 }
      'floor-above-default' = { param($document) $document.roles['codebase-scout'].floor = 2 }
      'default-outside-chain' = { param($document) $document.roles['codebase-scout'].default = 4 }
      'fractional-default' = { param($document) $document.roles['codebase-scout'].default = 1.5 }
      'string-floor' = { param($document) $document.roles['codebase-scout'].floor = '0' }
    }
    foreach ($case in $mutations.Keys) {
      $document = Read-PackageJson 'routing/model-routing.json'
      $null = & $mutations[$case] $document
      Assert-Rejected $case { Assert-ModelRouting $document $catalog } 'routing:'
    }
    $selection = Read-PackageJson 'routing/role-selection.json'
    Assert-RoleSelection $selection $catalog
    $selection.deliverableRoutes['unknown-deliverable'] = 'unknown-role'
    Assert-Rejected 'unknown-deliverable-role' { Assert-RoleSelection $selection $catalog } 'selection:'
  }
  Invoke-Check 'regression/agent-reference-scanner' {
    foreach ($agentId in $forbiddenAgentIds) {
      foreach ($extension in @('.md', '.json', '.ps1')) {
        $sample = if ($extension -eq '.json') { '{"agent":"' + $agentId + '"}' } elseif ($extension -eq '.ps1') { '$agent = "' + $agentId + '"' } else { 'Worker agent: `' + $agentId + '`' }
        Assert-Rejected "$extension-agent-reference" { Assert-ClaudeText $sample $extension 'fixture' } 'agent reference:'
      }
      Assert-Rejected 'comment-agent-reference' { Assert-ClaudeText ('# Worker agent: ' + $agentId) '.ps1' 'fixture' } 'agent reference:'
    }
    Assert-ClaudeText ('foreach ($entry in @()) { con' + 'tinue }') '.ps1' 'fixture'
    Assert-ClaudeText ('Write-Error message -ErrorAction Con' + 'tinue') '.ps1' 'fixture'
    Assert-ClaudeText ('Con' + 'tinue processing the current task.') '.md' 'fixture'
    Assert-ClaudeText 'Use claude-haiku-4-5 with effort.' '.md' 'fixture'
    Assert-Rejected 'vocabulary-name-does-not-exempt-other-files' { Assert-ClaudeText ('$forbiddenAgentIds = @("' + $forbiddenAgentIds[0] + '")') '.ps1' 'fixture' } 'agent reference:'
  }
  $stagedPackage = Join-Path $temporaryRoot 'skills/orca-project-delivery'
  Invoke-Check 'fixtures/stage-package-and-skills' {
    [void][IO.Directory]::CreateDirectory($stagedPackage)
    Write-Host "TEMP package copy: $stagedPackage"
    foreach ($file in $files) {
      $destination = Join-Path $stagedPackage ([IO.Path]::GetRelativePath($root, $file.FullName))
      [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
      Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
    foreach ($skill in $resolvedSkills) {
      $destination = Join-Path $temporaryRoot "skills/$($skill.Id)"
      Write-Host "TEMP skill copy: $destination"
      Copy-Item -LiteralPath (Split-Path -Parent $skill.Path) -Destination $destination -Recurse
    }
    Assert-Condition ($resolvedSkills.Count -eq @((Read-PackageJson 'routing/skill-catalog.json').skills).Count) 'Cannot stage every declared skill'
  }
  Invoke-Check 'regression/skill-path-resolution' {
    $sibling = Join-Path $temporaryRoot 'sibling-skill.md'
    $installed = Join-Path $temporaryRoot 'installed-skill.md'
    Assert-Rejected 'missing-both-skill-paths' { Resolve-SkillFile $sibling $installed } 'skill file missing:'
    [void][IO.Directory]::CreateDirectory($sibling)
    Assert-Rejected 'skill-path-is-directory' { Resolve-SkillFile $sibling $installed } 'skill file missing:'
    Remove-Item -LiteralPath $sibling
    [IO.File]::WriteAllText($installed, 'installed skill', $utf8)
    Assert-Condition ((Resolve-SkillFile $sibling $installed).Origin -eq 'installed-home') 'Installed fallback failed'
    [IO.File]::WriteAllText($sibling, 'sibling skill', $utf8)
    Assert-Condition ((Resolve-SkillFile $sibling $installed).Origin -eq 'package-sibling') 'Sibling precedence failed'
  }
  Invoke-Check 'regression/forbidden-paths' {
    $fixture = Join-Path $temporaryRoot 'forbidden-path-fixture'
    [void][IO.Directory]::CreateDirectory($fixture)
    $paths = @('agents', 'adapters', 'agents/role-compatibility.json', 'routing/agent-selection.json')
    Assert-AbsentPaths $fixture $paths
    foreach ($relative in $paths) {
      $path = Join-Path $fixture $relative
      [void][IO.Directory]::CreateDirectory((Split-Path -Parent $path))
      if ([IO.Path]::GetExtension($path)) { [IO.File]::WriteAllText($path, '{}', $utf8) }
      else { [void][IO.Directory]::CreateDirectory($path) }
      Assert-Rejected $relative { Assert-AbsentPaths $fixture @($relative) } 'forbidden path:'
      Remove-Item -LiteralPath $path -Recurse -Force
    }
  }
  $healthyRepository = $null
  Invoke-Check 'runtime/bootstrap-create-validate-templates' {
    $script:healthyRepository = New-FixtureRepository 'healthy-repository'
    Assert-OkResult (Invoke-PackageScript 'bootstrap-project.ps1' @('-ProjectRoot', $healthyRepository))
    Assert-OkResult (Invoke-PackageScript 'create-run.ps1' @('-ProjectRoot', $healthyRepository, '-Objective', 'Offline package verification', '-RunSlug', 'package-verification'))
    Assert-OkResult (Invoke-PackageScript 'validate-run.ps1' @('-ProjectRoot', $healthyRepository, '-IncludeTemplates'))
  }
  Invoke-Check 'runtime/dirty-git-bootstrap-and-create' {
    $repository = New-FixtureRepository 'dirty-git-repository'
    Assert-OkResult (Invoke-PackageScript 'bootstrap-project.ps1' @('-ProjectRoot', $repository) -DirtyGit)
    Assert-OkResult (Invoke-PackageScript 'create-run.ps1' @('-ProjectRoot', $repository, '-Objective', 'Dirty Git environment verification', '-RunSlug', 'dirty-git-verification') -DirtyGit)
  }
  Invoke-Check 'runtime/delivery-branch-refusal-zero-writes' {
    $repository = New-FixtureRepository 'delivery-repository' -Delivery
    $before = @(Get-ChildItem -LiteralPath $repository -Recurse -Force -File | ForEach-Object { $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash })
    $result = Invoke-PackageScript 'bootstrap-project.ps1' @('-ProjectRoot', $repository)
    Assert-Condition ($result.ExitCode -ne 0) 'Bootstrap accepted the delivery branch'
    foreach ($name in @('AGENTS.md', '.dev-work')) {
      Assert-Condition (-not (Test-Path -LiteralPath (Join-Path $repository $name))) "Bootstrap wrote $name on the delivery branch"
    }
    $after = @(Get-ChildItem -LiteralPath $repository -Recurse -Force -File | ForEach-Object { $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash })
    Assert-Condition (-not (Compare-Object $before $after)) 'Bootstrap changed repository files before refusing'
    # Check diagnostic topics independently of word order, quotes, or resolution details.
    $diagnostic = $result.Stdout + $result.Stderr
    Assert-Condition ($diagnostic -imatch '\bcontrol\s+branch\b' -and $diagnostic -imatch '\bdelivery\s+branch\b') 'Bootstrap refusal must name both the control branch and delivery branch'
  }
  Invoke-Check 'runtime/package-routing-negative-cases' {
    $cases = @(
      @{ Path = 'routing/model-routing.json'; Change = { param($document) $document.roles.Remove('codebase-scout') }; Diagnostic = "Catalog role 'codebase-scout'" },
      @{ Path = 'routing/model-routing.json'; Change = { param($document) $document.roles['unknown-role'] = $document.roles['codebase-scout'] }; Diagnostic = "Routing role 'unknown-role'" },
      @{ Path = 'routing/role-selection.json'; Change = { param($document) $document.deliverableRoutes['unknown-deliverable'] = 'unknown-role' }; Diagnostic = "unknown role 'unknown-role'" },
      @{ Path = 'roles/catalog.json'; Change = { param($document) $document.roles[0].path = 'missing-role.md' }; Diagnostic = 'path not found' },
      @{ Path = 'roles/catalog.json'; Change = { param($document) $document.roles[0].defaultSkills = @('unknown-skill') }; Diagnostic = "unknown skill 'unknown-skill'" }
    )
    foreach ($case in $cases) {
      $path = Join-Path $stagedPackage $case.Path
      $original = [IO.File]::ReadAllBytes($path)
      try {
        $document = [IO.File]::ReadAllText($path) | ConvertFrom-Json -AsHashtable
        $null = & $case.Change $document
        [IO.File]::WriteAllText($path, ($document | ConvertTo-Json -Depth 100), $utf8)
        $result = Invoke-PackageScript 'validate-run.ps1' @('-ProjectRoot', $healthyRepository)
        Assert-Condition ($result.ExitCode -eq 1) 'Expected package contract failure exit 1'
        $validation = $result.Stdout | ConvertFrom-Json
        Assert-Condition ($validation.ok -eq $false -and ($validation.errors -join ';').Contains($case.Diagnostic)) "Expected diagnostic $($case.Diagnostic)"
        Write-Host "REJECTED runtime $($case.Diagnostic)"
      } finally { [IO.File]::WriteAllBytes($path, $original) }
    }
    Assert-OkResult (Invoke-PackageScript 'validate-run.ps1' @('-ProjectRoot', $healthyRepository))
  }
  Invoke-Check 'runtime/schema-missing-evidence-path' {
    Assert-Condition ([bool]$healthyRepository) 'Healthy fixture unavailable'
    $definition = Read-PackageJson 'templates/task-definition.json'
    $assignment = Read-PackageJson 'templates/dev-work/assignment.json'
    $assignment.taskKey = 'schema-verification'
    $assignment.role = $definition.role
    $assignment.skills = $definition.skills
    $assignment.branch = $definition.branch
    $assignment.artifacts = $definition.artifacts
    $assignmentPath = Join-Path $healthyRepository '.dev-work/runs/package-verification/assignments/schema-verification.json'
    [IO.File]::WriteAllText($assignmentPath, ($assignment | ConvertTo-Json -Depth 100), $utf8)
    # First prove the identical fixture is valid; then remove exactly one field.
    Assert-OkResult (Invoke-PackageScript 'validate-run.ps1' @('-ProjectRoot', $healthyRepository, '-IncludeTemplates'))
    $assignment.artifacts.Remove('evidencePath')
    [IO.File]::WriteAllText($assignmentPath, ($assignment | ConvertTo-Json -Depth 100), $utf8)
    $result = Invoke-PackageScript 'validate-run.ps1' @('-ProjectRoot', $healthyRepository, '-IncludeTemplates')
    Assert-Condition ($result.ExitCode -eq 1) "Expected schema failure exit 1, got $($result.ExitCode)"
    $document = $result.Stdout | ConvertFrom-Json
    Assert-Condition ($document.ok -eq $false -and ($document.errors -join '\n') -match 'artifacts\.evidencePath') "Missing evidence-path diagnostic: $($result.Stdout)"
  }
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
        $validatorPath = Join-Path $stagedPackage 'scripts/validate-git-evidence.ps1'
        $original = [IO.File]::ReadAllText($validatorPath, $utf8)
        $exemption = "if (`$formal -and `$assignment.status -ceq 'superseded')"
        $pointerCheck = 'Test-SupersededAssignment $assignment $assignments $enteredStatuses'
        Assert-Condition ($original.Contains($exemption) -and $original.Contains($pointerCheck)) 'Superseded mutation targets missing'
        try {
          [IO.File]::WriteAllText($validatorPath, $original.Replace($exemption, 'if ($false)'), $utf8)
          $result = Invoke-EvidenceValidator @('-Run', $fixture.RunSlug, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)
          Assert-Rejected 'removed superseded exemption' { Assert-EvidenceStatus $result 'PASS' 'superseded positive assertion' } 'expected status PASS'
          [IO.File]::WriteAllText($validatorPath, $original.Replace($pointerCheck, ''), $utf8)
          $rework.Remove('supersededBy')
          Write-EvidenceJson (Join-Path $assignmentDirectory 'rework-round.json') $rework
          $result = Invoke-EvidenceValidator @('-Run', $fixture.RunSlug, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)
          Assert-Rejected 'removed superseded pointer check' { Assert-EvidenceStatus $result 'FAIL' 'superseded negative assertion' } 'expected status FAIL'
        } finally { [IO.File]::WriteAllText($validatorPath, $original, $utf8) }
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
    $validatorPath = Join-Path $stagedPackage 'scripts/validate-git-evidence.ps1'
    $validatorLines = [IO.File]::ReadAllLines($validatorPath, $utf8)
    $mutatedLines = @($validatorLines | Where-Object { $_ -notmatch 'requires the recorded merge parents' })
    Assert-Condition ($mutatedLines.Count -lt $validatorLines.Count) 'Parent-binding mutation did not remove the assertion'
    [IO.File]::WriteAllText($validatorPath, (($mutatedLines | ForEach-Object { $_ + "`n" }) -join ''), $utf8)
    try {
      $mutantResult = Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'postMerge', '-ProjectRoot', $fixture.ProjectRoot)
      Assert-Condition (((($mutantResult.Stdout | ConvertFrom-Json).status) -ceq 'PASS')) 'Removing parent-binding assertion must allow wrong-parent evidence (mutation should fail suite if assertion removed)'
    } finally {
      [IO.File]::WriteAllText($validatorPath, (($validatorLines | ForEach-Object { $_ + "`n" }) -join ''), $utf8)
    }
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
    $validatorPath = Join-Path $stagedPackage 'scripts/validate-git-evidence.ps1'
    $validatorLines = [IO.File]::ReadAllLines($validatorPath, $utf8)
    $mutatedLines = @($validatorLines | ForEach-Object { if ($_ -match 'if \(-not \$CoverageTaskKey') { $_ -replace 'if \(-not \$CoverageTaskKey -or \$assignment\.taskKey -ceq \$CoverageTaskKey\)', 'if ($true)' } else { $_ } })
    Assert-Condition ((Compare-Object $validatorLines $mutatedLines).Count -gt 0) 'CoverageTaskKey guard mutation did not change validator'
    [IO.File]::WriteAllText($validatorPath, (($mutatedLines | ForEach-Object { $_ + "`n" }) -join ''), $utf8)
    try {
      $mutantResult = Invoke-EvidenceValidator @('-EvidencePath', $evidencePath, '-Phase', 'review', '-ProjectRoot', $fixture.ProjectRoot)
      Assert-Condition (((($mutantResult.Stdout | ConvertFrom-Json).status) -ceq 'FAIL')) 'Removing CoverageTaskKey guard must restore over-strict -EvidencePath rejection'
    } finally {
      [IO.File]::WriteAllText($validatorPath, (($validatorLines | ForEach-Object { $_ + "`n" }) -join ''), $utf8)
    }
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
} catch {
  $failed++
  Write-Host "FAIL harness/setup: $($_.Exception.Message)"
} finally {
  if ($temporaryRoot) {
    Invoke-Check 'cleanup/temporary-root' {
      $resolvedTemporary = [IO.Path]::GetFullPath($temporaryRoot)
      $tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
      Assert-Condition ($resolvedTemporary.StartsWith($tempParent, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolvedTemporary) -like 'orca-package-verification-*') "Refusing unsafe cleanup: $resolvedTemporary"
      if (Test-Path -LiteralPath $resolvedTemporary) { Remove-Item -LiteralPath $resolvedTemporary -Recurse -Force }
      Assert-Condition (-not (Test-Path -LiteralPath $resolvedTemporary)) "Temporary root remains: $resolvedTemporary"
      Write-Host "CLEANED $resolvedTemporary"
    }
  }
}
if ($null -ne $resolvedSkills) {
  $siblings = @($resolvedSkills | Where-Object Origin -eq 'package-sibling').Count
  $installed = @($resolvedSkills | Where-Object Origin -eq 'installed-home').Count
  $declaredCount = try { @((Read-PackageJson 'routing/skill-catalog.json').skills).Count } catch { '?' }
  Write-Host "skills: $($resolvedSkills.Count)/$declaredCount resolved ($siblings package-sibling, $installed installed-home)"
}
Write-Host "SUMMARY PASS=$passed FAIL=$failed"
if ($failed -gt 0) { exit 1 }
exit 0
