#requires -Version 7.0
<##
Report selected Role/Skill dependency availability by name only.
Configured file values and current-process availability are separate fields.
##>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$Role,
  [string[]]$Skills = @(),
  [string]$ConfigPath = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'requirements-lib.ps1')
try {
  $resolution = Resolve-RequirementAvailability -ProjectRoot $ProjectRoot -RoleId $Role -SkillIds $Skills -ConfigPath $ConfigPath
  [ordered]@{ ok = ($resolution.Missing.Count -eq 0); role = $Role; skills = @($Skills); checks = $resolution.Checks; missing = $resolution.Missing } | ConvertTo-Json -Depth 10
  if ($resolution.Missing.Count -gt 0) { exit 1 }
  exit 0
} catch {
  [ordered]@{ ok = $false; errors = @($_.Exception.Message) } | ConvertTo-Json -Compress
  exit 1
}
