# Use installed external Skills

**English** | [简体中文](zh-CN/external-skills.md)

Version **3.0.0** supports explicitly configured, already-installed external Skills alongside the **46 bundled Skills, 16 Roles and 4 workflows**. Registration does not copy or rewrite the third-party files, change bundled catalogs, or increase package counts. Keep upstream notices and licenses with the original installation. For native package authoring, see [Extending](extending.md); for environment rules, see [Configuration precedence](../references/configuration-precedence.md).

## Register an installed file

Pass `-ConfigPath 'project-config.json'` explicitly to assembly and both requirement helpers, together with the execution host's `-ProjectRoot`. No filename is discovered automatically. The config file must be inside that root; its external Skill paths may be outside it.

```json
{
  "schemaVersion": 2,
  "env": {},
  "externalSkills": [
    {
      "id": "vendor-method",
      "path": "C:/Users/you/.agents/skills/vendor-method/SKILL.md",
      "version": "upstream-declared-1.0",
      "requires": { "cli": ["pwsh"] }
    },
    {
      "id": "project-method",
      "path": "third-party/project-method/SKILL.md"
    }
  ],
  "roleBindings": {
    "software-implementer": {
      "defaultSkills": ["test-driven-development", "vendor-method"],
      "optionalSkills": ["integration-verification", "project-method"]
    }
  }
}
```

Replace both paths with existing files before using this configuration. A fully qualified absolute path can point at a global installation outside `ProjectRoot`; a relative path resolves from the explicit `ProjectRoot`, never from the config directory or package directory. Provision relative files in each worktree that needs them. Absolute installations are machine-local and must also exist on the execution host.

- Config version 1 remains **env-only** and rejects `externalSkills`/`roleBindings`. Version 2 permits them, but still requires `env` (use `{}` when empty). See [the schema](../schemas/project-config.schema.json).
- Each registration requires `id` and `path`; optional fields are `name`, `description`, `version` and `requires`. Unknown fields are rejected. IDs match `^[a-z0-9][a-z0-9-]*$`, are case-sensitive and unique, and cannot collide with a bundled ID. The registration alias can differ from the upstream frontmatter `name`; no renaming of the source is needed. Distinct aliases can point at one file; there is no content-level deduplication.
- Every registration and binding is validated when the config is used, including unselected ones. Files must exist. Directories, `..` traversal segments, symlinks and reparse points are rejected. An installer using linked directories is not supported by this resolver; use an actual readable installed path without linked segments.
- There is no automatic installer, scanning, download, update, environment/path interpolation, frontmatter dependency parsing, or emulation of hooks and other host features. An external Skill is professional instruction under the Task and `AGENTS.md`, not new execution authority.

## Resolve Task selection

Use a complete [task-definition.json](../templates/task-definition.json). Assembly now validates the whole Task against [task-definition.schema.json](../schemas/task-definition.schema.json), including branch, artifacts and Orca fields; retain required fields even when their permitted value is `null`.

| Task selection | Assembly behavior |
| --- | --- |
| Entire `skills` property omitted; selected Role has a configured binding | `defaultSkills` becomes `skills.required`; `optionalSkills` becomes `skills.conditional` |
| Entire `skills` property omitted; no binding for that Role (including no config or v1 config) | Rejects before writing the brief; native Role defaults are not inferred |
| `"skills": {"required": ["project-method"], "conditional": []}` | These explicit arrays override the binding; they are not merged with it |
| `"skills": {"required": [], "conditional": []}` | Valid explicit empty selection, including with no binding |
| `skills: null`, `{}`, wrong types, missing array, extra member inside `skills` | Schema rejection before writing the brief |

Each binding requires **both** `defaultSkills` and `optionalSkills` arrays and names an existing bundled Role. Both arrays may mix bundled and registered external IDs. When that Role has a binding, the embedded Role YAML and Skill-list text reflect the **effective Task selection**, even for explicit overrides; empty lists render `[]` in YAML and `None` in text. JSON `roleBinding` separately reports the configured binding, while JSON `skills` reports the resolved selection. Original Role files stay unchanged. With no binding the legacy Role body is retained, and the Required/Conditional Skills section identifies the explicit Task selection.

Legacy top-level extension fields remain accepted. Only the known `skillz` typo is explicitly rejected; do not rely on arbitrary typo detection (`skils`, for example, remains a legacy extension).

## Declare and check dependencies

Put external requirements in the registration's `requires`, using the same [requirements schema](../schemas/requirements.schema.json) as bundled entries: CLI names, env declarations (`name`, `secret`, `purpose`), and API declarations (`name`, `authEnv`, `purpose`). Every API `authEnv` must be declared by that entry. Requirements cannot be inferred from arbitrary prose. No install commands, hooks, endpoints or secret values belong in these declarations.

Only declared non-secret env values may go in config `env`, including names declared by registered external Skills. Secrets use the execution environment or deliberately provisioned local `.env`. Process values, including empty overrides, beat project `.env`, which beats explicit config. Empty values do not fall through. Conflicting declarations fail; API checks check presence only and report `networkVerified: false`. Missing requirements report named `cli:`, `env:` and `api:` entries and prevent child launch.

**Requirement helpers never infer Role bindings or defaults.** Read assembly's JSON `skills.required`, add only activated `skills.conditional` selectors, and pass that array explicitly to both helpers with the same `ProjectRoot` and `ConfigPath`. Run array examples inside PowerShell 7, not as a native `pwsh -File ... -Skills ...` multi-array command. The child's working directory is `ProjectRoot`; selected declared file values are added over its inherited environment, the parent remains unchanged, and child exit codes are forwarded. Child output is not redacted.

## Deliver instructions and resolve resources

`explicit-path` references the original absolute `SKILL.md` and requires the worker to read it. `inline-extract` embeds a snapshot of required Skill bodies, demotes headings and fences leading frontmatter as data; conditional Skills remain path references in both modes. A later source edit does not update an inline snapshot. Neither mode guarantees that an arbitrary host loads or trusts a Skill or implements its upstream host-specific features.

Assembly and checker JSON expose `skillProvenance` only for selected external entries; bundled-only output does not acquire that field. Each record contains `id`, `origin: "project-external"`, resolved absolute `path`, original `declaredPath`, `configPath` exactly as supplied to `-ConfigPath` (possibly relative), absolute original `resourceBase`, observed lowercase `sha256`, and `declaredVersion` (null when absent). A declared version is not verified; a hash identifies entry-file content, not approval or all sibling resources. Assembly also includes provenance in the brief.

In **both delivery modes**, resolve a Skill's relative scripts and resources from its original `resourceBase`, not from the worker's current directory, the package, or the brief. Invocation does not automatically find or run such scripts: the Task must authorize the executable and the resource path. The recipe below joins `resourceBase` with `resources/probe.ps1` explicitly.

## Offline walkthrough

Run this single block from the package root in PowerShell 7 with Node available for the documentation test. It creates a synthetic installed Skill outside a separate temporary project, plus a project-relative Skill. These are fixtures, not a download or a change to an existing installation. It assembles both delivery modes, preflights the resolved selectors and runs the original sibling script; then verifies source hashes and a named dependency failure. It makes no provider call and reads no real credentials. Only the unique temporary fixture directory is removed at the end.

```powershell
$ErrorActionPreference = 'Stop'
$package = (Get-Location).Path
$demo = Join-Path ([IO.Path]::GetTempPath()) ('orca-installed-demo-' + [guid]::NewGuid().ToString('N'))
$project = Join-Path $demo 'project'
$installed = Join-Path $demo 'installed-method'
New-Item -ItemType Directory -Path "$installed/resources", "$project/third-party/project-method" -Force | Out-Null
try {
  if (Test-Path Env:ORCA_EXTERNAL_DEMO_MODE) { throw 'Use a session without ORCA_EXTERNAL_DEMO_MODE' }
  @'
---
name: upstream-method-name
---
# Installed method
Run resources/probe.ps1 relative to this Skill directory when the Task authorizes it.
'@ | Set-Content -LiteralPath "$installed/SKILL.md" -Encoding utf8
  @'
if ($env:ORCA_EXTERNAL_DEMO_MODE -ne 'offline') { exit 81 }
if ((Get-Content -LiteralPath "$PSScriptRoot/sibling.txt" -Raw).Trim() -ne 'sibling-resource') { exit 82 }
if ((Get-Location).Path -eq $PSScriptRoot) { exit 83 }
Write-Output 'External sibling resource passed.'
exit 37
'@ | Set-Content -LiteralPath "$installed/resources/probe.ps1" -Encoding utf8
  'sibling-resource' | Set-Content -LiteralPath "$installed/resources/sibling.txt" -Encoding utf8
  '# Project method' | Set-Content -LiteralPath "$project/third-party/project-method/SKILL.md" -Encoding utf8
  '# Demo rules: execute only the authorized offline sibling probe.' | Set-Content -LiteralPath "$project/AGENTS.md" -Encoding utf8
  $sourcePaths = @("$installed/SKILL.md", "$installed/resources/probe.ps1", "$installed/resources/sibling.txt", "$project/third-party/project-method/SKILL.md")
  $before = @($sourcePaths | ForEach-Object { (Get-FileHash -LiteralPath $_).Hash })
  $config = @{
    schemaVersion = 2
    env = @{ ORCA_EXTERNAL_DEMO_MODE = 'offline' }
    externalSkills = @(
      @{ id = 'vendor-method'; path = "$installed/SKILL.md"; version = 'declared-demo'; requires = @{
        cli = @('pwsh'); env = @(@{ name = 'ORCA_EXTERNAL_DEMO_MODE'; secret = $false; purpose = 'Offline demo mode' })
      } },
      @{ id = 'project-method'; path = 'third-party/project-method/SKILL.md' }
    )
    roleBindings = @{ 'software-implementer' = @{
      defaultSkills = @('test-driven-development', 'vendor-method', 'project-method')
      optionalSkills = @('integration-verification')
    } }
  }
  $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath "$project/project-config.json" -Encoding utf8
  $task = Get-Content -LiteralPath "$package/templates/task-definition.json" -Raw | ConvertFrom-Json
  $task.taskKey = 'installed-demo'
  $task.title = 'Verify an installed method'
  $task.objective = 'Run the authorized local sibling probe without changing installed sources.'
  $task.role = 'software-implementer'
  $task.branch.worktree = $project
  $task.artifacts.reportPath = "$project/result.md"
  $task.artifacts.evidencePath = "$project/evidence.json"
  $task.PSObject.Properties.Remove('skills')
  foreach ($mode in @('explicit-path', 'inline-extract')) {
    $task.skillDeliveryMode = $mode
    $task | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath "$project/task.json" -Encoding utf8
    $assembled = & "$package/scripts/assemble-task.ps1" -ProjectRoot $project -TaskDefinitionPath "$project/task.json" -OutputPath "$project/$mode.md" -ConfigPath 'project-config.json' | ConvertFrom-Json
    if (-not $assembled.ok) { throw 'Assembly failed' }
    $selectedSkills = @($assembled.skills.required)
    if (($selectedSkills -join ',') -ne 'test-driven-development,vendor-method,project-method') { throw 'Unexpected selection' }
    $checked = & "$package/scripts/check-requirements.ps1" -ProjectRoot $project -Role $task.role -Skills $selectedSkills -ConfigPath 'project-config.json' | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or -not $checked.ok) { throw 'Preflight failed' }
    $origin = $assembled.skillProvenance | Where-Object id -eq 'vendor-method'
    if ($origin.configPath -ne 'project-config.json' -or $origin.declaredVersion -ne 'declared-demo') { throw 'Unexpected provenance' }
    if ($origin.sha256 -cne (Get-FileHash -LiteralPath "$installed/SKILL.md").Hash.ToLowerInvariant()) { throw 'Entry hash differs' }
    $resource = Join-Path $origin.resourceBase 'resources/probe.ps1'
    $executable = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
    & "$package/scripts/invoke-with-requirements.ps1" -ProjectRoot $project -Role $task.role -Skills $selectedSkills -ConfigPath 'project-config.json' -Executable $executable -Arguments @('-NoProfile', '-File', $resource)
    if ($LASTEXITCODE -ne 37) { throw 'Child exit was not forwarded' }
  }
  if (Test-Path Env:ORCA_EXTERNAL_DEMO_MODE) { throw 'Parent environment changed' }
  $after = @($sourcePaths | ForEach-Object { (Get-FileHash -LiteralPath $_).Hash })
  if (Compare-Object $before $after) { throw 'Installed source changed' }
  $config.externalSkills[0].requires.cli = @('orca-external-demo-missing-command')
  $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath "$project/project-config.json" -Encoding utf8
  $missing = & "$package/scripts/check-requirements.ps1" -ProjectRoot $project -Role $task.role -Skills $selectedSkills -ConfigPath 'project-config.json' | ConvertFrom-Json
  if ($LASTEXITCODE -ne 1 -or $missing.missing -notcontains 'cli:orca-external-demo-missing-command') { throw 'Missing CLI was not named' }
  Write-Output 'External Skill walkthrough passed: both delivery modes, original resources, unchanged sources, named failure.'
} finally {
  Remove-Item -LiteralPath $demo -Recurse -Force
}
```

Expected: two `External sibling resource passed.` messages and the final walkthrough success sentence. The internal child status **37** is expected; the final missing-CLI check returns **1** intentionally. The Node documentation test captures those outcomes inside a successful driver. Non-Windows execution and real host loading/effectiveness remain unverified. Review the assembled brief and actual worker reading/application evidence separately before claiming a real Task used the method.
