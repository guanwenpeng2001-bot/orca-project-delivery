#requires -Version 7.0
<##
Offline package acceptance. Requires PowerShell 7, Git and the professional
Skills bundled under skills/ in this package. The package under
test is read-only; all runtime fixtures and copies use temporary directories.
##>
[CmdletBinding()]
param([string]$PackageRoot = (Split-Path -Parent $PSScriptRoot), [switch]$MetadataOnly, [string]$DocumentPython = '', [switch]$SkipMutationTests, [ValidateRange(1, 86400)][int]$SuiteTimeoutSeconds = 600, [string[]]$Suites = @())

# Unicode code points include whitespace. Hard limit 22000; warning at 19800 (90%).
# Keep the shipped entry under the warning threshold; raise both constants together if it ever must grow.
$entryCharacterLimit = 22000
$entryCharacterWarning = 19800
$warnings = [Collections.Generic.List[string]]::new()
$ErrorActionPreference = 'Stop'
$passed = 0
$failed = 0
$temporaryRoot = $null
$utf8 = [Text.UTF8Encoding]::new($false, $true)

$mutationFixtures = @{}
foreach ($helper in @('common', 'structure', 'runtime', 'lifecycle', 'evidence-fixtures', 'evidence', 'mutations')) {
  . (Join-Path $PSScriptRoot "verification-$helper.ps1")
}

try {
  $suiteSelection = Resolve-SuiteSelection -Requested $Suites -MetadataOnly:$MetadataOnly -SkipMutationTests:$SkipMutationTests
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
  $runningSuites = @($suiteSelection.Running)
  $selectionRequiresStaging = @($runningSuites | Where-Object { $_ -ne 'package structure' }).Count -gt 0
  if ($suiteSelection.Explicit) {
    Write-Host "SUITES requested: $($suiteSelection.Requested -join ', ')"
    Write-Host "SUITES running: $($runningSuites -join ', ')"
  }
  Invoke-Suite 'package structure' { Test-PackageStructure }
  if (-not $MetadataOnly -and $selectionRequiresStaging) {
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
        $bundledInCopy = Join-Path $stagedPackage "skills/$($skill.Id)/SKILL.md"
        Assert-Condition (Test-Path -LiteralPath $bundledInCopy -PathType Leaf) "Staged package missing bundled skill: $($skill.Id)"
      }
      Assert-Condition ($resolvedSkills.Count -eq @((Read-PackageJson 'routing/skill-catalog.json').skills).Count) 'Cannot stage every declared skill'
    }
    Assert-Condition (Test-Path -LiteralPath (Join-Path $stagedPackage 'scripts/verify-package.ps1')) 'Staged package unavailable'
  }
  if (-not $MetadataOnly -and ($runningSuites -ccontains 'package runtime')) {
    Invoke-Suite 'package runtime' { Test-PackageRuntime }
  }
  if (-not $MetadataOnly -and ($runningSuites -ccontains 'package contracts')) {
    Invoke-Suite 'package contracts' { Test-PackageContracts }
  }
  if (-not $MetadataOnly -and ($runningSuites -ccontains 'project lifecycle')) {
    Invoke-Suite 'project lifecycle' { Test-ProjectLifecycle }
  }
  if (-not $MetadataOnly -and ($runningSuites -ccontains 'git evidence')) {
    Invoke-Suite 'git evidence' { Test-GitEvidence }
  }
  if (-not $MetadataOnly -and $SkipMutationTests) {
    Write-Host 'SKIP evidence source mutations: -SkipMutationTests was explicitly requested'
  } elseif (-not $MetadataOnly -and ($runningSuites -ccontains 'evidence source mutations')) {
    Invoke-Suite 'evidence source mutations' { Test-EvidenceMutations }
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
  if (-not $MetadataOnly -and $null -ne $resolvedSkills) {
    $siblings = @($resolvedSkills | Where-Object Origin -eq 'package-bundled').Count
    $declaredCount = try { @((Read-PackageJson 'routing/skill-catalog.json').skills).Count } catch { '?' }
    Write-Host "skills: $($resolvedSkills.Count)/$declaredCount resolved ($siblings package-bundled)"
  }
  [ordered]@{ ok = ($failed -eq 0); passed = $passed; failed = $failed; warnings = @($warnings.ToArray()) } | ConvertTo-Json -Compress
  $summaryPrefix = if ($MetadataOnly) { 'METADATA SUMMARY' } else { 'SUMMARY' }
  Write-Host "$summaryPrefix PASS=$passed FAIL=$failed"
}
if ($failed -gt 0) { exit 1 }
exit 0
