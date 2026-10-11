function Test-ProjectLifecycle {
  $script:healthyRepository = $null
  Invoke-Check 'runtime/bootstrap-create-validate-templates' {
    $script:healthyRepository = New-FixtureRepository 'healthy-repository'
    Assert-OkResult (Invoke-PackageScript 'bootstrap-project.ps1' @('-ProjectRoot', $healthyRepository))
    foreach ($name in @('.env.example', 'project-config.example.json')) {
      Assert-Condition (Test-Path -LiteralPath (Join-Path $healthyRepository $name) -PathType Leaf) "Bootstrap example missing: $name"
    }
    $examplePath = Join-Path $healthyRepository '.env.example'
    [IO.File]::WriteAllText($examplePath, "# preserved project example`n", $utf8)
    Assert-OkResult (Invoke-PackageScript 'bootstrap-project.ps1' @('-ProjectRoot', $healthyRepository, '-ForceLock'))
    Assert-Condition ([IO.File]::ReadAllText($examplePath) -ceq "# preserved project example`n") 'Bootstrap overwrote project example'
    $exclude = Invoke-FixtureGit @('-C', $healthyRepository, 'check-ignore', '.env')
    Assert-Condition ($exclude -eq '.env') 'Bootstrap did not exclude local dotenv'
    Assert-OkResult (Invoke-PackageScript 'create-run.ps1' @('-ProjectRoot', $healthyRepository, '-Objective', 'Offline package verification', '-RunSlug', 'package-verification'))
    foreach ($directory in @('assignments', 'attempts', 'dispatch-receipts', 'dispatch-waves', 'handoffs', 'reconnaissance', 'audits', 'plans', 'task-briefs', 'worker-reports', 'reviews', 'verification', 'evidence', 'evidence/git')) {
      Assert-Condition (Test-Path -LiteralPath (Join-Path $healthyRepository ".dev-work/runs/package-verification/$directory") -PathType Container) "Run directory missing: $directory"
      Write-Host "DIRECTORY PASS $directory"
    }
    Assert-OkResult (Invoke-PackageScript 'validate-run.ps1' @('-ProjectRoot', $healthyRepository, '-IncludeTemplates'))
  }
  Invoke-Check 'regression/assemble-task-skill-paths' {
    Assert-Condition ([bool]$healthyRepository) 'Healthy fixture unavailable'
    $skillsDir = Join-Path $stagedPackage 'skills'
    $taskPath = Join-Path $temporaryRoot 'assemble-task-explicit.json'
    $outputPath = Join-Path $temporaryRoot 'assemble-task-explicit.md'
    $task = [ordered]@{
      schemaVersion = 1
      taskKey = 'assemble-fixture'
      title = 'Assemble fixture'
      objective = 'Offline assemble regression'
      role = 'software-implementer'
      skills = [ordered]@{ required = @('test-driven-development'); conditional = @('integration-verification') }
      skillDeliveryMode = 'explicit-path'
      inputs = @()
      allowedScope = @()
      forbiddenScope = @()
      branch = [ordered]@{ delivery = 'main'; base = 'main'; work = 'fixture/assemble'; mergeTarget = 'main'; worktree = $healthyRepository }
      artifacts = [ordered]@{ reportPath = (Join-Path $temporaryRoot 'report.md'); evidencePath = '' }
      acceptance = @('paths resolve')
      tests = @()
      orca = [ordered]@{ runId = 'run_test'; taskId = 'task_test'; dispatchId = 'ctx_test' }
      applicableAgentsFiles = @()
    }
    [IO.File]::WriteAllText($taskPath, ($task | ConvertTo-Json -Depth 10), $utf8)
    Assert-OkResult (Invoke-PackageScript 'assemble-task.ps1' @('-ProjectRoot', $healthyRepository, '-TaskDefinitionPath', $taskPath, '-OutputPath', $outputPath))
    $assembled = [IO.File]::ReadAllText($outputPath, $utf8)
    $bundledTdd = (Join-Path $skillsDir 'test-driven-development/SKILL.md').Replace('\', '/')
    Assert-Condition ($assembled.Contains($bundledTdd.Replace('/', '\')) -or $assembled.Contains($bundledTdd)) 'Explicit-path output must reference bundled test-driven-development path'
    $inlineTaskPath = Join-Path $temporaryRoot 'assemble-task-inline.json'
    $inlineOutput = Join-Path $temporaryRoot 'assemble-task-inline.md'
    $task.skillDeliveryMode = 'inline-extract'
    [IO.File]::WriteAllText($inlineTaskPath, ($task | ConvertTo-Json -Depth 10), $utf8)
    Assert-OkResult (Invoke-PackageScript 'assemble-task.ps1' @('-ProjectRoot', $healthyRepository, '-TaskDefinitionPath', $inlineTaskPath, '-OutputPath', $inlineOutput))
    $inlined = [IO.File]::ReadAllText($inlineOutput, $utf8)
    $sourceBody = [IO.File]::ReadAllText((Join-Path $skillsDir 'test-driven-development/SKILL.md'), $utf8).Trim()
    Assert-Condition ($inlined.Contains($sourceBody.Substring(0, [Math]::Min(80, $sourceBody.Length)))) 'inline-extract must include bundled Skill body'
  }
  Invoke-Check 'regression/standalone-relocated-package' {
    Assert-Condition ([bool]$healthyRepository) 'Healthy fixture unavailable'
    $relocated = Join-Path $temporaryRoot 'relocated-orca-project-delivery'
    if (Test-Path -LiteralPath $relocated) { Remove-Item -LiteralPath $relocated -Recurse -Force }
    Copy-Item -LiteralPath $stagedPackage -Destination $relocated -Recurse
    $taskPath = Join-Path $temporaryRoot 'assemble-task-relocated.json'
    $outputPath = Join-Path $temporaryRoot 'assemble-task-relocated.md'
    $task = [ordered]@{
      schemaVersion = 1
      taskKey = 'relocated-fixture'
      title = 'Relocated package fixture'
      objective = 'Standalone bundled skills'
      role = 'software-implementer'
      skills = [ordered]@{ required = @('test-driven-development'); conditional = @() }
      skillDeliveryMode = 'explicit-path'
      inputs = @()
      allowedScope = @()
      forbiddenScope = @()
      branch = [ordered]@{ delivery = 'main'; base = 'main'; work = 'fixture/relocated'; mergeTarget = 'main'; worktree = $healthyRepository }
      artifacts = [ordered]@{ reportPath = (Join-Path $temporaryRoot 'report-relocated.md'); evidencePath = '' }
      acceptance = @()
      tests = @()
      orca = [ordered]@{ runId = 'run_test'; taskId = 'task_test'; dispatchId = 'ctx_test' }
      applicableAgentsFiles = @()
    }
    [IO.File]::WriteAllText($taskPath, ($task | ConvertTo-Json -Depth 10), $utf8)
    $relocatedScript = Join-Path $relocated 'scripts/assemble-task.ps1'
    $ok = Invoke-Child $pwsh @('-NoProfile', '-NonInteractive', '-File', $relocatedScript, '-ProjectRoot', $healthyRepository, '-TaskDefinitionPath', $taskPath, '-OutputPath', $outputPath)
    Assert-Condition ($ok.ExitCode -eq 0) "Relocated assemble-task failed: $($ok.Stderr) $($ok.Stdout)"
    $missingSkill = Join-Path $relocated 'skills/test-driven-development/SKILL.md'
    Remove-Item -LiteralPath $missingSkill -Force
    $fail = Invoke-Child $pwsh @('-NoProfile', '-NonInteractive', '-File', $relocatedScript, '-ProjectRoot', $healthyRepository, '-TaskDefinitionPath', $taskPath, '-OutputPath', (Join-Path $temporaryRoot 'assemble-task-should-fail.md'))
    Assert-Condition ($fail.ExitCode -ne 0) 'assemble-task must fail when bundled Skill is missing'
    $globalDecoy = Join-Path $temporaryRoot 'decoy-skills/test-driven-development/SKILL.md'
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $globalDecoy))
    [IO.File]::WriteAllText($globalDecoy, 'decoy sibling skill', $utf8)
    $failWithDecoy = Invoke-Child $pwsh @('-NoProfile', '-NonInteractive', '-File', $relocatedScript, '-ProjectRoot', $healthyRepository, '-TaskDefinitionPath', $taskPath, '-OutputPath', (Join-Path $temporaryRoot 'assemble-task-decoy-fail.md'))
    Assert-Condition ($failWithDecoy.ExitCode -ne 0) 'assemble-task must not resolve a decoy outside the package skills directory'
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
}
