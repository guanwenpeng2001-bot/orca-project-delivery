[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = (Get-Location).Path,

  [Parameter(Mandatory = $false)]
  [switch]$IncludeTemplates,

  [Parameter(Mandatory = $false)]
  [switch]$SkipPackageChecks
)

$ErrorActionPreference = "Stop"

# --- host environment guard -------------------------------------------------
# Some hosts inject GIT_CONFIG_COUNT together with GIT_CONFIG_KEY_n pairs, then strip child
# variables whose names contain KEY/TOKEN/SECRET. The orphaned count makes every git call fail
# with: fatal: missing config key GIT_CONFIG_KEY_0. Drop the orphan so git still works.
if ($env:GIT_CONFIG_COUNT -and -not $env:GIT_CONFIG_KEY_0) {
  Remove-Item Env:GIT_CONFIG_COUNT -ErrorAction SilentlyContinue
}

function Invoke-Git {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )
  $output = & git -C $Root @Arguments 2>&1
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    throw ("git {0} failed (exit {1}) in {2}: {3}" -f ($Arguments -join " "), $exitCode, $Root, (($output | Out-String).Trim()))
  }
  return $output
}
# ---------------------------------------------------------------------------

# $errors is an ArrayList, not @(): it is threaded into the validator functions, which take a
# [System.Collections.ArrayList]. Binding an Object[] to that parameter copies it, so every
# problem the validators found in a copy used to be dropped before it reached the report.
# ArrayList is kept all the way through (+= would silently convert it back to Object[]).
$errors = [System.Collections.ArrayList]::new()
$warnings = @()
$checks = [ordered]@{}

function Read-JsonSafe {
  param([string]$Path)
  try { return (Get-Content $Path -Raw | ConvertFrom-Json) } catch { return $null }
}

# Per-invocation schema cache. This is a one-shot CLI and the package schemas are
# read-only deliverables, so re-reading the same schema for every document is
# wasted work. Only a successful, usable parse is cached: a missing or invalid
# schema keeps taking the uncached Read-JsonSafe path, so every document still
# reports its own error, in the same order and count, exactly as before. The
# cache lives in this process only (no persistence, no cross-process sharing) and
# holds at most the seven package schemas.
$script:schemaCache = @{}
function Get-CachedSchema {
  param([string]$SchemaPath)
  if ($script:schemaCache.Contains($SchemaPath)) { return $script:schemaCache[$SchemaPath] }
  $schema = Read-JsonSafe $SchemaPath
  if ($null -ne $schema) { $script:schemaCache[$SchemaPath] = $schema }
  return $schema
}

# Dependency-free, recursive validator for the schema keywords this package uses:
# type (a name or an array of names, including "null"), required, properties, items, enum,
# const, minLength, uniqueItems, additionalProperties. It descends through properties and
# items, reports every problem it finds, and names the JSON path of the offending value.
#
# ConvertFrom-Json type notes:
#  - objects arrive as PSCustomObject, arrays as Object[], JSON null as $null;
#  - an ISO-8601 string is materialised as [datetime]/[datetimeoffset]; JSON has no such
#    type, so those still count as strings (for `type`: a value that is really absent is
#    caught by `required`, which tests property presence, not value);
#  - an empty JSON array can collapse to $null on the pipeline ($null is what an empty
#    array looks like once it has been through one). To stay consistent, $null therefore
#    also satisfies `type: "array"` and is walked as an array of zero items.
function Get-JsonTypeName {
  param([object]$Value)
  if ($null -eq $Value) { return "null" }
  if ($Value -is [bool]) { return "boolean" }
  if ($Value -is [string]) { return "string" }
  if ($Value -is [datetime] -or $Value -is [datetimeoffset] -or $Value -is [guid] -or $Value -is [timespan]) { return "string" }
  if ($Value -is [int] -or $Value -is [long]) { return "integer" }
  if ($Value -is [double] -or $Value -is [single] -or $Value -is [decimal]) { return "number" }
  if ($Value -is [System.Array]) { return "array" }
  if ($Value -is [System.Management.Automation.PSCustomObject] -or $Value -is [System.Collections.IDictionary]) { return "object" }
  return "unknown"
}

function Test-JsonTypeMatch {
  param([object]$Value, [string]$ExpectedType)
  $actual = Get-JsonTypeName $Value
  if ($ExpectedType -eq $actual) { return $true }
  # JSON has no integer/double spelling once converted: either satisfies the other.
  if ($ExpectedType -eq "integer" -and $actual -eq "number") { return ([double]$Value -eq [math]::Truncate([double]$Value)) }
  if ($ExpectedType -eq "number" -and $actual -eq "integer") { return $true }
  # A collapsed empty array, see the notes above.
  if ($ExpectedType -eq "array" -and $actual -eq "null") { return $true }
  return $false
}

# Type-aware scalar comparison: 1 does not equal "1", "a" does not equal "A".
function Test-JsonScalarEqual {
  param([object]$Left, [object]$Right)
  if ($null -eq $Left -or $null -eq $Right) { return ($null -eq $Left -and $null -eq $Right) }
  $leftType = Get-JsonTypeName $Left
  $rightType = Get-JsonTypeName $Right
  if ($leftType -eq "integer" -or $leftType -eq "number") {
    if ($rightType -ne "integer" -and $rightType -ne "number") { return $false }
    return ([double]$Left -eq [double]$Right)
  }
  if ($leftType -ne $rightType) { return $false }
  if ($leftType -eq "string") { return ($Left.ToString() -ceq $Right.ToString()) }
  return ($Left -eq $Right)
}

function Get-JsonValueToken {
  param([object]$Value)
  # Type tag plus compact JSON: stable for equal values, distinct across types.
  return ((Get-JsonTypeName $Value) + ":" + ($Value | ConvertTo-Json -Depth 20 -Compress))
}

function Join-JsonPath {
  param([string]$ParentPath, [string]$Name)
  if ($ParentPath) { return "$ParentPath.$Name" }
  return $Name
}

function Test-SchemaNode {
  param(
    [object]$Value,
    [object]$Schema,
    [string]$Path,
    [string]$Label,
    [System.Collections.ArrayList]$Errors
  )
  if ($null -eq $Schema) { return }
  $where = if ($Path) { $Path } else { "(root)" }

  if ($Schema.PSObject.Properties["type"]) {
    $allowedTypes = @($Schema.type)
    $matched = $false
    foreach ($allowedType in $allowedTypes) {
      if (Test-JsonTypeMatch -Value $Value -ExpectedType $allowedType) { $matched = $true; break }
    }
    if (-not $matched) {
      [void]$Errors.Add("$Label`: $where has the wrong type (expected $($allowedTypes -join '|'), found $(Get-JsonTypeName $Value))")
    }
  }

  if ($Schema.PSObject.Properties["const"] -and -not (Test-JsonScalarEqual -Left $Value -Right $Schema.const)) {
    [void]$Errors.Add("$Label`: $where must equal $($Schema.const | ConvertTo-Json -Compress)")
  }

  if ($Schema.PSObject.Properties["enum"]) {
    $enumValues = @($Schema.enum)
    $matched = $false
    foreach ($candidate in $enumValues) {
      if (Test-JsonScalarEqual -Left $Value -Right $candidate) { $matched = $true; break }
    }
    if (-not $matched) { [void]$Errors.Add("$Label`: $where must be one of $($enumValues -join ', ')") }
  }

  if ($Schema.PSObject.Properties["minLength"] -and $Value -is [string] -and $Value.Length -lt [int]$Schema.minLength) {
    [void]$Errors.Add("$Label`: $where is shorter than minLength $($Schema.minLength)")
  }

  if (Test-JsonTypeMatch -Value $Value -ExpectedType "object") {
    $declaredNames = @()
    $propertiesSchema = $Schema.PSObject.Properties["properties"]
    if ($propertiesSchema) { $declaredNames = @($propertiesSchema.Value.PSObject.Properties.Name) }

    foreach ($requiredKey in @($Schema.required)) {
      if ($null -eq $requiredKey) { continue }
      if (-not $Value.PSObject.Properties[$requiredKey]) {
        [void]$Errors.Add("$Label`: $(Join-JsonPath $Path $requiredKey) is required")
      }
    }

    foreach ($name in $declaredNames) {
      $property = $Value.PSObject.Properties[$name]
      if (-not $property) { continue }
      $propertySchema = $propertiesSchema.Value.PSObject.Properties[$name].Value
      Test-SchemaNode -Value $property.Value -Schema $propertySchema -Path (Join-JsonPath $Path $name) -Label $Label -Errors $Errors
    }

    if ($Schema.PSObject.Properties["additionalProperties"] -and $Schema.additionalProperties -eq $false) {
      foreach ($name in @($Value.PSObject.Properties.Name)) {
        if ($declaredNames -notcontains $name) {
          [void]$Errors.Add("$Label`: $(Join-JsonPath $Path $name) is not allowed")
        }
      }
    }
  }

  if (Test-JsonTypeMatch -Value $Value -ExpectedType "array") {
    $items = if ($null -eq $Value) { @() } else { @($Value) }
    if ($Schema.PSObject.Properties["uniqueItems"] -and $Schema.uniqueItems -eq $true) {
      $seen = [System.Collections.Generic.List[string]]::new()
      foreach ($item in $items) {
        $token = Get-JsonValueToken $item
        if ($seen.Contains($token)) {
          [void]$Errors.Add("$Label`: $where has duplicate items ($token)")
        } else {
          [void]$seen.Add($token)
        }
      }
    }
    $itemsSchema = $Schema.PSObject.Properties["items"]
    if ($itemsSchema) {
      $index = 0
      foreach ($item in $items) {
        Test-SchemaNode -Value $item -Schema $itemsSchema.Value -Path ($Path + "[" + $index + "]") -Label $Label -Errors $Errors
        $index++
      }
    }
  }
}

function Test-AgainstSchema {
  param([object]$Document, [object]$Schema, [string]$Label, [System.Collections.ArrayList]$Errors)
  Test-SchemaNode -Value $Document -Schema $Schema -Path "" -Label $Label -Errors $Errors
}

function Test-Document {
  param([string]$DocumentPath, [string]$SchemaPath, [string]$Label, [System.Collections.ArrayList]$Errors)
  if (-not (Test-Path $DocumentPath)) { [void]$Errors.Add("$Label`: missing $DocumentPath"); return }
  if (-not (Test-Path $SchemaPath)) { [void]$Errors.Add("$Label`: missing schema $SchemaPath"); return }
  $doc = Read-JsonSafe $DocumentPath
  if ($null -eq $doc) { [void]$Errors.Add("$Label`: invalid JSON in $DocumentPath"); return }
  $schema = Get-CachedSchema $SchemaPath
  if ($null -eq $schema) { [void]$Errors.Add("$Label`: invalid schema $SchemaPath"); return }
  Test-AgainstSchema -Document $doc -Schema $schema -Label $Label -Errors $Errors
}

$root = (Resolve-Path $ProjectRoot).Path
try {
  $gitRoot = (Invoke-Git -Root $root -Arguments @("rev-parse", "--show-toplevel") | Select-Object -First 1)
} catch {
  throw "Not inside a Git worktree. git said: $($_.Exception.Message)"
}
$gitRoot = (Resolve-Path $gitRoot.Trim()).Path
$devWork = Join-Path $gitRoot ".dev-work"
$schemaRoot = Join-Path (Split-Path -Parent $PSScriptRoot) "schemas"

# ---------------------------------------------------------------- core documents
$manifestPath = Join-Path $devWork "manifest.json"
$lockPath = Join-Path $devWork "coordinator-lock.json"
$activePath = Join-Path $devWork "active-run.json"
Test-Document $manifestPath (Join-Path $schemaRoot "manifest.schema.json") "manifest" $errors
Test-Document $lockPath (Join-Path $schemaRoot "coordinator-lock.schema.json") "coordinator-lock" $errors

$active = $null
$state = $null
$statePath = $null
if (Test-Path $activePath) {
  Test-Document $activePath (Join-Path $schemaRoot "active-run.schema.json") "active-run" $errors
  $active = Read-JsonSafe $activePath
  if ($active -and $active.runDirectory) {
    $runDir = Join-Path $devWork ($active.runDirectory -replace "/", "\")
    $statePath = Join-Path $runDir "run-state.json"
    Test-Document $statePath (Join-Path $schemaRoot "run-state.schema.json") "run-state" $errors
    $state = Read-JsonSafe $statePath

    # Assignment records are part of the run contract too.
    $assignmentsDir = Join-Path $runDir "assignments"
    if (Test-Path $assignmentsDir) {
      foreach ($file in Get-ChildItem $assignmentsDir -Filter *.json) {
        Test-Document $file.FullName (Join-Path $schemaRoot "assignment.schema.json") "assignments/$($file.Name)" $errors
      }
    }
    $checks["activeRun"] = $active.run
  }
} else {
  $warnings += "No active run: $activePath (the coordinator lock is still validated)."
}

$capabilitiesPath = Join-Path $devWork 'runtime/claude-capabilities.json'
if (Test-Path $capabilitiesPath) {
  Test-Document $capabilitiesPath (Join-Path $schemaRoot 'runtime-capabilities.schema.json') 'claude-capabilities' $errors
}

# ------------------------------------------------------------------- invariants
$lock = Read-JsonSafe $lockPath
$checks["invariantChecks"] = @()

if ($state) {
  # Invariant 3: the coordinator control branch is not a delivery/integration branch.
  if ($state.coordinatorControlBranch -and ($state.coordinatorControlBranch -eq $state.deliveryBranch)) {
    [void]$errors.Add("Invariant 3 violated: coordinator control branch equals delivery branch '$($state.deliveryBranch)'.")
  }
  # Invariant 1: one coordinator control workspace per project.
  if ($state.coordinatorWorktree -and ((Resolve-Path $state.coordinatorWorktree -ErrorAction SilentlyContinue).Path -ne $gitRoot)) {
    [void]$errors.Add("Invariant 1 violated: run-state coordinatorWorktree '$($state.coordinatorWorktree)' is not this worktree '$gitRoot'.")
  }
  # Delivery branch must exist locally; past intake this is an error, not a warning.
  # Existence probe: a missing ref exits 1 by design, so this stays a raw call that captures
  # stderr instead of a throwing Invoke-Git call.
  $branchProbe = & git -C $gitRoot show-ref --verify --quiet "refs/heads/$($state.deliveryBranch)" 2>&1
  if ($LASTEXITCODE -ne 0) {
    $message = "Delivery branch is not a local branch: $($state.deliveryBranch)"
    $probeDetail = ($branchProbe | Out-String).Trim()
    if ($probeDetail) { $message = "$message (git said: $probeDetail)" }
    if ($state.stage -and $state.stage -ne "intake") { [void]$errors.Add("$message (run stage is '$($state.stage)').") } else { $warnings += $message }
  }
  if ($lock -and $active) {
    # The lock and the active-run pointer must not diverge.
    if ($lock.activeRun -and ($lock.activeRun -ne $active.run)) {
      [void]$errors.Add("State divergence: coordinator-lock.activeRun '$($lock.activeRun)' != active-run.run '$($active.run)'.")
    }
    if ($lock.status -ne "active") {
      $warnings += "Coordinator lock status is '$($lock.status)' while a run is active."
    }
  }
}

# -------------------------------------------------------------- package checks
if (-not $SkipPackageChecks) {
  $skillRoot = Split-Path -Parent $PSScriptRoot
  $routing = Read-JsonSafe (Join-Path $skillRoot 'routing/model-routing.json')
  $catalog = Read-JsonSafe (Join-Path $skillRoot 'roles/catalog.json')
  $selection = Read-JsonSafe (Join-Path $skillRoot 'routing/role-selection.json')
  $skillCatalog = Read-JsonSafe (Join-Path $skillRoot 'routing/skill-catalog.json')
  foreach ($document in @(
    @{ name = 'model-routing'; value = $routing.roles },
    @{ name = 'role catalog'; value = $catalog.roles },
    @{ name = 'role-selection'; value = $selection.deliverableRoutes },
    @{ name = 'skill catalog'; value = $skillCatalog.skills }
  )) {
    if (-not $document.value) { [void]$errors.Add("Package $($document.name) is missing, invalid, or empty.") }
  }

  $roleIds = @($catalog.roles.id)
  $routingIds = @($routing.roles.PSObject.Properties.Name)
  $before = $errors.Count
  foreach ($roleId in $roleIds) {
    if ($routingIds -cnotcontains $roleId) { [void]$errors.Add("Catalog role '$roleId' is missing from model-routing.json.") }
  }
  foreach ($roleId in $routingIds) {
    if ($roleIds -cnotcontains $roleId) { [void]$errors.Add("Routing role '$roleId' is missing from roles/catalog.json.") }
  }
  $checks['modelRoutingRoles'] = ($routing.roles -and $catalog.roles -and $errors.Count -eq $before)

  $before = $errors.Count
  foreach ($route in $selection.deliverableRoutes.PSObject.Properties) {
    if ($roleIds -cnotcontains $route.Value) { [void]$errors.Add("Deliverable '$($route.Name)' selects unknown role '$($route.Value)'.") }
  }
  $checks['roleSelection'] = ($selection.deliverableRoutes -and $catalog.roles -and $errors.Count -eq $before)

  $before = $errors.Count
  $skillIds = @($skillCatalog.skills.id)
  foreach ($role in $catalog.roles) {
    if (-not $role.path -or -not (Test-Path -LiteralPath (Join-Path $skillRoot $role.path) -PathType Leaf)) {
      [void]$errors.Add("Role '$($role.id)' path not found: $($role.path).")
    }
    foreach ($skillId in @($role.defaultSkills) + @($role.optionalSkills)) {
      if ($skillIds -cnotcontains $skillId) { [void]$errors.Add("Role '$($role.id)' references unknown skill '$skillId'.") }
    }
  }
  $checks['roleCatalog'] = ($catalog.roles -and $skillCatalog.skills -and $errors.Count -eq $before)
  $checks["packageChecks"] = "enabled"
} else {
  $checks["packageChecks"] = "skipped"
}

# ------------------------------------------------------------------- templates
if ($IncludeTemplates) {
  $skillRoot = Split-Path -Parent $PSScriptRoot
  $templatesRoot = Join-Path $skillRoot "templates"
  Test-Document (Join-Path $templatesRoot "dev-work\manifest.json") (Join-Path $schemaRoot "manifest.schema.json") "template:manifest" $errors
  Test-Document (Join-Path $templatesRoot "dev-work\run-state.json") (Join-Path $schemaRoot "run-state.schema.json") "template:run-state" $errors
  Test-Document (Join-Path $templatesRoot "dev-work\assignment.json") (Join-Path $schemaRoot "assignment.schema.json") "template:assignment" $errors
  Test-Document (Join-Path $templatesRoot "dev-work\active-run.json") (Join-Path $schemaRoot "active-run.schema.json") "template:active-run" $errors
  Test-Document (Join-Path $templatesRoot "task-definition.json") (Join-Path $schemaRoot "task-definition.schema.json") "template:task-definition" $errors
  $checks["templates"] = "validated"
}

$result = [ordered]@{
  ok = ($errors.Count -eq 0)
  projectRoot = $gitRoot
  errors = $errors
  warnings = $warnings
  checks = $checks
}
$result | ConvertTo-Json -Depth 10
if ($errors.Count -gt 0) { exit 1 }
