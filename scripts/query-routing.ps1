#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Role,
  [string]$ProjectRoot = (Get-Location).Path
)

[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$routing = Get-Content -LiteralPath (Join-Path $packageRoot 'routing/model-routing.json') -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
$catalog = Get-Content -LiteralPath (Join-Path $packageRoot 'roles/catalog.json') -Raw -Encoding utf8 | ConvertFrom-Json
$catalogIds = @($catalog.roles.id)
$routingIds = @($routing.roles.Keys)
$missingRouting = @($catalogIds | Where-Object { $_ -cnotin $routingIds })
$missingCatalog = @($routingIds | Where-Object { $_ -cnotin $catalogIds })
if ($missingRouting.Count -or $missingCatalog.Count) {
  [Console]::Error.WriteLine("Role inconsistency between roles/catalog.json and routing/model-routing.json: missing from routing: [$($missingRouting -join ', ')]; missing from catalog: [$($missingCatalog -join ', ')].")
  exit 1
}
if ($Role -cnotin $catalogIds) {
  [Console]::Error.WriteLine("Unknown role '$Role'. Valid ids: $($catalogIds -join ', ').")
  exit 1
}
$roleEntry = $routing.roles[$Role]
$tiers = [ordered]@{}
foreach ($step in $roleEntry.chain) { $tiers[$step.tier] = $routing.modelTiers[$step.tier] }
$policies = [ordered]@{}
foreach ($name in @('escalate', 'downgrade', 'suspend', 'userPinned', 'trivialTaskAdjustment', 'recording')) {
  $policies[$name] = $routing.policies[$name]
}
$slice = [ordered]@{
  roles = [ordered]@{ $Role = $roleEntry }
  modelTiers = $tiers
  policies = $policies
  vocabulary = $routing.vocabulary
}
$capabilitiesPath = '.dev-work/runtime/claude-capabilities.json'
if (Test-Path -LiteralPath (Join-Path $ProjectRoot $capabilitiesPath) -PathType Leaf) {
  $slice.capabilities = @{ path = $capabilitiesPath }
}
[Console]::WriteLine(($slice | ConvertTo-Json -Depth 20 -Compress))
