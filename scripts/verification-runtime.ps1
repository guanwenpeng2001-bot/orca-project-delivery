function Test-PackageRuntime {
  Invoke-Check 'runtime/capability-behavior' {
    $node = (Get-Command node -CommandType Application | Select-Object -First 1).Source
    $testFiles = @(Get-ChildItem -LiteralPath (Join-Path $stagedPackage 'tests') -Filter '*.test.mjs' -File | Sort-Object Name | ForEach-Object FullName)
    $exampleFiles = @(Get-ChildItem -LiteralPath (Join-Path $stagedPackage 'skills') -Recurse -Filter '*.test.mjs' -File | Sort-Object FullName | ForEach-Object FullName)
    $testFiles += $exampleFiles
    Assert-Condition ($testFiles.Count -gt 0) 'No Node test suites were discovered'
    $result = Invoke-Child $node (@('--test') + $testFiles) -TimeoutSeconds $SuiteTimeoutSeconds
    Assert-Condition ($result.ExitCode -eq 0) "Capability behavior tests failed: $($result.Stdout) $($result.Stderr)"
  }
  Invoke-Check 'runtime/capability-config-injection' {
    $result = Invoke-Child -TimeoutSeconds $SuiteTimeoutSeconds $pwsh @('-NoProfile', '-NonInteractive', '-File', (Join-Path $stagedPackage 'tests/capability-config.test.ps1'))
    Assert-Condition ($result.ExitCode -eq 0) "Capability config test failed: $($result.Stdout) $($result.Stderr)"
  }
  if ($DocumentPython) {
    Invoke-Check 'runtime/document-generation-readback' {
      foreach ($requiredSuite in @('document-production.test.py', 'document-depth-office.test.py')) {
        Assert-Condition (Test-Path -LiteralPath (Join-Path $stagedPackage "tests/$requiredSuite") -PathType Leaf) "Missing required document suite: $requiredSuite"
      }
      $pythonFiles = @(Get-ChildItem -LiteralPath (Join-Path $stagedPackage 'tests') -Filter '*.test.py' -File | Sort-Object Name | ForEach-Object FullName)
      foreach ($pythonFile in $pythonFiles) {
        $result = Invoke-Child -TimeoutSeconds $SuiteTimeoutSeconds $DocumentPython @('-I', $pythonFile)
        Assert-Condition ($result.ExitCode -eq 0) "Document generation tests failed for $(Split-Path -Leaf $pythonFile): $($result.Stdout) $($result.Stderr)"
      }
    }
  } else { Write-Host 'SKIP document generation: pass -DocumentPython with the installed document dependencies' }
  Invoke-Check 'runtime/requirements-extension-fixtures' {
    $result = Invoke-Child -TimeoutSeconds $SuiteTimeoutSeconds $pwsh @('-NoProfile', '-NonInteractive', '-File', (Join-Path $stagedPackage 'scripts/verify-requirements.ps1'), '-PackageRoot', $stagedPackage)
    Assert-Condition ($result.ExitCode -eq 0 -and $result.Stdout.Contains('REQUIREMENTS SUMMARY')) 'Requirements regressions failed'
  }
}
