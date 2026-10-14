#requires -Version 7.0
# Shared helpers for coordinator project lifecycle scripts.
# The evidence validator intentionally owns its separate read-only Git policy.
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

function Write-JsonFile {
  param([string]$Path, [object]$Value, [int]$Depth = 20)
  $json = $Value | ConvertTo-Json -Depth $Depth
  [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

function Resolve-DeliveryBranch {
  param([string]$Root, [string]$CurrentBranch, [string]$DeliveryBranch)
  # Resolution sources: user | origin-head | init-default | main | master | current.
  $source = $null
  if ($DeliveryBranch) {
    $source = 'user'
  } else {
    # Missing refs intentionally exit nonzero. Capture the exit before any pipeline
    # can stop the native process early and overwrite LASTEXITCODE.
    $originHead = & git -C $Root symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>&1
    $originHeadExit = $LASTEXITCODE
    if ($originHeadExit -eq 0 -and $originHead) {
      $originHeadBranch = ("$originHead").Trim() -replace '^origin/', ''
      if ($originHeadBranch) { $DeliveryBranch = $originHeadBranch; $source = 'origin-head' }
    }
    if (-not $source) {
      $initDefault = & git -C $Root config --get init.defaultBranch 2>&1
      $initDefaultExit = $LASTEXITCODE
      if ($initDefaultExit -eq 0 -and $initDefault) {
        $initDefault = ("$initDefault").Trim()
        if ($initDefault) {
          $probe = & git -C $Root show-ref --verify --quiet "refs/heads/$initDefault" 2>&1
          if ($LASTEXITCODE -eq 0) { $DeliveryBranch = $initDefault; $source = 'init-default' }
        }
      }
    }
    if (-not $source) {
      foreach ($candidate in @('main', 'master')) {
        $probe = & git -C $Root show-ref --verify --quiet "refs/heads/$candidate" 2>&1
        if ($LASTEXITCODE -eq 0) { $DeliveryBranch = $candidate; $source = $candidate; break }
      }
    }
    if (-not $source) { $DeliveryBranch = $CurrentBranch; $source = 'current' }
  }
  return [pscustomobject]@{ Branch = $DeliveryBranch; Source = $source }
}
