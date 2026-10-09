#requires -Version 7.0
<##
Invoke an explicit local executable with selected declared dependencies.
File values are literal data. Process values take precedence, only declared
names are added, and the parent process environment is never changed.
##>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$Role,
  [string[]]$Skills = @(),
  [string]$ConfigPath = '',
  [Parameter(Mandatory = $true)][string]$Executable,
  [string[]]$Arguments = @()
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'requirements-lib.ps1')
try {
  $root = (Resolve-Path -LiteralPath $ProjectRoot).Path
  $resolution = Resolve-RequirementAvailability -ProjectRoot $root -RoleId $Role -SkillIds $Skills -ConfigPath $ConfigPath
  if ($resolution.Missing.Count -gt 0) {
    [Console]::Error.WriteLine("Missing requirements: $($resolution.Missing -join ', ')")
    exit 1
  }
  $executablePath = $Executable
  if ($Executable.Contains('/') -or $Executable.Contains('\')) {
    if (-not [IO.Path]::IsPathRooted($Executable)) { $executablePath = Join-Path $root $Executable }
  } elseif ($Executable -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { throw 'Executable must be a command name or explicit file path.' }
  $command = Get-Command -Name $executablePath -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $command) { throw 'Executable not found.' }
  $start = [Diagnostics.ProcessStartInfo]::new()
  $start.FileName = $command.Source
  $start.WorkingDirectory = $root
  $start.UseShellExecute = $false
  foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
  $start.Environment.Clear()
  foreach ($entry in (Get-ChildRequirementEnvironment $resolution).GetEnumerator()) { $start.Environment[$entry.Key] = $entry.Value }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $start
  try {
    try { $started = $process.Start() } catch { throw 'Could not start the requested executable.' }
    if (-not $started) { throw 'Could not start the requested executable.' }
    $process.WaitForExit()
    exit $process.ExitCode
  } finally { $process.Dispose() }
} catch {
  [Console]::Error.WriteLine('Requirement configuration or child invocation failed; run check-requirements.ps1 for name-only configuration diagnostics.')
  exit 1
}
