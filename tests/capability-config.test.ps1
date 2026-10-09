#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'scripts/requirements-lib.ps1')
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('capability-config-' + [guid]::NewGuid().ToString('N'))
try {
  [void][IO.Directory]::CreateDirectory($temporary)
  Copy-Item (Join-Path $root 'templates/project-config.example.json') (Join-Path $temporary 'project-config.json')
  $environment = @{ OPENAI_API_KEY = 'synthetic-key' }
  $resolution = Resolve-RequirementAvailability -ProjectRoot $temporary -RoleId media-producer -SkillIds image-generation -ConfigPath project-config.json -ProcessEnvironment $environment
  if ($resolution.Missing.Count) { throw "Unexpected missing requirements: $($resolution.Missing -join ', ')" }
  $child = Get-ChildRequirementEnvironment $resolution
  if ($child['CAPABILITY_ONLINE_PROVIDERS_ENABLED'] -cne 'false' -or $child['OPENAI_IMAGE_MODEL'] -cne 'gpt-image-1.5') { throw 'Config did not reach selected child environment' }
  if ($environment.ContainsKey('OPENAI_IMAGE_MODEL')) { throw 'Parent environment was mutated' }
  $unselected = Resolve-RequirementAvailability -ProjectRoot $temporary -RoleId media-producer -SkillIds web-assets -ConfigPath project-config.json -ProcessEnvironment @{}
  $local = Get-ChildRequirementEnvironment $unselected
  if ($local.ContainsKey('OPENAI_IMAGE_MODEL') -or $local.ContainsKey('CAPABILITY_ONLINE_PROVIDERS_ENABLED') -or $unselected.Missing.Count) { throw 'Unselected provider requirements leaked into local task' }
  $all = Resolve-RequirementAvailability -ProjectRoot $temporary -RoleId media-producer -SkillIds @('image-generation', 'generated-video', 'speech-production', 'audio-transcription') -ConfigPath project-config.json -ProcessEnvironment @{ OPENAI_API_KEY = 'synthetic-key'; PEXO_API_KEY = 'synthetic-key'; ELEVENLABS_API_KEY = 'synthetic-key' }
  if ($all.Missing.Count) { throw 'Combined provider requirements conflict' }
  Write-Output 'PASS capability config selection and child injection; synthetic values only'
} finally {
  Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
}
