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

$warnings = @()

function Write-JsonFile {
  param([string]$Path, [object]$Value)
  $json = $Value | ConvertTo-Json -Depth 30
  [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

# Run a CLI, capture merged output, and never hang: stdout/stderr are drained concurrently with
# the wait (a CLI that writes more than the OS pipe buffer would otherwise look like a timeout),
# the child is killed on timeout, and stdOut/stdErr stay separable for health decisions.
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
    $p = [System.Diagnostics.Process]::new()
    $p.StartInfo = $psi
    if (-not $p.Start()) {
      return @{ ok = $false; timedOut = $false; exitCode = $null; output = $null; stdOut = $null; stdErr = $null; reason = "process could not be started" }
    }
    $stdOutTask = $p.StandardOutput.ReadToEndAsync()
    $stdErrTask = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($TimeoutMs)) {
      try { $p.Kill($true) } catch { }
      try { $p.WaitForExit(2000) | Out-Null } catch { }
      try { $stdOutTask.Wait(2000) | Out-Null } catch { }
      try { $stdErrTask.Wait(2000) | Out-Null } catch { }
      return @{ ok = $false; timedOut = $true; exitCode = $null; output = $null; stdOut = $null; stdErr = $null; reason = "timed out after ${TimeoutMs}ms" }
    }
    $stdOut = $stdOutTask.GetAwaiter().GetResult()
    $stdErr = $stdErrTask.GetAwaiter().GetResult()
    $text = ($stdOut + $stdErr).Trim()
    return @{ ok = ($p.ExitCode -eq 0); timedOut = $false; exitCode = $p.ExitCode; output = $text; stdOut = $stdOut.Trim(); stdErr = $stdErr.Trim(); reason = $null }
  } catch {
    return @{ ok = $false; timedOut = $false; exitCode = $null; output = $null; stdOut = $null; stdErr = $null; reason = $_.Exception.Message }
  }
}

# A CLI counts as usable only when `--version` really produced a version on stdout: exit code
# alone is not enough, because a broken shim (observed: opencode.ps1) exits 0 while writing a
# PowerShell ResourceUnavailable error to stderr.
function Get-CliVersion {
  param([string]$ExePath, [int]$TimeoutMs = 8000)
  if (-not $ExePath) { return @{ ok = $false; version = $null; reason = "no executable path" } }
  $result = Invoke-CliCaptured -ExePath $ExePath -Arguments "--version" -TimeoutMs $TimeoutMs
  if ($result.timedOut) { return @{ ok = $false; version = $null; reason = "version probe timed out after ${TimeoutMs}ms" } }
  if ($result.exitCode -ne 0) {
    $detail = $result.reason
    if (-not $detail) { $detail = [string](($result.output -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 1)) }
    return @{ ok = $false; version = $null; reason = "version probe failed (exit $($result.exitCode)): $detail" }
  }
  $version = [string](($result.stdOut -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 1))
  if (-not $version) {
    $detail = [string](($result.stdErr -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 1))
    if (-not $detail) { $detail = "no output on stdout or stderr" }
    return @{ ok = $false; version = $null; reason = "no version on stdout: $detail" }
  }
  return @{ ok = $true; version = $version; reason = $null }
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

# Extract an explicitly advertised effort list (e.g. `[possible values: low, medium, high]`) that
# belongs to an effort flag. Only an explicit enumeration counts: a bare `<EFFORT>` placeholder
# must never be read as "this CLI advertises its effort values".
function Get-AdvertisedEffortValues {
  param([string]$HelpText, [int]$Window = 4)
  if (-not $HelpText) { return @() }
  $lines = @($HelpText -split "`r?`n")
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -notmatch '(^|\s)--?(reasoning-)?effort\b') { continue }
    $end = [Math]::Min($i + $Window, $lines.Count - 1)
    for ($j = $i; $j -le $end; $j++) {
      if ($lines[$j] -match '\[possible values:\s*(?<list>[^\]]+)\]') {
        return @($Matches.list -split ',' | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ })
      }
    }
  }
  return @()
}

# Parse model ids out of a `models` listing. The `agy models` shape is "<id>\t<display name>";
# a bare token, a "Default model: <id>" line and an "* <id> (default)" bullet are also accepted.
# Prose lines such as "Fetching available models..." are ignored, so they cannot be mistaken
# for a listed model.
function Test-OrcaModelOption {
  # Orca validates the (agent, model, effort) combination against its own per-model option catalog
  # before it places anything. Pointing the request at a repo id that cannot exist keeps a valid
  # combination from launching, so the reply separates "Orca accepts this combination" from
  # "Orca rejects it" without starting a worker.
  param([string]$Agent, [string]$Model, [string]$Effort)
  $orcaCommand = Get-Command orca -ErrorAction SilentlyContinue
  if (-not $orcaCommand) { return 'unknown' }
  $sentinelRepo = "id:00000000-0000-0000-0000-000000000000"
  $cliArgs = @('orchestration', 'worker-start', '--spec', 'option probe', '--worktree', 'new-top-level',
    '--repo', $sentinelRepo, '--base-branch', 'main', '--setup', 'skip', '--name', 'orca-option-probe',
    '--agent', $Agent, '--model', $Model)
  if ($Effort) { $cliArgs += @('--effort', $Effort) }
  $cliArgs += @('--timeout-ms', '15000', '--json')
  $probeOutput = & $orcaCommand.Source @cliArgs 2>&1 | Out-String
  try { $parsed = $probeOutput | ConvertFrom-Json } catch { return 'unknown' }
  if ($null -eq $parsed) { return 'unknown' }
  if ($parsed.ok) { return 'launched' }
  $message = [string]$parsed.error.message
  if ($message -match 'does not support') { return 'rejected' }
  return 'accepted'
}
function Get-ListedModelIds {
  param([string]$Listing)
  if (-not $Listing) { return @() }
  $ids = @()
  foreach ($line in ($Listing -split "`r?`n")) {
    if ($line -notmatch '\S') { continue }
    if ($line -match '(?i)^\s*(?:default|current)\s+model\s*[:=]\s*(?<id>\S+)') {
      $ids += $Matches.id.Trim('"')
      continue
    }
    if ($line -match '^\s*(?:[\*\-]\s*)?(?<id>[A-Za-z0-9][A-Za-z0-9._/:\-]*)(?:\t|\s{2,}|\s+\(|$)') {
      $ids += $Matches.id
    }
  }
  return @($ids | Where-Object { $_ -notmatch '^(Fetching|Loading|Reading|Resolving|Downloading|Available|Models)$' } | Select-Object -Unique)
}

$root = (Resolve-Path $ProjectRoot).Path
try {
  $gitRoot = Invoke-Git -Root $root -Arguments @("rev-parse", "--show-toplevel")
} catch {
  throw "Not inside a Git worktree. git said: $($_.Exception.Message)"
}
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

# Portable home resolution: $env:USERPROFILE is Windows-only and is unset elsewhere, while the
# script already models a non-Windows runtime. On Windows the first branch keeps today's value.
$userProfile = $env:USERPROFILE
if (-not $userProfile) { $userProfile = $HOME }
if (-not $userProfile) { $userProfile = [Environment]::GetFolderPath("UserProfile") }

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
  $probeFailure = $null
  if ($detected) {
    $versionProbe = Get-CliVersion -ExePath $found.Source -TimeoutMs $VersionTimeoutMs
    if ($versionProbe.ok) {
      $version = $versionProbe.version
    } else {
      # Present but broken: not usable, so it is reported as not detected.
      $probeFailure = $versionProbe.reason
      $detected = $false
    }
  }

  $notes = @($agent.notes)
  if ($unsupported) { $notes += "Unsupported on runtime $runtime." }
  if ($missingRequired.Count -gt 0) { $notes += "Missing required commands: $($missingRequired -join ', ')." }
  if ($probeFailure) {
    $notes += "CLI found at $($found.Source) but not usable: $probeFailure"
    $script:warnings += "CLI '$($agent.id)' is present at $($found.Source) but did not run: $probeFailure"
  }

  $rows += [ordered]@{
    id = $agent.id
    displayName = $agent.displayName
    detected = $detected
    runtimeSupported = (-not $unsupported)
    command = $(if ($detected) { $found.Source } else { $null })
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

  $codexConfig = Join-Path $userProfile ".codex\config.toml"
  $codexModel = Read-TomlScalar -Path $codexConfig -Key "model"
  $codexEffort = Read-TomlScalar -Path $codexConfig -Key "model_reasoning_effort"
  $codexEfforts = Read-TomlArray -Path $codexConfig -Key "enabled-reasoning-efforts"

  $kimiConfig = Join-Path $userProfile ".kimi-code\config.toml"
  $kimiDefault = Read-TomlScalar -Path $kimiConfig -Key "default_model"
  $kimiModels = Get-KimiModelTable -Path $kimiConfig

  # grok: the model listing is host evidence, but `grok --help` only shows an `<EFFORT>`
  # placeholder, so the effort can only be verified from a launch receipt.
  $grokRow = $detectedById["grok"]
  $grokModels = $null
  $grokHelp = $null
  if ($grokRow -and $grokRow.detected) {
    $grokResult = Invoke-CliCaptured -ExePath $grokRow.command -Arguments "models" -TimeoutMs $CommandTimeoutMs
    if ($grokResult.ok -and $grokResult.output) { $grokModels = $grokResult.output }
    $grokHelpResult = Invoke-CliCaptured -ExePath $grokRow.command -Arguments "--help" -TimeoutMs $CommandTimeoutMs
    if ($grokHelpResult.ok -and $grokHelpResult.output) { $grokHelp = $grokHelpResult.output }
    if (-not $grokModels) {
      $grokFailure = $(if ($grokResult.reason) { $grokResult.reason } else { "no output" })
      $script:warnings += "grok: 'grok models' could not be read ($grokFailure); model evidence stays unverified."
    }
  }
  $grokEfforts = @(Get-AdvertisedEffortValues -HelpText $grokHelp)

  # antigravity: `agy models` does list models on this host, and `agy --help` advertises effort values.
  $agyRow = $detectedById["antigravity"]
  $agyHelp = $null
  $agyModelListing = $null
  if ($agyRow -and $agyRow.detected) {
    $agyResult = Invoke-CliCaptured -ExePath $agyRow.command -Arguments "--help" -TimeoutMs $CommandTimeoutMs
    if ($agyResult.output) { $agyHelp = $agyResult.output }
    $agyModelsResult = Invoke-CliCaptured -ExePath $agyRow.command -Arguments "models" -TimeoutMs $CommandTimeoutMs
    if ($agyModelsResult.ok -and $agyModelsResult.output) { $agyModelListing = $agyModelsResult.output }
    if (-not $agyModelListing) {
      $agyFailure = $(if ($agyModelsResult.reason) { $agyModelsResult.reason } else { "no output" })
      $script:warnings += "antigravity: 'agy models' could not be read ($agyFailure); model existence stays unverified."
    }
  }
  $agyEfforts = @()
  if ($agyHelp -and $agyHelp -match 'effort[^\r\n]*\((?<list>[a-z\|]+)\)') {
    $agyEfforts = @($Matches.list -split '\|' | Where-Object { $_ })
  }
  $agyModelIds = @(Get-ListedModelIds -Listing $agyModelListing)

  # claude: the declared model is an alias the CLI accepts and forwards to the host-managed
  # backend. This probe verifies the CLI contract only - the flags exist and the declared effort
  # is in the value set the CLI itself enumerates. The alias-to-backend mapping is host
  # configuration and is deliberately not probed here.
  $claudeRow = $detectedById["claude"]
  $claudeHelp = $null
  $claudeEffortProbe = $null
  if ($claudeRow -and $claudeRow.detected) {
    $claudeHelpResult = Invoke-CliCaptured -ExePath $claudeRow.command -Arguments "--help" -TimeoutMs $CommandTimeoutMs
    if ($claudeHelpResult.output) { $claudeHelp = $claudeHelpResult.output }
    # An unknown value makes the CLI print its accepted set without contacting any backend.
    $claudeEffortResult = Invoke-CliCaptured -ExePath $claudeRow.command -Arguments "--effort __probe__ --help" -TimeoutMs $CommandTimeoutMs
    if ($claudeEffortResult.output) { $claudeEffortProbe = $claudeEffortResult.output }
  }
  $claudeEfforts = @()
  if ($claudeEffortProbe -and $claudeEffortProbe -match 'Valid values:\s*(?<list>[a-z,\s]+)') {
    $claudeEfforts = @($Matches.list -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  }

  $profileRows = @()
  foreach ($profile in $profiles.profiles) {
    $row = $detectedById[$profile.agent]
    $evidence = @()
    $supportedEfforts = @()
    $verified = $false
    $verificationPath = $null
    # A profile is verified only when BOTH the model and the effort have positive host evidence.
    $modelEvidence = $false
    $effortEvidence = $false

    switch ($profile.agent) {
      "codex" {
        if (Test-Path $codexConfig) { $evidence += "config: $codexConfig" }
        if ($codexModel) { $evidence += "config model='$codexModel' effort='$codexEffort'" }
        $supportedEfforts = $codexEfforts
        $modelEvidence = [bool]($codexModel -and ($profile.model -eq $codexModel))
        $effortEvidence = [bool]($profile.effort -and ($profile.effort -in $codexEfforts))
        $verificationPath = "config.toml + worker-start receipt (launch.requested vs launch.effective)"
      }
      "kimi" {
        if (Test-Path $kimiConfig) { $evidence += "config: $kimiConfig" }
        if ($kimiDefault) { $evidence += "default_model='$kimiDefault'" }
        if ($kimiModels.ContainsKey($profile.model)) {
          $supportedEfforts = @($kimiModels[$profile.model].supportEfforts)
          $evidence += "support_efforts=[$($supportedEfforts -join ', ')] default_effort='$($kimiModels[$profile.model].defaultEffort)'"
          $modelEvidence = $true
          $effortEvidence = [bool]((-not $profile.effort) -or ($profile.effort -in $supportedEfforts))
        } else {
          $evidence += "model table '$($profile.model)' not found in config.toml"
        }
        $verificationPath = "config.toml [models." + $profile.model + "] + in-session model/effort surface (session-command mode)"
      }
      "grok" {
        if ($grokModels) {
          $evidence += "grok models: $((@($grokModels -split "`r?`n" | Where-Object { $_ -match '\S' }) | Select-Object -First 3) -join ' / ')"
          $modelEvidence = [bool](
            $grokModels -match ("(?m)^\s*[\*\-]\s*" + [regex]::Escape($profile.model) + "(?![\w.\-])") -or
            $grokModels -match ("Default model:\s*" + [regex]::Escape($profile.model) + "(?![\w.\-])"))
          if ($modelEvidence) {
            $evidence += "model '$($profile.model)' is listed by 'grok models' (model-name evidence only; a model listing cannot verify effort)"
          } else {
            $evidence += "model '$($profile.model)' is not listed by 'grok models'"
          }
        } else {
          $evidence += "grok models could not be read"
        }
        $supportedEfforts = $grokEfforts
        $effortEvidence = [bool](($grokEfforts.Count -gt 0) -and $profile.effort -and ($profile.effort -in $grokEfforts))
        if (-not $grokHelp) {
          $evidence += "grok --help could not be read, so effort '$($profile.effort)' cannot be verified from the CLI"
        } elseif ($grokEfforts.Count -gt 0) {
          $evidence += "grok --help advertises effort values=[$($grokEfforts -join ', ')]"
        } else {
          $evidence += "effort values are not advertised: grok --help shows --reasoning-effort/--effort but no accepted values, so effort '$($profile.effort)' is unverifiable here"
        }
        $verificationPath = "worker-start launch receipt (launch.requested vs launch.effective)"
      }
      "antigravity" {
        if ($agyHelp) {
          $evidence += "agy --help advertises --model and --effort"
          $supportedEfforts = $agyEfforts
          if ($agyEfforts.Count -gt 0) { $evidence += "effort choices=[$($agyEfforts -join ', ')]" }
        } else {
          $evidence += "agy --help could not be read"
        }
        if ($agyModelIds.Count -gt 0) {
          $evidence += "agy models lists $($agyModelIds.Count) models"
          if ($agyModelIds -contains $profile.model) {
            $modelEvidence = $true
            $evidence += "model '$($profile.model)' is listed by 'agy models'"
          } else {
            $related = @($agyModelIds | Where-Object { $_ -like "$($profile.model)*" })
            if ($related.Count -gt 0) {
              $evidence += "model '$($profile.model)' is NOT listed by 'agy models'; closest listed ids: $($related -join ', ')"
            } else {
              $evidence += "model '$($profile.model)' is NOT listed by 'agy models'; listed ids: $(@($agyModelIds | Select-Object -First 12) -join ', ')"
            }
          }
        } elseif ($agyModelListing) {
          $evidence += "agy models produced no parseable model ids"
        } else {
          $evidence += "agy models could not be read"
        }
        $effortEvidence = [bool]($profile.effort -and ($agyEfforts -contains $profile.effort))
        if ($agyEfforts.Count -gt 0) {
          if ($effortEvidence) {
            $evidence += "effort '$($profile.effort)' is advertised by agy --help"
          } else {
            $evidence += "effort '$($profile.effort)' is NOT advertised by agy --help"
          }
        }
        $verificationPath = "agy models + agy --help"
      }
      "claude" {
        if ($claudeHelp) {
          $hasModelFlag = [bool]($claudeHelp -match '--model')
          $hasEffortFlag = [bool]($claudeHelp -match '--effort')
          $evidence += "claude --help advertises --model flag=$hasModelFlag --effort flag=$hasEffortFlag"
          $modelEvidence = $hasModelFlag
          if (-not $hasEffortFlag) { $evidence += "claude --help does not advertise --effort" }
        } else {
          $evidence += "claude --help could not be read"
        }
        $supportedEfforts = $claudeEfforts
        if ($claudeEfforts.Count -gt 0) {
          $evidence += "claude --effort enumerates [$($claudeEfforts -join ', ')]"
          $effortEvidence = [bool]((-not $profile.effort) -or ($profile.effort -in $claudeEfforts))
          if (-not $effortEvidence) { $evidence += "effort '$($profile.effort)' is NOT enumerated by claude --effort" }
        }
        $evidence += "model alias '$($profile.model)' is forwarded to the host-managed backend; the alias mapping is not probed here"
        $verificationPath = "claude CLI contract (--model alias + --effort enumeration)"
      }
      default {
        $evidence += "No host-side model probe implemented for agent '$($profile.agent)'."
        $verificationPath = "worker-start receipt (launch.requested vs launch.effective)"
      }
    }

    # Orca's per-model option catalog is stricter than the CLI contract: it can reject a
    # (model, effort) pair the CLI would accept silently. Only profiles whose model control is
    # orca-launch-preferences are dispatched with these flags, so only those are checked.
    $orcaOptionVerdict = 'not-applicable'
    if ($profile.modelControl -eq 'orca-launch-preferences') {
      $orcaOptionVerdict = Test-OrcaModelOption -Agent $profile.agent -Model $profile.model -Effort $profile.effort
      switch ($orcaOptionVerdict) {
        'rejected' {
          $effortEvidence = $false
          $evidence += "Orca rejects model='$($profile.model)' with effort='$($profile.effort)' (per-model option catalog)."
        }
        'accepted' {
          $evidence += "Orca accepts model='$($profile.model)' with effort='$($profile.effort)' (sentinel repo; nothing launched)."
        }
        'launched' {
          $modelEvidence = $false
          $effortEvidence = $false
          $evidence += "Orca option probe unexpectedly launched a worker; this profile is treated as unverified."
        }
        default {
          $evidence += "Orca option validation unavailable, so the model/effort combination is not confirmed by Orca."
        }
      }
    } else {
      $evidence += "Orca launch options do not apply (modelControl='$($profile.modelControl)')."
    }

    $verified = [bool]($modelEvidence -and $effortEvidence)
    if (-not $verified) {
      $missing = @()
      if (-not $modelEvidence) { $missing += "model" }
      if (-not $effortEvidence) { $missing += "effort" }
      $evidence += "verified=false: no positive $($missing -join ' + ') evidence on this host."
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
      modelEvidence = $modelEvidence
      effortEvidence = $effortEvidence
      orcaOptionVerdict = $orcaOptionVerdict
      supportedEfforts = $supportedEfforts
      evidence = $evidence
      verificationPath = $verificationPath
    }
  }

  $modelOutput = [ordered]@{
    schemaVersion = 1
    checkedAt = [DateTimeOffset]::UtcNow.ToString("o")
    policy = "requiresProbe profiles are eligible for automatic routing only when verified is true; verified requires positive host evidence for BOTH model and effort, and anything unverifiable stays manual."
    sources = [ordered]@{
      codexConfig = $(if (Test-Path $codexConfig) { $codexConfig } else { $null })
      kimiConfig = $(if (Test-Path $kimiConfig) { $kimiConfig } else { $null })
      grokModelsRead = [bool]$grokModels
      grokHelpRead = [bool]$grokHelp
      antigravityHelpRead = [bool]$agyHelp
      antigravityModelsRead = [bool]$agyModelListing
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
