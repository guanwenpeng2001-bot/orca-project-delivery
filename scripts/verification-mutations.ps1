# Source-text mutations run by default, separately from behavior checks.
function Test-EvidenceMutations {
  Invoke-Check 'mutation/superseded' {
    Assert-Condition ($script:mutationFixtures.ContainsKey('superseded')) 'Mutation fixture unavailable: superseded'
    # Re-arm the rework assignment: the behavior suite ended with supersededBy restored
    # but the evidence pointer removed, which is a valid final state that the negative
    # mutation below must not depend on.
    $fixture = $script:mutationFixtures['superseded'].fixture
    $rework = $script:mutationFixtures['superseded'].rework
    $assignmentDirectory = $script:mutationFixtures['superseded'].assignmentDirectory
    $assignmentPath = Join-Path $assignmentDirectory 'rework-round.json'
    $originalAssignment = [IO.File]::ReadAllText($assignmentPath, $utf8)
    $rework.evidence = @{ gitEvidencePath = "runs/$($fixture.RunSlug)/evidence/git/rework-round.json" }
    Write-EvidenceJson $assignmentPath $rework
        $validatorPath = Join-Path $stagedPackage 'scripts/validate-git-evidence.ps1'
        $original = [IO.File]::ReadAllText($validatorPath, $utf8)
        $exemption = "if (`$formal -and `$assignment.status -ceq 'superseded')"
        $pointerCheck = 'Test-SupersededAssignment $assignment $assignments $enteredStatuses $script:Phase'
        Assert-Condition ($original.Contains($exemption) -and $original.Contains($pointerCheck)) 'Superseded mutation targets missing'
        try {
          $rework.supersededBy = 'missing-successor'
          Write-EvidenceJson $assignmentPath $rework
          $result = Invoke-EvidenceValidator @('-Run', $fixture.RunSlug, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)
          Assert-EvidenceStatus $result 'FAIL' 'superseded routing baseline' 'supersededBy'
          [IO.File]::WriteAllText($validatorPath, $original.Replace($exemption, 'if ($false)'), $utf8)
          $result = Invoke-EvidenceValidator @('-Run', $fixture.RunSlug, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)
          Assert-Rejected 'removed superseded exemption' { Assert-EvidenceStatus $result 'FAIL' 'superseded routing assertion' } 'expected status FAIL'
          [IO.File]::WriteAllText($validatorPath, $original.Replace($pointerCheck, ''), $utf8)
          $rework.Remove('supersededBy')
          Write-EvidenceJson (Join-Path $assignmentDirectory 'rework-round.json') $rework
          $result = Invoke-EvidenceValidator @('-Run', $fixture.RunSlug, '-Phase', 'final', '-ProjectRoot', $fixture.ProjectRoot)
          Assert-Rejected 'removed superseded pointer check' { Assert-EvidenceStatus $result 'FAIL' 'superseded negative assertion' } 'expected status FAIL'
        } finally {
          [IO.File]::WriteAllText($validatorPath, $original, $utf8)
          [IO.File]::WriteAllText($assignmentPath, $originalAssignment, $utf8)
        }
  }
  Invoke-Check 'mutation/parent-binding' {
    Assert-Condition ($script:mutationFixtures.ContainsKey('parent-binding')) 'Mutation fixture unavailable: parent-binding'
    $fixture = $script:mutationFixtures['parent-binding'].fixture
    $evidencePath = $script:mutationFixtures['parent-binding'].evidencePath
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
  Invoke-Check 'mutation/scope-parity' {
    Assert-Condition ($script:mutationFixtures.ContainsKey('scope-parity')) 'Mutation fixture unavailable: scope-parity'
    $fixture = $script:mutationFixtures['scope-parity'].fixture
    $evidencePath = $script:mutationFixtures['scope-parity'].evidencePath
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
}
