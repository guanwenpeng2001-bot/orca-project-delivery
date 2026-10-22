function Assert-Condition([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Invoke-Check([string]$CheckName, [scriptblock]$Check) {
  try {
    & $Check
    $script:passed++
    Write-Host "PASS $CheckName"
  } catch {
    $script:failed++
    Write-Host "FAIL ${CheckName}: $($_.Exception.Message)"
  }
}

function Read-PackageJson([string]$RelativePath) {
  Get-Content -LiteralPath (Join-Path $script:root $RelativePath) -Raw | ConvertFrom-Json -AsHashtable
}

function Assert-Rejected([string]$Name, [scriptblock]$Action, [string]$Diagnostic) {
  $caught = $null
  try { & $Action } catch { $caught = $_.Exception.Message }
  Assert-Condition ($null -ne $caught -and $caught.Contains($Diagnostic)) "Negative case $Name did not produce $Diagnostic (actual: $caught)"
  Write-Host "REJECTED $Name : $caught"
}
function Assert-AbsentPaths([string]$Directory, [string[]]$Paths) {
  foreach ($relative in $Paths) {
    Assert-Condition (-not (Test-Path -LiteralPath (Join-Path $Directory $relative))) "forbidden path: $relative"
  }
}

function Resolve-SkillFile([string]$BundledPath) {
  if (Test-Path -LiteralPath $BundledPath -PathType Leaf) { return [pscustomobject]@{ Path = $BundledPath; Origin = 'package-bundled' } }
  throw "skill file missing: $BundledPath"
}

function Get-PackageFiles([string]$Directory) {
  foreach ($entry in Get-ChildItem -LiteralPath $Directory -Force) {
    if ($entry.Name -in @('.git', '.dev-work', '.claude')) { continue }
    Assert-Condition (-not ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)) "Unsupported linked package entry: $($entry.FullName)"
    if ($entry.PSIsContainer) { Get-PackageFiles $entry.FullName } else { $entry }
  }
}

function Invoke-Child {
  param([string]$Executable, [string[]]$Arguments, [switch]$DirtyGit, [string]$InputText = '', [int]$TimeoutSeconds = 60)
  if (-not $PSBoundParameters.ContainsKey('TimeoutSeconds')) {
    $suiteTimeout = Get-Variable -Name SuiteTimeoutSeconds -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $suiteTimeout -and $suiteTimeout -gt 0) { $TimeoutSeconds = $suiteTimeout }
  }
  $start = [Diagnostics.ProcessStartInfo]::new()
  $start.FileName = $Executable
  $start.WorkingDirectory = $script:temporaryRoot
  $start.UseShellExecute = $false
  $start.CreateNoWindow = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  $start.RedirectStandardInput = $true
  foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
  # Isolate fixture Git from host repository/config injection; dirty cases add
  # the exact orphaned count only in the child, never in the harness process.
  foreach ($key in @($start.Environment.Keys)) {
    if ($key -like 'GIT_*' -or $key -like 'ORCA_*') { [void]$start.Environment.Remove($key) }
  }
  $start.Environment['GIT_CONFIG_NOSYSTEM'] = '1'
  $start.Environment['GIT_CONFIG_GLOBAL'] = (Join-Path $script:temporaryRoot 'empty-git-config')
  $start.Environment['GIT_TERMINAL_PROMPT'] = '0'
  if ($DirtyGit) { $start.Environment['GIT_CONFIG_COUNT'] = '2' }
  Write-Host ('COMMAND ' + $Executable + ' ' + (($Arguments | ForEach-Object { "'" + $_.Replace("'", "''") + "'" }) -join ' '))
  if ($DirtyGit) { Write-Host 'ENV GIT_CONFIG_COUNT=2; GIT_CONFIG_KEY_0 absent (child only)' }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $start
  try {
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.StandardInput.Write($InputText)
    $process.StandardInput.Close()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
      $process.Kill($true)
      $process.WaitForExit()
      throw "Child timed out after $TimeoutSeconds seconds: $Executable"
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    Write-Host "EXIT $($process.ExitCode)"
    if ($stdout.Trim()) { Write-Host $stdout.TrimEnd() }
    if ($stderr.Trim()) { Write-Host $stderr.TrimEnd() }
    return [pscustomobject]@{ ExitCode = $process.ExitCode; Stdout = $stdout; Stderr = $stderr }
  } finally { $process.Dispose() }
}

function Invoke-FixtureGit([string[]]$Arguments, [string]$InputText = '') {
  $result = Invoke-Child $script:git $Arguments -InputText $InputText
  Assert-Condition ($result.ExitCode -eq 0) "Fixture Git failed: $($result.Stderr)"
  return $result.Stdout.Trim()
}

function New-FixtureRepository([string]$Name, [switch]$Delivery) {
  $repository = Join-Path $script:temporaryRoot $Name
  Write-Host "TEMP repository: $repository"
  $branch = if ($Delivery) { 'main' } else { 'verification-control' }
  $null = Invoke-FixtureGit @('init', '--initial-branch', $branch, '--template=', $repository)
  # Plumbing avoids checkout, index changes, hooks, and user signing settings.
  $tree = Invoke-FixtureGit @('-C', $repository, 'hash-object', '-t', 'tree', '-w', '--stdin')
  $commit = Invoke-FixtureGit @('-C', $repository, '-c', 'user.name=Package Verification', '-c', 'user.email=verify@example.invalid', 'commit-tree', $tree, '-m', 'Temporary verification fixture')
  $null = Invoke-FixtureGit @('-C', $repository, 'update-ref', "refs/heads/$branch", $commit)
  if (-not $Delivery) { $null = Invoke-FixtureGit @('-C', $repository, 'update-ref', 'refs/heads/main', $commit) }
  return $repository
}

function New-FixtureCommit {
  param([string]$Worktree, [string]$FileName, [string]$Content, [string]$Message)
  [IO.File]::WriteAllText((Join-Path $Worktree $FileName), $Content, $utf8)
  $null = Invoke-FixtureGit @('-C', $Worktree, 'add', $FileName)
  $null = Invoke-FixtureGit @('-C', $Worktree, 'commit', '-m', $Message)
  return Invoke-FixtureGit @('-C', $Worktree, 'rev-parse', 'HEAD')
}

function Invoke-PackageScript([string]$Name, [string[]]$Arguments, [switch]$DirtyGit) {
  Invoke-Child $script:pwsh (@('-NoProfile', '-NonInteractive', '-File', (Join-Path $script:stagedPackage "scripts/$Name")) + $Arguments) -DirtyGit:$DirtyGit
}

function Assert-OkResult($Result) {
  Assert-Condition ($Result.ExitCode -eq 0) "Expected exit 0, got $($Result.ExitCode): $($Result.Stderr) $($Result.Stdout)"
  $document = $Result.Stdout | ConvertFrom-Json
  Assert-Condition ($document.ok -eq $true) "Expected ok:true: $($Result.Stdout)"
}

function Invoke-Suite([string]$Name, [scriptblock]$Suite) {
  $timer = [Diagnostics.Stopwatch]::StartNew()
  Write-Host "SUITE $Name"
  try { & $Suite }
  finally { Write-Host ("SUITE {0} duration={1:N2}s" -f $Name, $timer.Elapsed.TotalSeconds) }
}

function Resolve-SuiteSelection {
  param([string[]]$Requested = @(), [switch]$MetadataOnly)
  $canonicalSuites = @('package structure', 'package runtime', 'package contracts', 'project lifecycle')
  if ($null -eq $Requested) { $Requested = @() }
  if ($MetadataOnly -and (@($Requested).Count -gt 0)) { throw '-MetadataOnly cannot be combined with -Suites' }
  $selected = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $normalizedRequested = @()
  foreach ($element in @($Requested)) {
    foreach ($part in @($element -split ',')) {
      $trimmed = $part.Trim()
      $match = $canonicalSuites | Where-Object { $_ -ieq $trimmed } | Select-Object -First 1
      if (-not $match) { throw "Unknown suite '$part' (declared: $($canonicalSuites -join ', '))" }
      if ($normalizedRequested -cnotcontains $match) { $normalizedRequested += $match }
      [void]$selected.Add($match)
    }
  }
  $explicit = $normalizedRequested.Count -gt 0
  if ($explicit -and (@($normalizedRequested | Where-Object { $_ -ne 'package structure' }).Count -gt 0)) {
    [void]$selected.Add('package structure')
  }
  $running = if ($explicit) { @($canonicalSuites | Where-Object { $selected.Contains($_) }) } else { @($canonicalSuites) }
  [pscustomobject]@{ Requested = @($normalizedRequested); Running = $running; Explicit = $explicit }
}
