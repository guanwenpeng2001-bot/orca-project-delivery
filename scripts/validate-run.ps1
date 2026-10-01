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
$errors = @()
$warnings = @()
$checks = [ordered]@{}

function Read-JsonSafe {
  param([string]$Path)
  try { return (Get-Content $Path -Raw | ConvertFrom-Json) } catch { return $null }
}

# Minimal, dependency-free validator for the schema keywords this package uses:
# required, type, const, enum, minLength, items, additionalProperties.
function Test-AgainstSchema {
  param([object]$Document, [object]$Schema, [string]$Label, [System.Collections.ArrayList]$Errors)
  foreach ($key in @($Schema.required)) {
    if ($null -eq $Document.PSObject.Properties[$key]) {
      [void]$Errors.Add("$Label`: missing required property '$key'")
      continue
    }
    $value = $Document.$key
    $prop = $Schema.properties.$key
    if (-not $prop) { continue }
    if ($null -ne $prop.const -and $value -ne $prop.const) {
      [void]$Errors.Add("$Label`: '$key' must equal '$($prop.const)'")
    }
    if ($prop.enum -and ($prop.enum -notcontains $value)) {
      [void]$Errors.Add("$Label`: '$key' is not one of [$($prop.enum -join ', ')]")
    }
    if ($prop.type) {
      $types = @($prop.type)
      $matched = $false
      foreach ($t in $types) {
        switch ($t) {
          "null" { if ($null -eq $value) { $matched = $true } }
          "string" { if ($value -is [string]) { $matched = $true } }
          "integer" { if ($value -is [int] -or $value -is [long]) { $matched = $true } }
          "number" { if ($value -is [int] -or $value -is [long] -or $value -is [double]) { $matched = $true } }
          "boolean" { if ($value -is [bool]) { $matched = $true } }
          "array" { if ($value -is [System.Array]) { $matched = $true } }
          "object" { if ($value -is [System.Management.Automation.PSCustomObject] -or $value -is [System.Collections.IDictionary]) { $matched = $true } }
          default { $matched = $true }
        }
      }
      if (-not $matched) { [void]$Errors.Add("$Label`: '$key' has the wrong type (expected $($types -join '|'))") }
    }
    if ($prop.minLength -and $value -is [string] -and $value.Length -lt $prop.minLength) {
      [void]$Errors.Add("$Label`: '$key' is shorter than minLength $($prop.minLength)")
    }
    if ($prop.items -and $prop.items.type -and $value -is [System.Array]) {
      $index = 0
      foreach ($item in $value) {
        if ($prop.items.type -eq "string" -and -not ($item -is [string])) {
          [void]$Errors.Add("$Label`: '$key'[$index] is not a string")
        }
        if ($prop.items.type -eq "object" -and -not ($item -is [System.Management.Automation.PSCustomObject])) {
          [void]$Errors.Add("$Label`: '$key'[$index] is not an object")
        }
        $index++
      }
    }
  }
}

function Test-Document {
  param([string]$DocumentPath, [string]$SchemaPath, [string]$Label, [System.Collections.ArrayList]$Errors)
  if (-not (Test-Path $DocumentPath)) { [void]$Errors.Add("$Label`: missing $DocumentPath"); return }
  if (-not (Test-Path $SchemaPath)) { [void]$Errors.Add("$Label`: missing schema $SchemaPath"); return }
  $doc = Read-JsonSafe $DocumentPath
  if ($null -eq $doc) { [void]$Errors.Add("$Label`: invalid JSON in $DocumentPath"); return }
  $schema = Read-JsonSafe $SchemaPath
  if ($null -eq $schema) { [void]$Errors.Add("$Label`: invalid schema $SchemaPath"); return }
  Test-AgainstSchema -Document $doc -Schema $schema -Label $Label -Errors $Errors
}

$root = (Resolve-Path $ProjectRoot).Path
$gitRoot = (& git -C $root rev-parse --show-toplevel 2>$null)
if (-not $gitRoot) { throw "Not inside a Git worktree." }
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
        Test-Document $file.FullName (Join-Path $schemaRoot "assignment.schema.json") "assignment:$($file.BaseName)" $errors
      }
    }
    $checks["activeRun"] = $active.run
  }
} else {
  $warnings += "No active run: $activePath (the coordinator lock is still validated)."
}

# ------------------------------------------------------------------- invariants
$lock = Read-JsonSafe $lockPath
$checks["invariantChecks"] = @()

if ($state) {
  # Invariant 3: the coordinator control branch is not a delivery/integration branch.
  if ($state.coordinatorControlBranch -and ($state.coordinatorControlBranch -eq $state.deliveryBranch)) {
    $errors += "Invariant 3 violated: coordinator control branch equals delivery branch '$($state.deliveryBranch)'."
  }
  # Invariant 1: one coordinator control workspace per project.
  if ($state.coordinatorWorktree -and ((Resolve-Path $state.coordinatorWorktree -ErrorAction SilentlyContinue).Path -ne $gitRoot)) {
    $errors += "Invariant 1 violated: run-state coordinatorWorktree '$($state.coordinatorWorktree)' is not this worktree '$gitRoot'."
  }
  # Delivery branch must exist locally; past intake this is an error, not a warning.
  & git -C $gitRoot show-ref --verify --quiet "refs/heads/$($state.deliveryBranch)"
  if ($LASTEXITCODE -ne 0) {
    $message = "Delivery branch is not a local branch: $($state.deliveryBranch)"
    if ($state.stage -and $state.stage -ne "intake") { $errors += "$message (run stage is '$($state.stage)')." } else { $warnings += $message }
  }
  if ($lock -and $active) {
    # The lock and the active-run pointer must not diverge.
    if ($lock.activeRun -and ($lock.activeRun -ne $active.run)) {
      $errors += "State divergence: coordinator-lock.activeRun '$($lock.activeRun)' != active-run.run '$($active.run)'."
    }
    if ($lock.status -ne "active") {
      $warnings += "Coordinator lock status is '$($lock.status)' while a run is active."
    }
  }
}

# -------------------------------------------------------------- package checks
if (-not $SkipPackageChecks) {
  $skillRoot = Split-Path -Parent $PSScriptRoot
  $skillsRoot = Split-Path -Parent $skillRoot

  # Duplicate authority: the routing table and the role compatibility matrix must agree.
  $agentSelectionPath = Join-Path $skillRoot "routing\agent-selection.json"
  $roleCompatPath = Join-Path $skillRoot "agents\role-compatibility.json"
  if ((Test-Path $agentSelectionPath) -and (Test-Path $roleCompatPath)) {
    $selection = Read-JsonSafe $agentSelectionPath
    $compat = Read-JsonSafe $roleCompatPath
    $selectionRoles = $selection.roleRoutes
    $compatRoles = $compat.roles
    foreach ($roleId in @($selectionRoles.PSObject.Properties.Name)) {
      if (-not $compatRoles.PSObject.Properties[$roleId]) {
        $errors += "Routing role '$roleId' exists in agent-selection.json but not in role-compatibility.json."
        continue
      }
      $a = $selectionRoles.$roleId | ConvertTo-Json -Depth 10 -Compress
      $b = $compatRoles.$roleId | ConvertTo-Json -Depth 10 -Compress
      if ($a -ne $b) { $errors += "Duplicate authority drift for role '$roleId' (agent-selection.json != role-compatibility.json)." }
    }
    foreach ($roleId in @($compatRoles.PSObject.Properties.Name)) {
      if (-not $selectionRoles.PSObject.Properties[$roleId]) {
        $errors += "Routing role '$roleId' exists in role-compatibility.json but not in agent-selection.json."
      }
    }
  }

  # Routing order: a profile that must not auto-route may not precede one that may.
  $profilesPath = Join-Path $skillRoot "agents\configured-profiles.json"
  if ((Test-Path $agentSelectionPath) -and (Test-Path $profilesPath)) {
    $profiles = Read-JsonSafe $profilesPath
    $mayAutoRoute = @{}
    foreach ($p in $profiles.profiles) { $mayAutoRoute[$p.id] = [bool]$p.autoRouteAfterProbe }
    $selection = Read-JsonSafe $agentSelectionPath
    foreach ($roleId in @($selection.roleRoutes.PSObject.Properties.Name)) {
      $seenExcluded = $null
      foreach ($profileId in @($selection.roleRoutes.$roleId.preferredProfiles)) {
        if (-not $mayAutoRoute.ContainsKey($profileId)) {
          $errors += "Role '$roleId' prefers unknown profile '$profileId'."
          continue
        }
        if ($mayAutoRoute[$profileId]) {
          if ($seenExcluded) { $errors += "Role '$roleId' prefers '$profileId' after non-auto-route profile '$seenExcluded'." }
        } elseif (-not $seenExcluded) {
          $seenExcluded = $profileId
        }
      }
    }
  }

  # Declared professional skills must exist as sibling skills. Catalog paths are
  # package-root relative, i.e. "..\<skill>\SKILL.md" from this package directory.
  $skillCatalogPath = Join-Path $skillRoot "routing\skill-catalog.json"
  if (Test-Path $skillCatalogPath) {
    $catalog = Read-JsonSafe $skillCatalogPath
    foreach ($entry in $catalog.skills) {
      $resolved = Join-Path $skillRoot ($entry.path -replace "/", "\")
      if (-not (Test-Path $resolved)) { $errors += "Declared skill '$($entry.id)' not found at $resolved." }
    }
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
