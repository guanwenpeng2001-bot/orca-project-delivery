#requires -Version 7.0
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

. (Join-Path $PSScriptRoot 'project-common.ps1')

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

# Cache raw schema text for this invocation; Test-Json owns JSON/schema semantics.
$script:schemaCache = @{}
function Get-CachedSchema {
  param([string]$SchemaPath)
  if (-not $script:schemaCache.Contains($SchemaPath)) {
    $script:schemaCache[$SchemaPath] = [IO.File]::ReadAllText($SchemaPath)
  }
  return $script:schemaCache[$SchemaPath]
}

function Format-SchemaDiagnostic {
  param([System.Management.Automation.ErrorRecord]$ValidationError)
  $message = $ValidationError.ToString()
  # Keep the engine's complete diagnostic, including its JSON pointer. Add the
  # legacy dotted path when a required-property error only identifies its parent.
  # Match the engine detail and quoted pointer, not the localized wrapper text.
  $missing = [regex]::Match($message, 'Required properties (\[[^\r\n]*?\]) are not present')
  $quotes = [regex]::Escape(('"' + "'" + [char]0x2018 + [char]0x2019 + [char]0x201c + [char]0x201d))
  $pointer = [regex]::Match($message, "[$quotes](?<path>/[^$quotes]*)[$quotes]")
  if ($missing.Success -and $pointer.Success) {
    $parent = ($pointer.Groups['path'].Value.TrimStart('/') -split '/' | ForEach-Object { $_.Replace('~1', '/').Replace('~0', '~') }) -join '.'
    $paths = foreach ($name in (ConvertFrom-Json -InputObject $missing.Groups[1].Value)) {
      if ($parent) { "$parent.$name" } else { $name }
    }
    $message += " (required: $($paths -join ', '))"
  }
  return $message
}

function Test-Document {
  param([string]$DocumentPath, [string]$SchemaPath, [string]$Label, [System.Collections.ArrayList]$Errors)
  if (-not (Test-Path -LiteralPath $DocumentPath)) { [void]$Errors.Add("$Label`: missing $DocumentPath"); return }
  if (-not (Test-Path -LiteralPath $SchemaPath)) { [void]$Errors.Add("$Label`: missing schema $SchemaPath"); return }
  try {
    $document = [IO.File]::ReadAllText($DocumentPath)
    $schema = Get-CachedSchema $SchemaPath
    $validationErrors = @()
    $valid = Test-Json -Json $document -Schema $schema -ErrorAction SilentlyContinue -ErrorVariable validationErrors
    if (-not $valid) {
      foreach ($validationError in $validationErrors) {
        [void]$Errors.Add("$Label`: $(Format-SchemaDiagnostic $validationError)")
      }
      if ($validationErrors.Count -eq 0) { [void]$Errors.Add("$Label`: schema validation failed in $DocumentPath") }
    } else {
      # State consumers use PSCustomObject parsing. Reject schema-valid JSON that
      # they cannot read (including case-variant keys), so skipped state is never success.
      $null = ConvertFrom-Json -InputObject $document -ErrorAction Stop
    }
  } catch {
    [void]$Errors.Add("$Label`: validation failed in $DocumentPath (schema $SchemaPath): $($_.Exception.Message)")
  }
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
    $wavesDir = Join-Path $runDir 'dispatch-waves'
    if (Test-Path -LiteralPath $wavesDir -PathType Container) {
      foreach ($file in Get-ChildItem -LiteralPath $wavesDir -Filter *.json -File) {
        Test-Document $file.FullName (Join-Path $schemaRoot 'dispatch-wave.schema.json') "dispatch-waves/$($file.Name)" $errors
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
  if (@($state.completedStages | Where-Object { $_ -cin @('reconnaissance', 'dynamic-reconnaissance', 'parallel-reconnaissance') }).Count -gt 0 -and -not $state.stageDecisions.design) {
    $warnings += "Design verdict is missing: stageDecisions.design must record the evaluation after reconnaissance."
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
  try {
    . (Join-Path $PSScriptRoot 'requirements-lib.ps1')
    $null = Get-RequirementsCatalog $skillRoot
    $checks['catalogRequirements'] = $true
  } catch {
    [void]$errors.Add($_.Exception.Message)
    $checks['catalogRequirements'] = $false
  }
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
