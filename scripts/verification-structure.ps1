function Assert-RoleSelection($Selection, $Catalog) {
  Assert-Condition ($Selection.deliverableRoutes -is [Collections.IDictionary] -and $Selection.deliverableRoutes.Count -gt 0) 'selection: empty or invalid routes'
  foreach ($deliverable in $Selection.deliverableRoutes.Keys) {
    Assert-Condition (@($Catalog.roles.id) -ccontains $Selection.deliverableRoutes[$deliverable]) "selection: $deliverable selects unknown role"
  }
}

function Assert-DesignTriggers($Document, $Selection) {
  Assert-Condition (($Document.schemaVersion -is [int] -or $Document.schemaVersion -is [long]) -and $Document.schemaVersion -eq 1) 'design triggers: schemaVersion must be 1'
  Assert-Condition ($Document.triggers -is [array] -and $Document.triggers.Count -gt 0) 'design triggers: triggers must be a nonempty array'
  foreach ($trigger in $Document.triggers) {
    Assert-Condition ($trigger.id -is [string] -and -not [string]::IsNullOrWhiteSpace($trigger.id)) 'design triggers: id must be a nonempty string'
    foreach ($field in @('when', 'instantiates')) {
      Assert-Condition ($trigger[$field] -is [array] -and $trigger[$field].Count -gt 0) "design triggers: $($trigger.id) $field must be a nonempty array"
      foreach ($value in $trigger[$field]) {
        Assert-Condition ($value -is [string] -and -not [string]::IsNullOrWhiteSpace($value)) "design triggers: $($trigger.id) $field must contain nonempty strings"
      }
    }
    foreach ($deliverable in $trigger.instantiates) {
      Assert-Condition (@($Selection.deliverableRoutes.Keys) -ccontains $deliverable) "design triggers: $($trigger.id) instantiates unknown deliverable $deliverable"
    }
  }
}

function Test-PackageStructure {
  # Presence is a fixed package contract; discovery below also covers added scripts.
  $requiredScripts = @(
    'assemble-task.ps1', 'bootstrap-project.ps1', 'create-run.ps1', 'dispatch-task.ps1',
    'reconcile-state.ps1', 'release-coordinator.ps1',
    'verify-package.ps1',
    'requirements-lib.ps1', 'check-requirements.ps1', 'invoke-with-requirements.ps1',
    'verify-requirements.ps1', 'project-common.ps1', 'verification-common.ps1',
    'verification-structure.ps1', 'verification-runtime.ps1', 'verification-lifecycle.ps1'
  )
  Invoke-Check 'package/required-scripts' {
    foreach ($name in $requiredScripts) {
      $path = Join-Path $root "scripts/$name"
      Assert-Condition (Test-Path -LiteralPath $path -PathType Leaf) "Missing required script: $path"
    }
  }
  $scripts = @(Get-ChildItem -LiteralPath (Join-Path $root 'scripts') -Filter '*.ps1' -File | Sort-Object Name)
  foreach ($scriptFile in $scripts) {
    $name = $scriptFile.Name
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
  Invoke-Check 'routing/role-selection-valid' {
    Assert-RoleSelection (Read-PackageJson 'routing/role-selection.json') (Read-PackageJson 'roles/catalog.json')
  }
  Invoke-Check 'routing/workflow-paths' {
    $selection = Read-PackageJson 'routing/workflow-selection.json'
    $names = @($selection.default)
    foreach ($rule in $selection.rules) {
      Assert-Condition ($rule -is [Collections.IDictionary] -and $rule.Contains('workflow')) 'workflow: rule missing name'
      $names += $rule.workflow
    }
    foreach ($name in $names) {
      Assert-Condition ($name -is [string] -and $name -cmatch '^[a-z0-9][a-z0-9-]*$') 'workflow: invalid name'
      Assert-Condition (Test-Path -LiteralPath (Join-Path $root "workflows/$name.md") -PathType Leaf) "workflow: missing definition $name"
    }
  }
  Invoke-Check 'routing/design-triggers-valid' {
    Assert-DesignTriggers (Read-PackageJson 'routing/design-triggers.json') (Read-PackageJson 'routing/role-selection.json')
  }
  Invoke-Check 'package/no-mirror-tables' {
    Assert-AbsentPaths $root @('agents', 'adapters', 'agents/role-compatibility.json', 'routing/agent-selection.json')
  }
  Invoke-Check 'metadata/entry-character-budget' {
    $entry = [IO.File]::ReadAllText((Join-Path $root 'SKILL.md'), $utf8)
    $characterCount = 0
    foreach ($rune in $entry.EnumerateRunes()) { $characterCount++ }
    Write-Host "ENTRY SKILL.md: $characterCount Unicode characters including whitespace"
    Assert-Condition ($characterCount -le $entryCharacterLimit) "SKILL.md has $characterCount Unicode characters including whitespace; limit is $entryCharacterLimit"
    if ($characterCount -ge $entryCharacterWarning) {
      $warning = "SKILL.md has $characterCount Unicode characters including whitespace; warning threshold is $entryCharacterWarning, limit is $entryCharacterLimit"
      $warnings.Add($warning)
      Write-Host "WARNING: $warning"
    }
  }
  Invoke-Check 'metadata/entry-outline' {
    $entryPath = Join-Path $root 'SKILL.md'
    $lines = [IO.File]::ReadAllLines($entryPath, $utf8)
    Assert-Condition ($lines.Count -le 250) "Entry has $($lines.Count) lines; limit is 250"
    $expected = @('Purpose', 'Coordinator-only guard', 'System boundaries', 'Required invariants', 'Bootstrap', 'Workflow selection', 'Dynamic reconnaissance', 'Role and Skill routing', 'Agent execution', 'Skill delivery', 'Task and branch creation', 'Worker input order', 'Execution loop', 'Review and integration', 'Recovery and handoff', 'Completion', 'Do not do')
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
  $script:resolvedSkills = [Collections.Generic.List[object]]::new()
  Invoke-Check 'metadata/skills-readme' {
    Assert-Condition (Test-Path -LiteralPath (Join-Path $root 'skills/README.md') -PathType Leaf) 'Missing skills/README.md: per-Skill provenance and license record'
  }
  Invoke-Check 'metadata/review-report-no-hash-binding' {
    $template = [IO.File]::ReadAllText((Join-Path $root 'templates/review-report.md'))
    Assert-Condition ($template -notmatch 'commitSha|Commit Binding|"dirty"') 'review-report template must not reintroduce hash-binding bookkeeping'
  }
  Invoke-Check 'metadata/skill-paths' {
    $missing = [Collections.Generic.List[string]]::new()
    foreach ($skill in (Read-PackageJson 'routing/skill-catalog.json').skills) {
      Assert-Condition ($skill.id -match '^[a-z0-9][a-z0-9-]*$') "Invalid skill ID: $($skill.id)"
      $expected = "skills/$($skill.id)/SKILL.md"
      Assert-Condition ($skill.path.Replace('\', '/') -ceq $expected) "Unexpected catalog path for $($skill.id): $($skill.path)"
      $bundled = [IO.Path]::GetFullPath((Join-Path $root $expected))
      try { $resolved = Resolve-SkillFile $bundled }
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
    Assert-Condition (-not $manifest.deliverables.Contains('orcaAgents') -and -not $manifest.Contains('inPlaceFixes')) 'Obsolete manifest fields remain'
    foreach ($key in $counts.Keys) {
      Assert-Condition ($manifest.deliverables.Contains($key) -and $manifest.deliverables[$key] -eq $counts[$key]) "Manifest $key declared $($manifest.deliverables[$key]), actual $($counts[$key])"
      Write-Host "COUNT $key=$($counts[$key])"
    }
  }
  Invoke-Check 'metadata/catalog-requirements' {
    . (Join-Path $root 'scripts/requirements-lib.ps1')
    $null = Get-RequirementsCatalog $root
    Assert-RequirementsSchema (Read-PackageJson 'templates/project-config.example.json') 'project-config' 'Config template'
    foreach ($example in @('.env.example', 'templates/project.env.example')) {
      foreach ($line in [IO.File]::ReadAllLines((Join-Path $root $example))) {
        Assert-Condition ($line -match '^\s*(#.*)?$' -or $line -cmatch '^[A-Z][A-Z0-9_]*=$') 'Env examples must contain names with empty values only'
      }
    }
  }
}

function Test-PackageContracts {
  Invoke-Check 'regression/role-and-design-selection' {
    $catalog = Read-PackageJson 'roles/catalog.json'
    $selection = Read-PackageJson 'routing/role-selection.json'
    Assert-RoleSelection $selection $catalog
    $selection.deliverableRoutes['unknown-deliverable'] = 'unknown-role'
    Assert-Rejected 'unknown-deliverable-role' { Assert-RoleSelection $selection $catalog } 'selection:'
    $designMutations = [ordered]@{
      'unknown-design-deliverable' = @{ mutate = { param($document) $document.triggers[0].instantiates = @('unknown-design-deliverable') }; diagnostic = 'design triggers: system-boundary-or-cross-module instantiates unknown deliverable unknown-design-deliverable' }
      'missing-design-triggers' = @{ mutate = { param($document) $document.Remove('triggers') }; diagnostic = 'design triggers: triggers must be a nonempty array' }
    }
    $selection = Read-PackageJson 'routing/role-selection.json'
    foreach ($case in $designMutations.Keys) {
      $document = Read-PackageJson 'routing/design-triggers.json'
      $null = & $designMutations[$case].mutate $document
      Assert-Rejected $case { Assert-DesignTriggers $document $selection } $designMutations[$case].diagnostic
    }
  }
  Invoke-Check 'regression/bundled-skill-resolution' {
    $bundled = Join-Path $stagedPackage 'skills/code-review/SKILL.md'
    Assert-Condition ((Resolve-SkillFile $bundled).Origin -eq 'package-bundled') 'Bundled resolution failed'
    $missingPath = Join-Path $temporaryRoot 'missing-bundled-skill.md'
    Assert-Rejected 'missing-bundled-skill' { Resolve-SkillFile $missingPath } 'skill file missing:'
    $dirPath = Join-Path $temporaryRoot 'skill-path-directory'
    [void][IO.Directory]::CreateDirectory($dirPath)
    Assert-Rejected 'skill-path-is-directory' { Resolve-SkillFile $dirPath } 'skill file missing:'
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
}
