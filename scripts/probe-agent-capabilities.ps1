[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = (Get-Location).Path,

  [Parameter(Mandatory = $false)]
  [string]$RegistryPath,

  [Parameter(Mandatory = $false)]
  [switch]$Standalone,

  [Parameter(Mandatory = $false)]
  [switch]$SkipModelProbe,

  [Parameter(Mandatory = $false)]
  [int]$VersionTimeoutMs = 8000,

  [Parameter(Mandatory = $false)]
  [int]$CommandTimeoutMs = 20000
)

$ErrorActionPreference = "Stop"
$warnings = @()

function Write-JsonFile {
  param([string]$Path, [object]$Value)
  $json = $Value | ConvertTo-Json -Depth 30
  [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

# Run a CLI, capture merged output, and never hang: the child is killed on timeout.
function Invoke-CliCaptured {
  param([string]$ExePath, [string]$Arguments, [int]$TimeoutMs = 8000)
  $file = $ExePath
  $argLine = $Arguments
  switch ([System.IO.Path]::GetExtension($ExePath).ToLowerInvariant()) {
    ".ps1" {
      $pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
      if (-not $pwshPath) { return @{ ok = $false; timedOut = $false; exitCode = $null; output = $null; reason = "pwsh not found for a .ps1 shim" } }
      $argLine = "-NoProfile -File `"$ExePath`" $Arguments"
      $file = $pwshPath
    }
    ".cmd" {
      $argLine = "/c `"$ExePath`" $Arguments"
      $file = $env:ComSpec
    }
  }
  try {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $file
    $psi.Arguments = $argLine
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    if (-not $p.WaitForExit($TimeoutMs)) {
      try { $p.Kill($true) } catch { }
      return @{ ok = $false; timedOut = $true; exitCode = $null; output = $null; reason = "timed out after ${TimeoutMs}ms" }
    }
    $text = ($p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()).Trim()
    return @{ ok = ($p.ExitCode -eq 0); timedOut = $false; exitCode = $p.ExitCode; output = $text; reason = $null }
  } catch {
    return @{ ok = $false; timedOut = $false; exitCode = $null; output = $null; reason = $_.Exception.Message }
  }
}

function Get-CliVersion {
  param([string]$ExePath, [int]$TimeoutMs = 8000)
  if (-not $ExePath) { return $null }
  $result = Invoke-CliCaptured -ExePath $ExePath -Arguments "--version" -TimeoutMs $TimeoutMs
  if ($result.timedOut) { $script:warnings += "Version probe timed out: $ExePath"; return $null }
  if (-not $result.output) { return $null }
  return [string](($result.output -split "`r?`n")[0])
}

function Read-TomlScalar {
  param([string]$Path, [string]$Key)
  if (-not (Test-Path $Path)) { return $null }
  $match = Select-String -Path $Path -Pattern ("^\s*" + [regex]::Escape($Key) + "\s*=\s*(.+?)\s*$") | Select-Object -First 1
  if (-not $match) { return $null }
  return $match.Matches[0].Groups[1].Value.Trim().Trim('"')
}

function Read-TomlArray {
  param([string]$Path, [string]$Key)
  $raw = Read-TomlScalar -Path $Path -Key $Key
  if (-not $raw) { return @() }
  $raw = $raw.Trim()
  if ($raw.StartsWith("[") -and $raw.EndsWith("]")) { $raw = $raw.Substring(1, $raw.Length - 2) }
  return @($raw -split "," | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ })
}

# Minimal reader for the `[models."<id>"]` blocks used by the Kimi config.
function Get-KimiModelTable {
  param([string]$Path)
  $table = @{}
  if (-not (Test-Path $Path)) { return $table }
  $current = $null
  foreach ($line in Get-Content $Path) {
    if ($line -match '^\s*\[models\."(?<id>[^"]+)"\]\s*$') {
      $current = $Matches.id
      if (-not $table.ContainsKey($current)) { $table[$current] = @{ supportEfforts = @(); defaultEffort = $null } }
      continue
    }
    if ($line -match '^\s*\[') { $current = $null; continue }
    if (-not $current) { continue }
    if ($line -match '^\s*support_efforts\s*=\s*\[(?<list>.*)\]\s*$') {
      $table[$current].supportEfforts = @($Matches.list -split "," | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ })
    } elseif ($line -match '^\s*default_effort\s*=\s*"?(?<value>[^"\s]+)"?\s*$') {
      $table[$current].defaultEffort = $Matches.value
    }
  }
  return $table
}

$root = (Resolve-Path $ProjectRoot).Path
$gitRoot = (& git -C $root rev-parse --show-toplevel 2>$null)
if (-not $gitRoot) { throw "Not inside a Git worktree." }
$gitRoot = (Resolve-Path $gitRoot.Trim()).Path

$devWork = Join-Path $gitRoot ".dev-work"
if ((-not $Standalone) -and (-not (Test-Path (Join-Path $devWork "manifest.json")))) {
  throw ".dev-work is not initialized in $gitRoot. Run scripts/bootstrap-project.ps1 first, or pass -Standalone."
}

$skillRoot = Split-Path -Parent $PSScriptRoot
if (-not $RegistryPath) {
  $RegistryPath = Join-Path $skillRoot "agents\registry.json"
}
$registry = Get-Content $RegistryPath -Raw | ConvertFrom-Json

$isWin = $false
if (Get-Variable IsWindows -ErrorAction SilentlyContinue) {
  $isWin = [bool]$IsWindows
} elseif ($env:OS -eq "Windows_NT") {
  $isWin = $true
}
$runtime = $(if ($isWin) { "win32" } else { "linux" })

$rows = @()
foreach ($agent in $registry.agents) {
  $unsupported = @($agent.unsupportedRuntimes) -contains $runtime
  $commands = @($agent.detectCmd) + @($agent.detectAliases)
  $found = $null
  foreach ($cmd in $commands) {
    $candidate = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($candidate) {
      $found = $candidate
      break
    }
  }

  $missingRequired = @()
  foreach ($required in @($agent.requiredCommands)) {
    if (-not (Get-Command $required -ErrorAction SilentlyContinue)) {
      $missingRequired += $required
    }
  }

  $detected = ($null -ne $found) -and ($missingRequired.Count -eq 0) -and (-not $unsupported)
  $version = $null
  if ($detected) {
    $version = Get-CliVersion -ExePath $found.Source -TimeoutMs $VersionTimeoutMs
  }

  $notes = @($agent.notes)
  if ($unsupported) { $notes += "Unsupported on runtime $runtime." }
  if ($missingRequired.Count -gt 0) { $notes += "Missing required commands: $($missingRequired -join ', ')." }

  $rows += [ordered]@{
    id = $agent.id
    displayName = $agent.displayName
    detected = $detected
    runtimeSupported = (-not $unsupported)
    command = $(if ($found) { $found.Source } else { $null })
    version = $version
    missingRequiredCommands = $missingRequired
    modelControl = $agent.modelControl
    supportsWorkerLaunchPreferences = [bool]$agent.supportsWorkerLaunchPreferences
    skillDelivery = $agent.skillDelivery
    autoRouteConfigured = [bool]$agent.autoRoute
    autoRouteEligible = $detected -and [bool]$agent.autoRoute
    notes = $notes
  }
}

$targetDir = Join-Path $devWork "runtime"
if (-not (Test-Path $targetDir)) {
  New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

$output = [ordered]@{
  schemaVersion = 1
  host = [ordered]@{
    machine = [Environment]::MachineName
    user = [Environment]::UserName
    runtime = $runtime
    powershell = $PSVersionTable.PSVersion.ToString()
  }
  checkedAt = [DateTimeOffset]::UtcNow.ToString("o")
  registryPath = (Resolve-Path $RegistryPath).Path
  agents = $rows
}
$target = Join-Path $targetDir "runtime-capabilities.json"

# --------------------------------------------------------------- model evidence
# A profile is only eligible for automatic routing once its model/effort can be
# verified on this host. Unverifiable is recorded as unverifiable, never as success.
$modelOutput = $null
if (-not $SkipModelProbe) {
  $profilesPath = Join-Path $skillRoot "agents\configured-profiles.json"
  $profiles = Get-Content $profilesPath -Raw | ConvertFrom-Json

  $detectedById = @{}
  foreach ($row in $rows) { $detectedById[$row.id] = $row }

  $codexConfig = Join-Path $env:USERPROFILE ".codex\config.toml"
  $codexModel = Read-TomlScalar -Path $codexConfig -Key "model"
  $codexEffort = Read-TomlScalar -Path $codexConfig -Key "model_reasoning_effort"
  $codexEfforts = Read-TomlArray -Path $codexConfig -Key "enabled-reasoning-efforts"

  $kimiConfig = Join-Path $env:USERPROFILE ".kimi-code\config.toml"
  $kimiDefault = Read-TomlScalar -Path $kimiConfig -Key "default_model"
  $kimiModels = Get-KimiModelTable -Path $kimiConfig

  $grokRow = $detectedById["grok"]
  $grokModels = $null
  if ($grokRow -and $grokRow.detected) {
    $grokResult = Invoke-CliCaptured -ExePath $grokRow.command -Arguments "models" -TimeoutMs $CommandTimeoutMs
    if ($grokResult.ok) { $grokModels = $grokResult.output }
  }

  $agyRow = $detectedById["antigravity"]
  $agyHelp = $null
  if ($agyRow -and $agyRow.detected) {
    $agyResult = Invoke-CliCaptured -ExePath $agyRow.command -Arguments "--help" -TimeoutMs $CommandTimeoutMs
    if ($agyResult.output) { $agyHelp = $agyResult.output }
  }
  $agyEfforts = @()
  if ($agyHelp -and $agyHelp -match 'effort[^\r\n]*\((?<list>[a-z\|]+)\)') {
    $agyEfforts = @($Matches.list -split '\|' | Where-Object { $_ })
  }

  $profileRows = @()
  foreach ($profile in $profiles.profiles) {
    $row = $detectedById[$profile.agent]
    $evidence = @()
    $supportedEfforts = @()
    $verified = $false
    $verificationPath = $null

    switch ($profile.agent) {
      "codex" {
        if (Test-Path $codexConfig) { $evidence += "config: $codexConfig" }
        if ($codexModel) { $evidence += "config model='$codexModel' effort='$codexEffort'" }
        $supportedEfforts = $codexEfforts
        if ($codexModel -and ($profile.model -eq $codexModel) -and ($profile.effort -in $codexEfforts)) { $verified = $true }
        $verificationPath = "config.toml + worker-start receipt (launch.requested vs launch.effective)"
      }
      "kimi" {
        if (Test-Path $kimiConfig) { $evidence += "config: $kimiConfig" }
        if ($kimiDefault) { $evidence += "default_model='$kimiDefault'" }
        if ($kimiModels.ContainsKey($profile.model)) {
          $supportedEfforts = @($kimiModels[$profile.model].supportEfforts)
          $evidence += "support_efforts=[$($supportedEfforts -join ', ')] default_effort='$($kimiModels[$profile.model].defaultEffort)'"
          if ((-not $profile.effort) -or ($profile.effort -in $supportedEfforts)) { $verified = $true }
        } else {
          $evidence += "model table '$($profile.model)' not found in config.toml"
        }
        $verificationPath = "config.toml [models." + $profile.model + "] + in-session model/effort surface (session-command mode)"
      }
      "grok" {
        if ($grokModels) {
          $evidence += "grok models: $((@($grokModels -split "`r?`n" | Where-Object { $_ -match '\S' }) | Select-Object -First 3) -join ' / ')"
          if ($grokModels -match ("(?m)^\s*[\*\-]\s*" + [regex]::Escape($profile.model) + "\b") -or $grokModels -match ("Default model:\s*" + [regex]::Escape($profile.model))) {
            $verified = $true
          }
        } else {
          $evidence += "grok models could not be read"
        }
        $evidence += "effort: --reasoning-effort/--effort flag present; accepted values are not advertised"
        $verificationPath = "grok models + worker-start receipt"
      }
      "antigravity" {
        if ($agyHelp) {
          $evidence += "agy --help advertises --model and --effort"
          $supportedEfforts = $agyEfforts
          if ($agyEfforts.Count -gt 0) { $evidence += "effort choices=[$($agyEfforts -join ', ')]" }
        } else {
          $evidence += "agy --help could not be read"
        }
        $evidence += "model '$($profile.model)' existence is not listable from the CLI"
        $verificationPath = "worker-start receipt (launch.requested vs launch.effective)"
      }
      default {
        $evidence += "No host-side model probe implemented for agent '$($profile.agent)'."
        $verificationPath = "worker-start receipt (launch.requested vs launch.effective)"
      }
    }

    $profileRows += [ordered]@{
      profileId = $profile.id
      agent = $profile.agent
      model = $profile.model
      effort = $profile.effort
      declaredModelControl = $profile.modelControl
      agentDetected = [bool]($row -and $row.detected)
      agentSupportsLaunchPreferences = [bool]($row -and $row.supportsWorkerLaunchPreferences)
      verified = $verified
      supportedEfforts = $supportedEfforts
      evidence = $evidence
      verificationPath = $verificationPath
    }
  }

  $modelOutput = [ordered]@{
    schemaVersion = 1
    checkedAt = [DateTimeOffset]::UtcNow.ToString("o")
    policy = "requiresProbe profiles are eligible for automatic routing only when verified is true; unverifiable stays manual."
    sources = [ordered]@{
      codexConfig = $(if (Test-Path $codexConfig) { $codexConfig } else { $null })
      kimiConfig = $(if (Test-Path $kimiConfig) { $kimiConfig } else { $null })
      grokModelsRead = [bool]$grokModels
      antigravityHelpRead = [bool]$agyHelp
    }
    profiles = $profileRows
  }
  $modelTarget = Join-Path $targetDir "model-capabilities.json"
  Write-JsonFile $modelTarget $modelOutput
  $output["modelCapabilitiesPath"] = $modelTarget
}

$output["warnings"] = $warnings
Write-JsonFile $target $output
$output | ConvertTo-Json -Depth 30
