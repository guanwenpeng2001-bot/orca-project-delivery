#requires -Version 7.0
function Assert-UniqueJsonProperties($Element) {
  if ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($property in $Element.EnumerateObject()) {
      if (-not $names.Add($property.Name)) { throw 'Duplicate JSON property.' }
      Assert-UniqueJsonProperties $property.Value
    }
  } elseif ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
    foreach ($entry in $Element.EnumerateArray()) { Assert-UniqueJsonProperties $entry }
  }
}

function Read-RequirementsJson([string]$Path, [string]$Label) {
  try {
    $text = [IO.File]::ReadAllText($Path)
    $document = [System.Text.Json.JsonDocument]::Parse($text)
    try { Assert-UniqueJsonProperties $document.RootElement } finally { $document.Dispose() }
    return ($text | ConvertFrom-Json -AsHashtable)
  } catch { throw "$Label is unreadable, malformed, or contains duplicate properties." }
}

function Assert-RequirementsSchema($Document, [string]$SchemaName, [string]$Label) {
  $schema = Join-Path (Split-Path -Parent $PSScriptRoot) "schemas/$SchemaName.schema.json"
  $valid = Test-Json -Json ($Document | ConvertTo-Json -Depth 100 -Compress) -SchemaFile $schema -ErrorAction SilentlyContinue
  if (-not $valid) { throw "$Label does not match $SchemaName schema." }
}

function Resolve-CatalogPath([string]$PackageRoot, [string]$Path) {
  $current = Get-Item -LiteralPath $PackageRoot
  foreach ($segment in $Path.Replace('\', '/').Split('/')) {
    $current = Get-Item -LiteralPath (Join-Path $current.FullName $segment) -ErrorAction Stop
    if ($current.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked catalog paths are not supported.' }
  }
  if ($current.PSIsContainer) { throw 'Catalog path must be a file.' }
  return $current.FullName
}

function Get-RequirementsCatalog([string]$PackageRoot) {
  $roles = Read-RequirementsJson (Join-Path $PackageRoot 'roles/catalog.json') 'Role catalog'
  $skills = Read-RequirementsJson (Join-Path $PackageRoot 'routing/skill-catalog.json') 'Skill catalog'
  if ($roles.roles -isnot [array] -or $roles.roles.Count -eq 0 -or $skills.skills -isnot [array] -or $skills.skills.Count -eq 0) { throw 'Catalog entries must be nonempty arrays.' }
  foreach ($group in @(@{ Kind = 'role'; Entries = $roles.roles }, @{ Kind = 'skill'; Entries = $skills.skills })) {
    $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($entry in $group.Entries) {
      if ($entry -isnot [Collections.IDictionary] -or $entry.id -isnot [string] -or $entry.id -cnotmatch '^[a-z0-9][a-z0-9-]*$' -or -not $ids.Add($entry.id)) { throw 'Invalid or duplicate catalog ID.' }
      $expected = if ($group.Kind -eq 'skill') { "skills/$($entry.id)/SKILL.md" } else {
        if ($entry.category -isnot [string] -or $entry.category -cnotmatch '^[a-z0-9][a-z0-9-]*$') { throw 'Invalid role category.' }
        "roles/$($entry.category)/$($entry.id).md"
      }
      if ($entry.path -isnot [string] -or $entry.path.Replace('\', '/') -cne $expected) { throw "Invalid catalog path for $($entry.id)." }
      $null = Resolve-CatalogPath $PackageRoot $expected
      if ($entry.Contains('requires')) {
        Assert-RequirementsSchema $entry.requires 'requirements' "Requirements for $($entry.id)"
        foreach ($kind in @('cli', 'env', 'api')) {
          $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
          foreach ($requirement in @($entry.requires[$kind])) {
            if ($null -eq $requirement) { continue }
            $name = if ($kind -eq 'cli') { $requirement } else { $requirement.name }
            if (-not $names.Add($name)) { throw "Duplicate $kind requirement for $($entry.id)." }
          }
        }
        foreach ($api in @($entry.requires.api)) {
          if ($null -eq $api) { continue }
          if (@($entry.requires.env.name) -cnotcontains $api.authEnv) { throw "API $($api.name) references undeclared env $($api.authEnv)." }
        }
      }
    }
  }
  foreach ($role in $roles.roles) {
    foreach ($field in @('defaultSkills', 'optionalSkills')) {
      if ($role[$field] -isnot [array]) { throw "Role $($role.id) $field must be an array." }
      foreach ($id in $role[$field]) {
        if (@($skills.skills.id) -cnotcontains $id) { throw "Role '$($role.id)' references unknown skill '$id'." }
      }
    }
  }
  return @{ Roles = $roles.roles; Skills = $skills.skills }
}

function Get-SelectedRequirements($Catalog, [string]$RoleId, [string[]]$SkillIds) {
  $entries = @()
  $role = $null
  if ($RoleId) {
    $role = $Catalog.Roles | Where-Object { $_.id -ceq $RoleId }
    if (-not $role) { throw 'Unknown role selector.' }
    $entries += $role
  }
  $selectedSkills = @()
  foreach ($id in @($SkillIds | Select-Object -Unique)) {
    $skill = $Catalog.Skills | Where-Object { $_.id -ceq $id }
    if (-not $skill) { throw 'Unknown skill selector.' }
    $selectedSkills += $skill
  }
  $entries += $selectedSkills
  $commands = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $variables = @{}
  $apis = @{}
  foreach ($entry in $entries) {
    if (-not $entry.Contains('requires')) { continue }
    foreach ($command in @($entry.requires.cli)) { if ($null -ne $command) { [void]$commands.Add($command) } }
    foreach ($variable in @($entry.requires.env)) {
      if ($null -eq $variable) { continue }
      if ($variables.ContainsKey($variable.name)) {
        $previous = $variables[$variable.name]
        if ($previous.secret -ne $variable.secret -or $previous.purpose -cne $variable.purpose) { throw "Conflicting metadata for env $($variable.name)." }
      } else { $variables[$variable.name] = $variable }
    }
    foreach ($api in @($entry.requires.api)) {
      if ($null -eq $api) { continue }
      if ($apis.ContainsKey($api.name)) {
        $previous = $apis[$api.name]
        if ($previous.authEnv -cne $api.authEnv -or $previous.purpose -cne $api.purpose) { throw "Conflicting metadata for API $($api.name)." }
      } else { $apis[$api.name] = $api }
    }
  }
  return @{ Role = $role; Skills = $selectedSkills; Commands = @($commands | Sort-Object); Variables = $variables; Apis = @($apis.Values | Sort-Object name) }
}

function Read-LiteralDotEnv([string]$Path) {
  $values = @{}
  if (-not (Test-Path -LiteralPath $Path)) { return $values }
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'Dotenv path must be a file.' }
  try { $lines = [IO.File]::ReadAllLines($Path) } catch { throw 'Cannot read dotenv file.' }
  for ($index = 0; $index -lt $lines.Count; $index++) {
    $line = $lines[$index]
    if ($line -match '^[ \t]*($|#)') { continue }
    if ($line -cnotmatch '^([A-Z][A-Z0-9_]*)=(.*)$') { throw "Invalid dotenv declaration at line $($index + 1)." }
    $name = $Matches[1]
    $value = $Matches[2]
    if ($values.ContainsKey($name)) { throw "Duplicate dotenv name $name at line $($index + 1)." }
    if ($value.StartsWith("'") -or $value.StartsWith('"')) {
      $quote = $value.Substring(0, 1)
      if ($value.Length -lt 2 -or -not $value.EndsWith($quote)) { throw "Unmatched dotenv quote for $name at line $($index + 1)." }
      $value = $value.Substring(1, $value.Length - 2)
      if ($value.Contains($quote)) { throw "Invalid dotenv quote for $name at line $($index + 1)." }
    }
    if ($value.Contains([char]0)) { throw "Invalid dotenv value for $name at line $($index + 1)." }
    $values[$name] = $value
  }
  return $values
}

function Read-ProjectConfig([string]$ProjectRoot, [string]$ConfigPath, $Catalog) {
  if (-not $ConfigPath) { return @{} }
  $path = if ([IO.Path]::IsPathRooted($ConfigPath)) { [IO.Path]::GetFullPath($ConfigPath) } else { [IO.Path]::GetFullPath((Join-Path $ProjectRoot $ConfigPath)) }
  $prefix = $ProjectRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
  if (-not $path.StartsWith($prefix, $comparison)) { throw 'Config path must be inside the explicit project root.' }
  $relative = [IO.Path]::GetRelativePath($ProjectRoot, $path)
  $null = Resolve-CatalogPath $ProjectRoot $relative
  $config = Read-RequirementsJson $path 'Project config'
  Assert-RequirementsSchema $config 'project-config' 'Project config'
  foreach ($name in $config.env.Keys) {
    $declarations = @(@($Catalog.Roles) + @($Catalog.Skills) | ForEach-Object { $_.requires.env } | Where-Object { $_.name -ceq $name })
    if ($declarations.Count -eq 0 -or @($declarations | Where-Object secret).Count -gt 0) { throw "Project config name $name must be declared non-secret." }
  }
  return $config.env
}

function Resolve-RequirementAvailability {
  param([string]$ProjectRoot, [string]$RoleId, [string[]]$SkillIds, [string]$ConfigPath, [System.Collections.IDictionary]$ProcessEnvironment = [Environment]::GetEnvironmentVariables())
  if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) { throw 'ProjectRoot must be an existing directory.' }
  $root = (Resolve-Path -LiteralPath $ProjectRoot).Path
  $catalog = Get-RequirementsCatalog (Split-Path -Parent $PSScriptRoot)
  $selected = Get-SelectedRequirements $catalog $RoleId $SkillIds
  $dotenv = if ($selected.Variables.Count) { Read-LiteralDotEnv (Join-Path $root '.env') } else { @{} }
  $config = Read-ProjectConfig $root $ConfigPath $catalog
  $checks = [Collections.Generic.List[object]]::new()
  $missing = [Collections.Generic.List[string]]::new()
  foreach ($command in $selected.Commands) {
    $available = [bool](Get-Command -Name $command -CommandType Application -ErrorAction SilentlyContinue)
    $checks.Add(@{ kind = 'cli'; name = $command; availableInProcess = $available; availableForChild = $available; source = $(if ($available) { 'process-command' } else { 'absent' }) })
    if (-not $available) { $missing.Add("cli:$command") }
  }
  foreach ($name in @($selected.Variables.Keys | Sort-Object)) {
    $variable = $selected.Variables[$name]
    $inProcess = $ProcessEnvironment.Contains($name) -and -not [string]::IsNullOrEmpty($ProcessEnvironment[$name])
    $inFile = $dotenv.ContainsKey($name) -and -not [string]::IsNullOrEmpty($dotenv[$name])
    $inConfig = $config.Contains($name) -and -not [string]::IsNullOrEmpty($config[$name])
    $source = if ($ProcessEnvironment.Contains($name)) { 'process-env' } elseif ($dotenv.ContainsKey($name)) { 'project-env-file' } elseif ($config.Contains($name)) { 'project-config' } else { 'absent' }
    $available = switch ($source) { 'process-env' { $inProcess }; 'project-env-file' { $inFile }; 'project-config' { $inConfig }; default { $false } }
    $checks.Add(@{ kind = 'env'; name = $name; secret = $variable.secret; purpose = $variable.purpose; configured = ($inFile -or $inConfig); availableInProcess = $inProcess; availableForChild = $available; source = $source })
    if (-not $available) { $missing.Add("env:$name") }
  }
  foreach ($api in $selected.Apis) {
    $auth = $checks | Where-Object { $_.kind -eq 'env' -and $_.name -ceq $api.authEnv }
    $checks.Add(@{ kind = 'api'; name = $api.name; authEnv = $api.authEnv; purpose = $api.purpose; configured = $auth.configured; availableInProcess = $auth.availableInProcess; availableForChild = $auth.availableForChild; source = $auth.source; networkVerified = $false })
    if (-not $auth.availableForChild) { $missing.Add("api:$($api.name)") }
  }
  return @{ Selected = $selected; Checks = $checks.ToArray(); Missing = $missing.ToArray(); DotEnv = $dotenv; Config = $config; ProcessEnvironment = $ProcessEnvironment }
}

function Get-ChildRequirementEnvironment($Resolution) {
  $comparer = if ($IsWindows) { [StringComparer]::OrdinalIgnoreCase } else { [StringComparer]::Ordinal }
  $environment = [Collections.Generic.Dictionary[string, string]]::new($comparer)
  foreach ($name in $Resolution.ProcessEnvironment.Keys) { $environment[[string]$name] = [string]$Resolution.ProcessEnvironment[$name] }
  foreach ($name in $Resolution.Selected.Variables.Keys) {
    if ($environment.ContainsKey($name)) { continue }
    if ($Resolution.DotEnv.ContainsKey($name)) { $environment[$name] = $Resolution.DotEnv[$name] }
    elseif ($Resolution.Config.Contains($name)) { $environment[$name] = $Resolution.Config[$name] }
  }
  return $environment
}
