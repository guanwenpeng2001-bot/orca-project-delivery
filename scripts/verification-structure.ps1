# The sole vocabulary declaration is exempt from scanning, by its AST extent only.
$forbiddenAgentIds = @(
  'claude-agent-teams', 'codebuddy', 'openclaude', 'codex', 'autohand', 'opencode',
  'opencode2', 'mimo-code', 'pi', 'omp', 'qoder', 'gemini', 'antigravity', 'aider',
  'goose', 'amp', 'kilo', 'kiro', 'crush', 'aug', 'cline', 'codebuff', 'freebuff',
  'command-code', 'continue', 'cursor', 'droid', 'kimi', 'mistral-vibe', 'qwen-code',
  'rovo', 'hermes', 'openclaw', 'copilot', 'grok', 'devin', 'ante', 'trae', 'muse',
  'zcode', 'prime-agent', 'dsh'
)

function Assert-ModelRouting($Routing, $Catalog) {
  $ids = @($Catalog.roles.id)
  Assert-Condition ($ids.Count -gt 0 -and @($ids | Select-Object -Unique).Count -eq $ids.Count) 'routing: expected nonempty unique catalog roles'
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
    if ($Source -ceq 'scripts/verification-structure.ps1') {
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
      $databaseTerm = $Extension -eq '.md' -and $match.Value -ceq ('cur' + 'sor') -and
        ($match.Index -eq 0 -or $segment[$match.Index - 1] -notin @('`', '"', "'")) -and
        ($segment.Substring(0, $match.Index) -cmatch '(database|SQL) $' -or $segment.Substring($match.Index) -cmatch ('^cur' + 'sor pagination\b'))
      Assert-Condition ($ordinaryProse -or $databaseTerm) "agent reference: $Source contains $($match.Value)"
    }
  }
}

function Test-PackageStructure {
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
  $script:resolvedSkills = [Collections.Generic.List[object]]::new()
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
  Invoke-Check 'metadata/bundled-skill-integrity' {
    $readmePath = Join-Path $root 'skills/README.md'
    Assert-Condition (Test-Path -LiteralPath $readmePath -PathType Leaf) 'skills/README.md missing'
    $readme = [IO.File]::ReadAllText($readmePath, $utf8)
    $rows = [regex]::Matches($readme, '\|\s*`([^`]+)`\s*\|\s*([A-F0-9]{64})\s*\|')
    $expectedRows = @('LICENSE') + @((Read-PackageJson 'routing/skill-catalog.json').skills | ForEach-Object { "$($_.id)/SKILL.md" })
    $actualRows = @($rows | ForEach-Object { $_.Groups[1].Value })
    Assert-Condition ($actualRows.Count -eq $expectedRows.Count -and -not (Compare-Object ($actualRows | Sort-Object -Unique) ($expectedRows | Sort-Object) -CaseSensitive)) 'SHA256 table must cover exactly the catalog Skills and LICENSE'
    foreach ($match in $rows) {
      $relative = $match.Groups[1].Value
      $expectedHash = $match.Groups[2].Value
      $filePath = Join-Path $root (Join-Path 'skills' ($relative.Replace('/', '\')))
      Assert-Condition (Test-Path -LiteralPath $filePath -PathType Leaf) "Bundled file missing for integrity check: $relative"
      $actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash
      Assert-Condition ($actualHash -ceq $expectedHash) "Hash mismatch for $relative"
    }
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
    Assert-ClaudeText ('A database cur' + 'sor reads rows; use cur' + 'sor pagination for API results.') '.md' 'fixture'
    Assert-Rejected 'quoted-database-term' { Assert-ClaudeText ('Use `cur' + 'sor` as worker agent.') '.md' 'fixture' } 'agent reference:'
    Assert-Rejected 'capitalized-agent' { Assert-ClaudeText ('Use Cur' + 'sor as worker agent.') '.md' 'fixture' } 'agent reference:'
    $nonClaudeRouting = Read-PackageJson 'routing/model-routing.json'
    $nonClaudeRouting.agent = 'cur' + 'sor'
    Assert-Rejected 'non-claude-routing' { Assert-ModelRouting $nonClaudeRouting (Read-PackageJson 'roles/catalog.json') } 'agent must be claude'
    Assert-Rejected 'vocabulary-name-does-not-exempt-other-files' { Assert-ClaudeText ('$forbiddenAgentIds = @("' + $forbiddenAgentIds[0] + '")') '.ps1' 'fixture' } 'agent reference:'
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
