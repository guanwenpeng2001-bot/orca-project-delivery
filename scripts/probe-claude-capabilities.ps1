#requires -Version 7.0
[CmdletBinding()]
param(
  [string]$ProjectRoot = (Get-Location).Path,
  [string]$RoutingPath,
  [switch]$Standalone,
  [ValidateRange(1, 2147483647)]
  [int]$CommandTimeoutMs = 20000
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

# Hosts can leave an orphaned count after stripping GIT_CONFIG_KEY_n variables.
if ($env:GIT_CONFIG_COUNT -and -not $env:GIT_CONFIG_KEY_0) {
  Remove-Item Env:GIT_CONFIG_COUNT -ErrorAction SilentlyContinue
}

# Drain both pipes concurrently and bound every CLI call, including shim processes.
function Invoke-CliCaptured {
  param([string]$ExePath, [string[]]$Arguments, [int]$TimeoutMs)
  $process = [System.Diagnostics.Process]::new()
  try {
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $ExePath
    if ([IO.Path]::GetExtension($ExePath) -eq '.ps1') {
      $start.FileName = (Get-Command pwsh -ErrorAction Stop).Source
      $Arguments = @('-NoProfile', '-File', $ExePath) + $Arguments
    } elseif ([IO.Path]::GetExtension($ExePath) -in @('.cmd', '.bat')) {
      $start.FileName = $env:ComSpec
      $Arguments = @('/c', $ExePath) + $Arguments
    }
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $process.StartInfo = $start
    if (-not $process.Start()) { throw 'Process could not be started.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutMs)) {
      try { $process.Kill($true) } catch { }
      return @{ exitCode = $null; stdOut = ''; stdErr = ''; reason = "Timed out after ${TimeoutMs}ms" }
    }
    return @{
      exitCode = $process.ExitCode
      stdOut = $stdoutTask.GetAwaiter().GetResult().Trim()
      stdErr = $stderrTask.GetAwaiter().GetResult().Trim()
      reason = $null
    }
  } catch {
    return @{ exitCode = $null; stdOut = ''; stdErr = ''; reason = $_.Exception.Message }
  } finally { $process.Dispose() }
}

function Get-CliVersion {
  param([string]$ExePath, [int]$TimeoutMs)
  $result = Invoke-CliCaptured $ExePath @('--version') $TimeoutMs
  $version = [string]($result.stdOut -split '\r?\n' | Where-Object { $_ -match '\S' } | Select-Object -First 1)
  return @{ ok = ($result.exitCode -eq 0 -and [bool]$version); version = $version }
}

function Get-OrcaOptionVerdict {
  param([string]$OutputText)
  try { $receipt = ConvertFrom-Json -InputObject $OutputText -ErrorAction Stop } catch { return 'unknown' }
  if ($receipt.ok -isnot [bool]) { return 'unknown' }
  if ($receipt.ok) { return 'launched' }
  $code = [string]$receipt.error.code
  $message = [string]$receipt.error.message
  if ($code -eq 'invalid_argument' -and $message -match 'Agent claude model .+ does not support (?:effort|model)\b') { return 'rejected' }
  if ($code -eq 'repo_not_found' -or ($code -eq 'invalid_argument' -and $message -match '\brepo_not_found\b')) { return 'accepted' }
  return 'unknown'
}

# Run sentinel probes from the coordinator terminal bound to the Orca Run.
# Workers receive consumer_fenced, which is not evidence about model support.
function Test-OrcaModelOption {
  param([string]$ExePath, [string]$Model, [string]$Effort, [int]$TimeoutMs)
  $arguments = @('orchestration', 'worker-start', '--spec', 'option probe', '--worktree', 'new-top-level',
    '--repo', 'id:00000000-0000-0000-0000-000000000000', '--base-branch', 'main', '--setup', 'skip',
    '--name', 'claude-capability-probe',
    '--agent', 'claude', '--model', $Model)
  if ($Effort) { $arguments += @('--effort', $Effort) }
  $arguments += @('--timeout-ms', '15000', '--json')
  $response = Invoke-CliCaptured $ExePath $arguments $TimeoutMs
  if ($null -eq $response.exitCode) { return 'unknown' }
  try {
    $receipt = $response.stdOut | ConvertFrom-Json -ErrorAction Stop
    if ($receipt.error.code -eq 'consumer_fenced') { $script:consumerFenced = $true }
  } catch { }
  return Get-OrcaOptionVerdict $response.stdOut
}

try {
  $root = (Resolve-Path $ProjectRoot).Path
  $devWork = Join-Path $root '.dev-work'
  if (-not $Standalone -and -not (Test-Path -LiteralPath (Join-Path $devWork 'manifest.json') -PathType Leaf)) {
    throw '.dev-work is not initialized. Run bootstrap-project.ps1 first, or pass -Standalone.'
  }
  if (-not $RoutingPath) { $RoutingPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'routing/model-routing.json' }
  $routing = Get-Content -Encoding utf8 -LiteralPath $RoutingPath -Raw | ConvertFrom-Json
  if (-not $routing.modelTiers -or -not $routing.vocabulary.modelLadder -or -not $routing.vocabulary.effortLevels) {
    throw 'Routing file lacks modelTiers or vocabulary.'
  }
  $combos = @()
  foreach ($tier in $routing.vocabulary.modelLadder) {
    $tierConfig = $routing.modelTiers.PSObject.Properties[$tier].Value
    if (-not $tierConfig.preferred) { throw "Routing tier '$tier' lacks a preferred request." }
    foreach ($request in @($tierConfig.preferred, $tierConfig.fallback)) {
      if ($null -eq $request) { continue }
      if ($request.model -isnot [string] -or -not $request.model -or $request.withEffort -isnot [bool]) { throw "Invalid request for tier '$tier'." }
      $efforts = @($null)
      if ($request.withEffort) { $efforts = @($routing.vocabulary.effortLevels) }
      foreach ($effort in $efforts) {
        $combos += [ordered]@{ tier = $tier; model = $request.model; effort = $effort; verdict = 'unknown' }
      }
    }
  }
  $claudeCommand = Get-Command claude -ErrorAction SilentlyContinue
  if (-not $claudeCommand) { throw 'Claude CLI was not found.' }
  $version = Get-CliVersion $claudeCommand.Source $CommandTimeoutMs
  if (-not $version.ok) { throw 'Claude CLI did not return a version on stdout with exit code 0.' }
  $help = Invoke-CliCaptured $claudeCommand.Source @('--help') $CommandTimeoutMs
  $effortHelp = Invoke-CliCaptured $claudeCommand.Source @('--effort', '__probe__', '--help') $CommandTimeoutMs
  $effortText = $effortHelp.stdOut + "`n" + $effortHelp.stdErr
  $effortValues = @()
  if ($effortText -match 'Valid values:\s*(?<list>[a-z]+(?:\s*,\s*[a-z]+)*)') {
    $effortValues = @($Matches.list -split ',' | ForEach-Object { $_.Trim() })
  }
  $warnings = @()
  $claudeCli = [ordered]@{
    detected = $true; command = $claudeCommand.Source; version = $version.version
    modelFlag = ($help.exitCode -eq 0 -and $help.stdOut -match '--model\b')
    effortFlag = ($help.exitCode -eq 0 -and $help.stdOut -match '--effort\b')
    effortValues = $effortValues
  }
  if (-not $claudeCli.modelFlag -or -not $claudeCli.effortFlag -or -not $effortValues.Count) {
    $warnings += 'Claude CLI model/effort contract could not be fully verified.'
  }
  $script:consumerFenced = $false
  $orcaCommand = Get-Command orca -ErrorAction SilentlyContinue
  $exitCode = 0
  if (-not $orcaCommand) {
    $exitCode = 2
    $warnings += 'Orca CLI was not found; all combinations remain unknown.'
  } else {
    foreach ($combo in $combos) {
      $combo.verdict = Test-OrcaModelOption $orcaCommand.Source $combo.model $combo.effort $CommandTimeoutMs
      if ($combo.verdict -eq 'launched') {
        $combo['verification'] = 'unverified'
        $warnings += 'Sentinel unexpectedly launched a worker. Probing stopped; contact the coordinator immediately.'
        break
      }
      if ($combo.verdict -eq 'unknown') { $warnings += "No parameter-validation evidence for $($combo.model) / $($combo.effort)." }
    }
  }
  if ($script:consumerFenced) { $warnings += '未在绑定 Run 的协调者终端运行；consumer_fenced 组合保持 unknown。' }
  $result = [ordered]@{
    schemaVersion = 2
    checkedAt = [DateTimeOffset]::UtcNow.ToString('o')
    routingFileHash = (Get-FileHash -LiteralPath $RoutingPath -Algorithm SHA256).Hash.ToLowerInvariant()
    policy = '本文件是哨兵实测快照；accepted 只表示 Orca 参数校验放行，effective 以首次 worker-start 回执 launch.effective 为准。'
    claudeCli = $claudeCli
    combos = $combos
    warnings = $warnings
  }
  $json = $result | ConvertTo-Json -Depth 10
  if (-not $Standalone) {
    $runtimeDirectory = Join-Path $devWork 'runtime'
    New-Item -ItemType Directory -Path $runtimeDirectory -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $runtimeDirectory 'claude-capabilities.json'), $json + "`n", [Text.UTF8Encoding]::new($false))
  }
  $json
  exit $exitCode
} catch {
  Write-Error $_ -ErrorAction Continue
  exit 1
}
