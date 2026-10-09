#requires -Version 7.0
[CmdletBinding()]
param([string]$PackageRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$utf8 = [Text.UTF8Encoding]::new($false)
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('orca-requirements-' + [guid]::NewGuid().ToString('N'))
$passed = 0
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Save-Json($Path, $Document) { [IO.File]::WriteAllText($Path, (($Document | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n"), $utf8) }
function Run-Script([string]$Name, [string[]]$Arguments, [hashtable]$Environment = @{}) {
  $start = [Diagnostics.ProcessStartInfo]::new((Get-Command pwsh -CommandType Application).Source)
  $start.UseShellExecute = $false
  $start.WorkingDirectory = $temporary
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  foreach ($argument in @('-NoProfile', '-NonInteractive', '-File', (Join-Path $package "scripts/$Name")) + $Arguments) { $start.ArgumentList.Add($argument) }
  foreach ($name in @($start.Environment.Keys)) { if ($name -like 'FIXTURE_*') { [void]$start.Environment.Remove($name) } }
  foreach ($name in $Environment.Keys) { $start.Environment[$name] = $Environment[$name] }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $start
  try {
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(60000)) { $process.Kill($true); throw 'Fixture timed out' }
    return @{ Code = $process.ExitCode; Text = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult() }
  } finally { $process.Dispose() }
}
function Check([string]$Name, [scriptblock]$Body) { & $Body; $script:passed++; Write-Host "PASS requirements/$Name" }
try {
  [void][IO.Directory]::CreateDirectory($temporary)
  $package = Join-Path $temporary 'package'
  [void][IO.Directory]::CreateDirectory($package)
  foreach ($entry in Get-ChildItem -LiteralPath $PackageRoot -Force) {
    if ($entry.Name -notin @('.git', '.dev-work', 'AGENTS.md', '.env')) { Copy-Item -LiteralPath $entry.FullName -Destination $package -Recurse }
  }
  $project = Join-Path $temporary 'project with spaces'
  [void][IO.Directory]::CreateDirectory($project)
  $rolePath = Join-Path $package 'roles/catalog.json'
  $skillPath = Join-Path $package 'routing/skill-catalog.json'
  $roles = Get-Content -LiteralPath $rolePath -Raw | ConvertFrom-Json -AsHashtable
  $skills = Get-Content -LiteralPath $skillPath -Raw | ConvertFrom-Json -AsHashtable
  $roles.roles += [pscustomobject]@{ id = 'fixture-role'; name = 'Fixture Role'; category = 'engineering'; path = 'roles/engineering/fixture-role.md'; defaultSkills = @('fixture-skill'); optionalSkills = @(); requires = @{ cli = @('pwsh'); env = @(@{ name = 'FIXTURE_SECRET'; secret = $true; purpose = 'Synthetic authentication' }); api = @(@{ name = 'fixture-api'; authEnv = 'FIXTURE_SECRET'; purpose = 'Offline name check' }) } }
  $skills.skills += [pscustomobject]@{ id = 'fixture-skill'; name = 'Fixture Skill'; path = 'skills/fixture-skill/SKILL.md'; description = 'Temporary extension'; requires = @{ env = @(@{ name = 'FIXTURE_SETTING'; secret = $false; purpose = 'Synthetic setting' }, @{ name = 'FIXTURE_LITERAL'; secret = $true; purpose = 'Literal parser test' }) } }
  Save-Json $rolePath $roles
  Save-Json $skillPath $skills
  [void][IO.Directory]::CreateDirectory((Join-Path $package 'skills/fixture-skill'))
  [IO.File]::WriteAllText((Join-Path $package 'skills/fixture-skill/SKILL.md'), "---`nname: fixture-skill`ndescription: Temporary extension`n---`n# Fixture Skill`n`n## Method`nInspect synthetic data only.`n", $utf8)
  [IO.File]::WriteAllText((Join-Path $package 'roles/engineering/fixture-role.md'), "---`nid: fixture-role`n---`n# Fixture Role`nInspect synthetic data only.`n", $utf8)
  $routingPath = Join-Path $package 'routing/model-routing.json'
  $routing = Get-Content $routingPath -Raw | ConvertFrom-Json -AsHashtable
  $routing.roles['fixture-role'] = $routing.roles['software-implementer']
  Save-Json $routingPath $routing
  $manifestPath = Join-Path $package 'PACKAGE-MANIFEST.json'
  $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -AsHashtable
  $manifest.deliverables.roles++; $manifest.deliverables.professionalSkills++
  Save-Json $manifestPath $manifest
  $hash = (Get-FileHash (Join-Path $package 'skills/fixture-skill/SKILL.md')).Hash
  [IO.File]::AppendAllText((Join-Path $package 'skills/README.md'), "| ``fixture-skill/SKILL.md`` | $hash |`n", $utf8)
  $selection = @('-ProjectRoot', $project, '-Role', 'fixture-role', '-Skills', 'fixture-skill')
  Check 'missing-selected-dependencies' {
    $result = Run-Script 'check-requirements.ps1' $selection
    Assert ($result.Code -eq 1) 'Missing dependencies must exit 1'
    $document = $result.Text | ConvertFrom-Json
    Assert (-not $document.ok -and @($document.missing).Count -ge 3) 'Missing names must be reported'
  }
  $dotenv = Join-Path $project '.env'
  $config = Join-Path $project 'project-config.json'
  $literal = '$(Write-Output forbidden-execution); ${HOME} `literal` # data'
  [IO.File]::WriteAllText($dotenv, "# synthetic only`nFIXTURE_SECRET='synthetic-file-secret'`nFIXTURE_LITERAL=$literal`nFIXTURE_UNDECLARED=synthetic-unselected`n", $utf8)
  Save-Json $config @{ schemaVersion = 1; env = @{ FIXTURE_SETTING = 'synthetic-config-setting' } }
  $configuredSelection = $selection + @('-ConfigPath', 'project-config.json')
  Check 'configured-is-not-current-process' {
    $result = Run-Script 'check-requirements.ps1' $configuredSelection
    Assert ($result.Code -eq 0) 'Configured requirements must be usable by child helper'
    $document = $result.Text | ConvertFrom-Json
    $secret = $document.checks | Where-Object { $_.kind -eq 'env' -and $_.name -eq 'FIXTURE_SECRET' }
    Assert ($secret.configured -and -not $secret.availableInProcess -and $secret.availableForChild -and $secret.source -eq 'project-env-file') 'File configuration must not claim process availability'
    foreach ($value in @('synthetic-file-secret', 'synthetic-config-setting', $literal, 'synthetic-unselected')) { Assert (-not $result.Text.Contains($value)) 'Value leaked in checker diagnostics' }
  }
  Check 'literal-child-only-env-precedence-arguments-exit' {
    $child = Join-Path $project 'child fixture.ps1'
    $childBody = @'
if ($env:FIXTURE_SECRET -cne 'synthetic-process-secret') { exit 81 }
if ($env:FIXTURE_SETTING -cne 'synthetic-config-setting') { exit 82 }
if ($env:FIXTURE_LITERAL -cne '$(Write-Output forbidden-execution); ${HOME} `literal` # data') { exit 83 }
if ($env:FIXTURE_UNDECLARED) { exit 84 }
if ($env:FIXTURE_INHERITED -cne 'synthetic-inherited') { exit 85 }
if ($args.Count -ne 4 -or $args[0] -cne 'space argument' -or $args[1] -cne '' -or $args[2] -cne '"quoted"' -or $args[3] -cne '; $(not-executed)') { exit 86 }
Write-Output 'child-fixture-ok'
exit 23
'@
    [IO.File]::WriteAllText($child, $childBody, $utf8)
    $driver = Join-Path $project 'driver.ps1'
    $wrapper = (Join-Path $package 'scripts/invoke-with-requirements.ps1').Replace("'", "''")
    $body = @"
& '$wrapper' -ProjectRoot '$($project.Replace("'", "''"))' -Role fixture-role -Skills fixture-skill -ConfigPath project-config.json -Executable pwsh -Arguments @('-NoProfile', '-File', '$($child.Replace("'", "''"))', 'space argument', '', '"quoted"', '; `$(not-executed)')
`$childCode = `$LASTEXITCODE
if (`$env:FIXTURE_SETTING -or `$env:FIXTURE_LITERAL -or `$env:FIXTURE_UNDECLARED -or `$env:FIXTURE_SECRET -cne 'synthetic-process-secret') { exit 87 }
exit `$childCode
"@
    [IO.File]::WriteAllText($driver, $body, $utf8)
    $result = Run-Script '../../project with spaces/driver.ps1' @() @{ FIXTURE_SECRET = 'synthetic-process-secret'; FIXTURE_INHERITED = 'synthetic-inherited' }
    Assert ($result.Code -eq 23 -and $result.Text.Contains('child-fixture-ok')) "Child arguments/environment/exit failed: $($result.Code) $($result.Text)"
    Assert (-not $env:FIXTURE_SETTING -and -not $env:FIXTURE_LITERAL) 'Test process env mutated'
  }
  Check 'file-value-reaches-child-and-failure-does-not-execute' {
    $wrapper = (Join-Path $package 'scripts/invoke-with-requirements.ps1').Replace("'", "''")
    $childPath = Join-Path $project 'file-child.ps1'
    [IO.File]::WriteAllText($childPath, 'if ($env:FIXTURE_SECRET -cne "synthetic-file-secret") { exit 91 }; if ((Get-Location).Path -cne $PSScriptRoot) { exit 92 }; Write-Output "file-child-ok"', $utf8)
    $driverPath = Join-Path $project 'file-driver.ps1'
    $driverBody = @"
& '$wrapper' -ProjectRoot '$($project.Replace("'", "''"))' -Role fixture-role -Skills fixture-skill -ConfigPath project-config.json -Executable pwsh -Arguments @('-NoProfile', '-File', '$($childPath.Replace("'", "''"))')
`$childCode = `$LASTEXITCODE
if (`$env:FIXTURE_SECRET -or `$env:FIXTURE_LITERAL -or `$env:FIXTURE_SETTING) { exit 93 }
exit `$childCode
"@
    [IO.File]::WriteAllText($driverPath, $driverBody, $utf8)
    $success = Run-Script '../../project with spaces/file-driver.ps1' @()
    Assert ($success.Code -eq 0 -and $success.Text.Contains('file-child-ok')) 'File value did not reach the child or changed the parent'
    $original = [IO.File]::ReadAllText($dotenv)
    try {
      [IO.File]::WriteAllText($dotenv, "FIXTURE_SECRET=`nFIXTURE_LITERAL=synthetic-literal`n", $utf8)
      $failure = Run-Script '../../project with spaces/file-driver.ps1' @()
      Assert ($failure.Code -eq 1 -and -not $failure.Text.Contains('file-child-ok')) 'Empty dependency allowed child execution'
    } finally { [IO.File]::WriteAllText($dotenv, $original, $utf8) }
    $unavailable = Run-Script 'invoke-with-requirements.ps1' ($configuredSelection + @('-Executable', 'fixture-missing-executable-649638'))
    Assert ($unavailable.Code -eq 1) 'Missing executable accepted'
  }
  Check 'malformed-dotenv-redacted' {
    $original = [IO.File]::ReadAllText($dotenv)
    try {
      [IO.File]::WriteAllText($dotenv, 'export FIXTURE_SECRET=synthetic-private-value', $utf8)
      $exported = Run-Script 'check-requirements.ps1' $configuredSelection
      Assert ($exported.Code -eq 1 -and -not $exported.Text.Contains('synthetic-private-value')) 'Exported dotenv must fail without raw value'
      [IO.File]::WriteAllText($dotenv, "FIXTURE_SECRET='synthetic-private-value", $utf8)
      $unmatched = Run-Script 'check-requirements.ps1' $configuredSelection
      Assert ($unmatched.Code -eq 1 -and -not $unmatched.Text.Contains('synthetic-private-value')) 'Unmatched quote must fail without raw value'
      [IO.File]::WriteAllText($dotenv, "FIXTURE_SECRET=one`nFIXTURE_SECRET=synthetic-private-value", $utf8)
      $duplicate = Run-Script 'check-requirements.ps1' $configuredSelection
      Assert ($duplicate.Code -eq 1 -and -not $duplicate.Text.Contains('synthetic-private-value')) 'Duplicate dotenv must fail without raw value'
    } finally { [IO.File]::WriteAllText($dotenv, $original, $utf8) }
  }
  Check 'malformed-config-and-secret-rejected' {
    $original = [IO.File]::ReadAllText($config)
    try {
      foreach ($invalid in @('{"env": "synthetic-private-value"}', '{"schemaVersion":1,"env":{"FIXTURE_SECRET":"synthetic-private-value"}}', '{"schemaVersion":1,"env":{"FIXTURE_SETTING":"one","FIXTURE_SETTING":"synthetic-private-value"}}', '{"schemaVersion":1,"env":{"FIXTURE_SETTING":3}}', '{broken synthetic-private-value')) {
        [IO.File]::WriteAllText($config, $invalid, $utf8)
        $result = Run-Script 'check-requirements.ps1' $configuredSelection
        Assert ($result.Code -eq 1 -and -not $result.Text.Contains('synthetic-private-value')) 'Malformed config must fail without raw value'
      }
    } finally { [IO.File]::WriteAllText($config, $original, $utf8) }
  }
  Check 'catalog-invalid-shapes-refs-conflicts-paths' {
    $original = [IO.File]::ReadAllText($skillPath)
    try {
      foreach ($case in [string[]]@('secret', 'name', 'duplicate', 'api', 'hook', 'conflict', 'id', 'path', 'null', 'scalar-cli', 'extra-env-property', 'duplicate-id', 'api-conflict', 'purpose-conflict')) {
        $document = $original | ConvertFrom-Json -NoEnumerate
        $entry = $document.skills[-1]
        if ($case -eq 'secret') { $entry.requires.env[0].secret = 'false' }
        elseif ($case -eq 'name') { $entry.requires.env[0].name = 'invalid-name' }
        elseif ($case -eq 'duplicate') { $entry.requires.env = @($entry.requires.env[0], $entry.requires.env[0]) }
        elseif ($case -eq 'api') { $entry.requires | Add-Member api @([pscustomobject]@{ name = 'unbound-api'; authEnv = 'UNDECLARED'; purpose = 'Test' }) }
        elseif ($case -eq 'hook') { $entry.requires | Add-Member hook 'synthetic-private-value' }
        elseif ($case -eq 'conflict') { $entry.requires.env = @($entry.requires.env) + @([pscustomobject]@{ name = 'FIXTURE_SECRET'; secret = $false; purpose = 'Conflict' }) }
        elseif ($case -eq 'id') { $entry.id = '../fixture-skill' }
        elseif ($case -eq 'path') { $entry.path = '../SKILL.md' }
        elseif ($case -eq 'null') { $entry.requires = $null }
        elseif ($case -eq 'scalar-cli') { $entry.requires | Add-Member cli 'pwsh' }
        elseif ($case -eq 'extra-env-property') { $entry.requires.env[0] | Add-Member value 'synthetic-private-value' }
        elseif ($case -eq 'duplicate-id') { $document.skills += $entry }
        elseif ($case -eq 'api-conflict') { $entry.requires | Add-Member api @([pscustomobject]@{ name = 'fixture-api'; authEnv = 'FIXTURE_LITERAL'; purpose = 'Offline name check' }) }
        elseif ($case -eq 'purpose-conflict') { $entry.requires.env += [pscustomobject]@{ name = 'FIXTURE_SECRET'; secret = $true; purpose = 'Conflicting purpose' } }
        Save-Json $skillPath $document
        $result = Run-Script 'check-requirements.ps1' $configuredSelection
        Assert ($result.Code -eq 1 -and -not $result.Text.Contains('synthetic-private-value')) "Invalid catalog accepted or leaked value: $case"
      }
    } finally { [IO.File]::WriteAllText($skillPath, $original, $utf8) }
  }
  Check 'missing-cli-invalid-selectors-paths' {
    $original = [IO.File]::ReadAllText($rolePath)
    try {
      $document = $original | ConvertFrom-Json -NoEnumerate
      $document.roles[-1].requires.cli = @('fixture-missing-executable-649638')
      Save-Json $rolePath $document
      $missingCommand = Run-Script 'check-requirements.ps1' $configuredSelection
      Assert ($missingCommand.Code -eq 1 -and $missingCommand.Text.Contains('fixture-missing-executable-649638')) 'Missing CLI must fail by name'
    } finally { [IO.File]::WriteAllText($rolePath, $original, $utf8) }
    $invalidRole = Run-Script 'check-requirements.ps1' @('-ProjectRoot', $project, '-Role', '../fixture-role')
    Assert ($invalidRole.Code -eq 1) 'Invalid role must fail'
    $unknownSkill = Run-Script 'check-requirements.ps1' @('-ProjectRoot', $project, '-Role', 'fixture-role', '-Skills', 'unknown-skill')
    Assert ($unknownSkill.Code -eq 1) 'Unknown skill must fail'
    $missingRoot = Run-Script 'check-requirements.ps1' @('-ProjectRoot', (Join-Path $temporary 'missing'), '-Role', 'fixture-role')
    Assert ($missingRoot.Code -eq 1) 'Missing project root must fail'
    $missingConfig = Run-Script 'check-requirements.ps1' @('-ProjectRoot', $project, '-Role', 'fixture-role', '-ConfigPath', 'missing.json')
    Assert ($missingConfig.Code -eq 1) 'Missing config must fail'
  }
  Check 'assembly-both-modes-agents-last-and-no-values' {
    [IO.File]::WriteAllText((Join-Path $project 'AGENTS.md'), "# Fixture rules`nRULES-LAST-SENTINEL`n", $utf8)
    $task = Get-Content (Join-Path $package 'templates/task-definition.json') -Raw | ConvertFrom-Json -AsHashtable
    $task.role = 'fixture-role'; $task.skills.required = @('fixture-skill'); $task.skills.conditional = @(); $task.branch.worktree = $project
    $taskPath = Join-Path $project 'task.json'
    $output = Join-Path $project 'task.md'
    foreach ($mode in @('explicit-path', 'inline-extract')) {
      $task.skillDeliveryMode = $mode
      Save-Json $taskPath $task
      $result = Run-Script 'assemble-task.ps1' @('-ProjectRoot', $project, '-TaskDefinitionPath', $taskPath, '-OutputPath', $output)
      Assert ($result.Code -eq 0) "Assembly failed: $($result.Text)"
      $text = [IO.File]::ReadAllText($output)
      Assert ($text.Contains('FIXTURE_SECRET') -and $text.Contains('FIXTURE_SETTING') -and $text.Contains('invoke-with-requirements.ps1')) 'Requirement names/helper missing'
      Assert (-not $text.Contains('synthetic-file-secret') -and $text.TrimEnd().EndsWith('RULES-LAST-SENTINEL')) 'Assembly leaked values or misplaced AGENTS'
      Assert ($text.IndexOf('### Declared Requirements') -lt $text.IndexOf('## Allowed Scope')) 'Requirements not inside input order'
      if ($mode -eq 'inline-extract') { Assert ($text.Contains('Inspect synthetic data only.')) 'Extension body missing' }
    }
  }
  Check 'extension-metadata-and-manifest-consistency' {
    $result = Run-Script 'verify-package.ps1' @('-PackageRoot', $package, '-MetadataOnly')
    Assert ($result.Code -eq 0) "Extended package metadata failed: $($result.Text)"
    $manifest.deliverables.roles--
    Save-Json $manifestPath $manifest
    $result = Run-Script 'verify-package.ps1' @('-PackageRoot', $package, '-MetadataOnly')
    Assert ($result.Code -ne 0 -and $result.Text.Contains('Manifest roles')) 'Manifest mismatch must still fail'
  }
  Check 'conditional-dependencies-and-invalid-assembly-selectors' {
    $definition = Get-Content (Join-Path $package 'templates/task-definition.json') -Raw | ConvertFrom-Json -AsHashtable
    $definition.role = 'codebase-scout'
    $definition.skills.required = @('codebase-reconnaissance')
    $definition.skills.conditional = @('fixture-skill')
    $definition.branch.worktree = $project
    $definitionPath = Join-Path $project 'conditional.json'
    $outputPath = Join-Path $project 'conditional.md'
    Save-Json $definitionPath $definition
    $assembled = Run-Script 'assemble-task.ps1' @('-ProjectRoot', $project, '-TaskDefinitionPath', $definitionPath, '-OutputPath', $outputPath)
    Assert ($assembled.Code -eq 0 -and [IO.File]::ReadAllText($outputPath).Contains('Conditional (only when activated) env:')) 'Conditional requirements not distinguished'
    $definition.skills.required = @('../fixture-skill')
    Save-Json $definitionPath $definition
    $rejected = Run-Script 'assemble-task.ps1' @('-ProjectRoot', $project, '-TaskDefinitionPath', $definitionPath, '-OutputPath', (Join-Path $project 'invalid.md'))
    Assert ($rejected.Code -eq 1 -and -not (Test-Path (Join-Path $project 'invalid.md'))) 'Invalid assembly selector wrote a brief'
  }
  Check 'offline-unselected-needs-no-config' {
    $result = Run-Script 'check-requirements.ps1' @('-ProjectRoot', $temporary, '-Role', 'codebase-scout')
    Assert ($result.Code -eq 0) 'Existing role must remain offline without keys'
  }
  Write-Host "REQUIREMENTS SUMMARY PASS=$passed FAIL=0"
} catch {
  Write-Host "FAIL requirements: $($_.Exception.Message)"
  exit 1
} finally {
  if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Recurse -Force }
}
