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
  $scripts = @('assemble-task.ps1', 'bootstrap-project.ps1', 'create-run.ps1', 'probe-claude-capabilities.ps1', 'reconcile-state.ps1', 'release-coordinator.ps1', 'validate-run.ps1')
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
