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

# Sort object keys recursively, but retain array order and scalar types.
function ConvertTo-CanonicalValue($Value) {
  if ($Value -is [Collections.IDictionary]) {
    $ordered = [ordered]@{}
    foreach ($key in @($Value.Keys | Sort-Object -CaseSensitive)) {
      $ordered[$key] = ConvertTo-CanonicalValue $Value[$key]
    }
    return $ordered
  }
  if ($Value -is [array]) {
    $items = @(foreach ($item in $Value) { ConvertTo-CanonicalValue $item })
    return ,$items
  }
  return $Value
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
  $scripts = @('assemble-task.ps1', 'bootstrap-project.ps1', 'create-run.ps1', 'probe-agent-capabilities.ps1', 'reconcile-state.ps1', 'release-coordinator.ps1', 'validate-run.ps1')
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
  Invoke-Check 'metadata/routing-equivalence' {
    $selection = (Read-PackageJson 'routing/agent-selection.json').roleRoutes
    $compatibility = (Read-PackageJson 'agents/role-compatibility.json').roles
    Assert-Condition ($selection.Count -gt 0 -and $compatibility.Count -gt 0) 'Routing maps must be nonempty'
    $left = ConvertTo-CanonicalValue $selection | ConvertTo-Json -Depth 100 -Compress
    $right = ConvertTo-CanonicalValue $compatibility | ConvertTo-Json -Depth 100 -Compress
    Assert-Condition ($left -ceq $right) 'Normalized roleRoutes and roles differ'
  }
  Invoke-Check 'metadata/profiles-and-routing-order' {
    $profiles = @{}
    foreach ($profile in (Read-PackageJson 'agents/configured-profiles.json').profiles) {
      Assert-Condition (-not $profiles.ContainsKey($profile.id)) "Duplicate profile: $($profile.id)"
      $profiles[$profile.id] = $profile.autoRouteAfterProbe
    }
    foreach ($routes in @((Read-PackageJson 'routing/agent-selection.json').roleRoutes, (Read-PackageJson 'agents/role-compatibility.json').roles)) {
      foreach ($role in $routes.Keys) {
        $excluded = $null
        foreach ($profileId in $routes[$role].preferredProfiles) {
          Assert-Condition ($profiles.ContainsKey($profileId)) "Role $role references unknown profile $profileId"
          if ($profiles[$profileId] -eq $true) {
            Assert-Condition (-not $excluded) "Role $role auto-routeable $profileId follows excluded $excluded"
          } else { $excluded = $profileId }
        }
      }
    }
  }
  Invoke-Check 'routing/claude-first' {
    $eligibleIds = @(foreach ($profile in (Read-PackageJson 'agents/configured-profiles.json').profiles) {
      if ($profile.autoRouteAfterProbe -is [bool] -and $profile.autoRouteAfterProbe -eq $true) { $profile.id }
    })
    $routes = (Read-PackageJson 'routing/agent-selection.json').roleRoutes
    Assert-Condition ($routes -is [Collections.IDictionary] -and $routes.Count -gt 0) 'routing/agent-selection.json has no roleRoutes to check'
    foreach ($role in $routes.Keys) {
      $entry = $routes[$role]
      $hasCandidates = $entry -is [Collections.IDictionary] -and $entry.Contains('preferredProfiles')
      $candidates = $null
      if ($hasCandidates) { $candidates = $entry['preferredProfiles'] }
      $first = $null
      $actual = '<missing>'
      if ($candidates -is [array]) {
        if ($candidates.Count -gt 0) {
          $first = $candidates[0]
          $actual = ConvertTo-Json -InputObject $first -Depth 100 -Compress
        }
      } elseif ($hasCandidates) {
        $actual = '<not-an-array>'
      }
      $valid = $candidates -is [array] -and $candidates.Count -gt 0 -and
        $first -is [string] -and -not [string]::IsNullOrWhiteSpace($first) -and
        $first -clike 'claude-*' -and $eligibleIds -ccontains $first
      Assert-Condition $valid "Role '$role' preferredProfiles[0]=$actual; expected an existing claude-* profile with autoRouteAfterProbe=true in agents/configured-profiles.json"
    }
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
      $source = $null
      $origin = $null
      if (Test-Path -LiteralPath $sibling -PathType Leaf) { $source = $sibling; $origin = 'package-sibling' }
      elseif (Test-Path -LiteralPath $installed -PathType Leaf) { $source = $installed; $origin = 'installed-home' }
      else { $missing.Add("$($skill.id): tried $sibling and $installed"); continue }
      $resolvedSkills.Add([pscustomobject]@{ Id = $skill.id; Path = $source; Origin = $origin })
      Write-Host "SKILL $($skill.id): $origin $source"
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
      orcaAgents = @((Read-PackageJson 'agents/registry.json').agents).Count
      workflows = @(Get-ChildItem -LiteralPath (Join-Path $root 'workflows') -Filter '*.md' -File).Count
    }
    foreach ($key in $counts.Keys) {
      Assert-Condition ($manifest.deliverables.Contains($key) -and $manifest.deliverables[$key] -eq $counts[$key]) "Manifest $key declared $($manifest.deliverables[$key]), actual $($counts[$key])"
      Write-Host "COUNT $key=$($counts[$key])"
    }
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
