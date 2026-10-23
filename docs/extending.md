# Extending Roles, Skills, and configuration

**English** | [简体中文](zh-CN/extending.md)

Use the [installed external Skill walkthrough](external-skills.md) for version 2 project registration, mixed bindings, resolved requirement selectors and original sibling resources. No separate installation is required for bundled Skills.

Extend the package's native catalogs when a reusable method or a distinct deliverable is missing. A **Role** defines identity, responsibility, authority boundaries, and outputs; a **Skill** supplies a method. Neither grants permission beyond the Task and applicable `AGENTS.md`. Orca still owns dispatch and lifecycle. Workers do not load the coordinator entry Skill or create their own `.dev-work/`.

- [Native registration](#native-registration)
- [Author a Skill](#author-a-skill)
- [Author a Role](#author-a-role)
- [Declare dependencies](#declare-dependencies)
- [Validate the extension](#validate-the-extension)
- [Select and deliver methods](#select-and-deliver-methods)
- [Configure the execution host](#configure-the-execution-host)
- [Run an offline example](#run-an-offline-example)
- [Diagnose failures](#diagnose-failures)

## Native registration

Work in a separate development checkout or a disposable copy, preserve existing entries, and save text as UTF-8 without BOM with LF line endings. The following `export-contract-check` Skill and `export-reviewer` Role are **illustrative additions**, not bundled production entries. The 3.1.0 package ships 69 Skills and 18 Roles; validation compares catalogs to the manifest rather than fixing those numbers forever.

| File | What to add or update |
| --- | --- |
| `skills/<id>/SKILL.md` | Self-contained method, decision criteria, example, failure signals, evaluation and evidence |
| `routing/skill-catalog.json` → `skills` | Skill ID, name, description, exact package-relative path, optional `requires` |
| `roles/<category>/<id>.md` | Role contract and matching front matter |
| `roles/catalog.json` → `roles` | ID, name, category, path, `defaultSkills`, `optionalSkills`, optional `requires` |
| `routing/model-routing.json` → `roles` | A chain, default index and floor index for every catalog Role |
| `routing/role-selection.json` → `deliverableRoutes` | A new deliverable mapping when needed |
| `routing/skill-selection.json` → `riskRoutes` | A new risk-to-method mapping only when relevant |
| `PACKAGE-MANIFEST.json` → `deliverables` | Counts matching the resulting Role and Skill catalogs; workflow count remains accurate |

IDs and Role categories match `^[a-z0-9][a-z0-9-]*$`; IDs must be unique within their catalog. Skill paths are exactly `skills/<id>/SKILL.md`; Role paths are exactly `roles/<category>/<id>.md`. Forward or backward separators are accepted, but aliases, traversal, external files, missing files and linked catalog paths are not. Role default/optional Skill arrays must exist and refer to registered IDs. These restrictions apply to native catalog entries. To use already-installed files without changing package content or counts, use [configured external Skills](external-skills.md); version 2 project config supplies explicit external registrations and mixed Role bindings, with no sibling fallback.

Start from [skill-authoring.md](../templates/skill-authoring.md) and [role-authoring.md](../templates/role-authoring.md). The following bodies show the finished contract; replace the templates' authoring instructions with useful content.

## Author a Skill

Create `skills/export-contract-check/SKILL.md`:

```markdown
---
name: export-contract-check
description: Compare a local export sample with its declared field and empty-result contract.
---

# Export Contract Check

## Method

Read the assigned export contract and local sample. List required fields and types, then compare every record. Distinguish a valid empty result from a missing file. Report mismatches by record and field without reproducing sensitive values.

## Worked example

For required fields id (string) and active (boolean), [{"id":"demo","active":"yes"}] fails because active is a string. An empty array passes only when the contract permits zero records.

## Failure signals

Missing fields, incorrect types, duplicate IDs, or an absent sample prevent a passing verdict. Preserve the sample and report the failing rule; do not repair source data.

## Evaluation scenario

Given one valid record, one wrong-type record, an empty array, and a missing file, classify all four against the contract and identify the evidence for each verdict.

## Completion

Return checks, observed results, and unverified items. This method grants no source-writing or orchestration authority.
```

Append this object to `routing/skill-catalog.json`'s existing `skills` array:

```json
{
  "id": "export-contract-check",
  "name": "Export Contract Check",
  "path": "skills/export-contract-check/SKILL.md",
  "description": "Compare local export samples with their declared contract."
}
```

Keep essential method content in `SKILL.md`: required Skills work with both path delivery and full-body inline delivery. The original sixteen bundled Skills are maintained MIT adaptations of their pinned baseline; the later fifty-three are original methods with public references. Preserve the original upstream notice in `skills/LICENSE` and any notices required for future imports; no current Skill ships a `LICENSE.txt`. Examples demonstrate reasoning, not measured production outcomes. See [Professional Skills](professional-skills.md).

## Author a Role

Create `roles/quality/export-reviewer.md`:

```markdown
---
id: export-reviewer
name: Export Reviewer
category: quality
defaultSkills:
  - export-contract-check
optionalSkills:
  - integration-verification
---

# Export Reviewer

## When to use

Independently assess a local export against the Task's approved data contract.

## Responsibilities

Read only assigned source and samples. Apply the selected methods, identify failed rules, and provide reproducible evidence. Product scope and acceptance changes belong to the user.

## Non-goals

Do not repair source, change sample data, contact services, merge branches, or dispatch workers.

## Inputs and outputs

Inputs: Task, applicable AGENTS.md, export contract, and local samples. Output: the assigned report with checks, findings, and explicit unverified items.

## Completion

All assigned cases have evidence and a verdict. Follow the injected Worker Contract and write only the assigned report path.
```

Append to `roles/catalog.json`'s `roles` array:

```json
{
  "id": "export-reviewer",
  "name": "Export Reviewer",
  "category": "quality",
  "path": "roles/quality/export-reviewer.md",
  "defaultSkills": ["export-contract-check"],
  "optionalSkills": ["integration-verification"]
}
```

Add an `export-reviewer` property under `routing/model-routing.json`'s `roles` object:

```json
{
  "chain": [
    { "tier": "sonnet", "effort": "high" },
    { "tier": "opus", "effort": "high" }
  ],
  "default": 1,
  "floor": 0,
  "taskTypes": ["Local export contract review"]
}
```

`default` and `floor` are zero-based integer indexes: `0 <= floor <= default < chain.length`. Chains are nonempty and strictly increasing by the file's `modelLadder`, then `effortLevels`; repeated or descending steps fail. The set of routed Roles must equal the catalog set. Reuse existing tier vocabulary and request policy; this example chooses a policy, not proof that a host accepts or launches it. All workers remain `claude`; requested/effective model evidence and user-pinned choices retain their existing rules.

For deliverable-driven selection, add `"export-contract-review": "export-reviewer"` to `routing/role-selection.json`'s `deliverableRoutes`. The Role default already recommends this Skill; a new `riskRoutes` entry is unnecessary for this example. In an existing project, record the selected Role and Skills explicitly in the Task rather than expecting registration to dispatch anything.

## Declare dependencies

Dependencies are declared per entry; the original sixteen methods require no credentials, while provider Skills declare their configuration names. To exercise optional dependencies in the **example Skill's catalog object**, add this `requires` property (not to its Markdown front matter):

```json
{
  "cli": ["pwsh"],
  "env": [
    { "name": "EXAMPLE_EXPORT_KEY", "secret": true, "purpose": "Synthetic export authentication presence check" },
    { "name": "EXAMPLE_EXPORT_MODE", "secret": false, "purpose": "Local export verification mode" }
  ],
  "api": [
    { "name": "example-export", "authEnv": "EXAMPLE_EXPORT_KEY", "purpose": "Synthetic API declaration; no request is made" }
  ]
}
```

The same optional structure works on a Role entry. [requirements.schema.json](../schemas/requirements.schema.json) permits only `cli`, `env`, and `api`, each optional. Declarations contain **names, metadata and purposes**, never values, endpoints, executable hooks or install commands. CLI names match `^[A-Za-z0-9][A-Za-z0-9._-]*$` and resolve as Applications on `PATH`; paths and command strings are invalid. Env names match `^[A-Z][A-Z0-9_]*$`; `KEY`, `TOKEN` and `SECRET` are valid names. Every API `authEnv` must refer to an env declaration in the same entry. API IDs use the lowercase ID pattern.

Duplicate declarations within an entry fail. Across selected entries, identical declarations deduplicate; mismatched env `secret`/`purpose` or API `authEnv`/`purpose` fails. API checks only check the auth variable's presence and always return `networkVerified: false`. They do not authenticate, contact a provider, install a CLI or incur paid API usage.

## Validate the extension

After adding the example, derive the manifest counts from the edited catalogs. Set `deliverables.roles` and `deliverables.professionalSkills` to the corresponding values printed below; do not copy counts from another revision. A complete 3.1.0 package starts at 18 Roles / 69 Skills, so these illustrative additions yield 19 / 70. Preserve the existing `VERSION` and matching manifest `version`; extending an older checkout does not upgrade it to 3.1.0. Keep workflow counts correct.

```powershell
(Get-Content -Raw ./roles/catalog.json | ConvertFrom-Json).roles.Count
(Get-Content -Raw ./routing/skill-catalog.json | ConvertFrom-Json).skills.Count
(Get-Content -Raw ./VERSION).Trim()
```

Run these commands from the edited package copy. An older 12-Role / 16-Skill checkout would instead yield 13 / 17 and retain its existing version; it still lacks the 3.1.0 capabilities. When maintaining a real extension, also update the introductory counts in `skills/README.md`.

In a PowerShell 7 session, set `$package` to your edited package copy:

```powershell
$package = (Resolve-Path 'C:/work/orca-project-delivery-copy').Path
```

```powershell
& "$package/scripts/verify-package.ps1" -MetadataOnly
$metadataExit = $LASTEXITCODE
& "$package/scripts/verify-package.ps1"
$packageExit = $LASTEXITCODE
```

Both must exit 0 with `FAIL=0`. `-MetadataOnly` checks parsing, encoding, routing, entry outline, catalogs and manifest counts/version; it skips runtime fixtures and is not the full acceptance gate. The full suite runs synthetic runtime and extension fixtures offline. Documentation tests run the official 3.1.0 count assertions and the capability tutorial's release guard against a fixed release fixture; acceptance of the edited package compares its actual catalogs, files and manifest without requiring 18 / 69. A mismatched count, missing route or invalid path must fail. Run the full suite again after correcting anything, inspect Git diff and `git diff --check`, then seek independent review through the normal delivery workflow.

## Select and deliver methods

Coordinator selection follows `routing/skill-selection.json`: include Role defaults unless the Task shows they are irrelevant, normally 1–3 required and 0–2 conditional Skills, and add domain methods for material scope/risk. The **helpers do not automatically select Role defaults or optional Skills**: pass exactly the required plus currently activated conditional IDs through `-Skills`.

For the example Task, select `role: "export-reviewer"`, `skills.required: ["export-contract-check"]`, and `skills.conditional: ["integration-verification"]` only if relevant. Use [task-definition.json](../templates/task-definition.json) for the complete Task shape. `assemble-task.ps1` validates IDs, includes Role plus required-Skill dependencies as required, and labels conditional dependencies separately under `### Declared Requirements` inside Inputs and Dependencies. It includes names and purposes, not values. Conditional requirements are not active merely because they appear in a brief; once activated, include their IDs when rerunning both helpers.

The existing ten-part input order remains: objective; Role; required/conditional Skills; inputs/dependencies; scope; branch/worktree; report contract; acceptance/tests; Worker Contract; applicable `AGENTS.md` last. `explicit-path` gives exact readable paths; `inline-extract` embeds required Skill bodies, while conditional Skills remain path references. Record the source path and require proof of reading or applying the method. Workers follow their Task, never the full coordinator Skill.

## Configure the execution host

Use an **explicit `-ProjectRoot` on the machine that actually runs the helper and child**. It must be an existing directory, normally the worker's actual project worktree. The helpers do not search a coordinator tree, copy its `.env`, infer a remote path, or read `.dev-work` overrides. Project execution config is separate from instruction precedence; see [configuration-precedence.md](../references/configuration-precedence.md).

| File/source | Behavior |
| --- | --- |
| Process environment | Highest priority, including an explicitly empty value |
| `<ProjectRoot>/.env` | Literal local values; read only when selected entries declare env requirements; keep untracked |
| Explicit `-ConfigPath` | Lowest priority, non-secret JSON only; there is no default config filename lookup |
| `.env.example` | Share names and empty placeholders, never credentials; not loaded by the helpers |
| `project-config.example.json` | Starter structure, not automatically active |

Coordinator bootstrap creates missing `.env.example` and `project-config.example.json`, preserving existing files. It does not create a populated `.env`. It adds `/.env`, `/AGENTS.md` and `/.dev-work/` to local Git `info/exclude`; that exclude file is shared across the clone's worktrees. Provision execution-host files deliberately without bootstrapping a second `.dev-work/` in a worker. Verify the destination's ignore rules before using real local values.

Dotenv grammar is deliberately small:

- One physical line per `NAME=value`, with uppercase names matching the env pattern; no spaces before the name or between the name and `=`. Empty lines and full-line `#` comments (optionally indented) are allowed.
- Everything after `=` is literal, including spaces, `#`, `$()`, `${...}`, backticks and backslashes. No inline comments, `export`, expansion, escaping, dot-sourcing or shell evaluation.
- If a value starts with `'` or `"`, it must end with the same quote; that outer pair is removed and the same quote cannot occur inside. Unquoted values are not trimmed. Empty values are legal syntax but unavailable as dependencies.
- Duplicate names, malformed lines, unmatched quotes, multiline values and NUL characters fail. Diagnostics identify names/line numbers without echoing values.

Non-secret config uses [project-config.schema.json](../schemas/project-config.schema.json):

```json
{
  "schemaVersion": 1,
  "env": { "EXAMPLE_EXPORT_MODE": "fixture" }
}
```

Pass `-ConfigPath 'project-config.json'` explicitly. Relative paths resolve under `ProjectRoot`; absolute paths must still be inside it, and linked config paths are rejected. Version 1 remains env-only; version 2 also permits [external registrations and Role bindings](external-skills.md), and both require `env`. Every supplied name must be declared non-secret in the package catalogs or configured external registrations; unknown names or names marked secret anywhere are rejected, even if another source overrides them. Values must be strings; duplicate JSON properties, unknown properties, malformed JSON and NUL values fail. Only selected declared variables are added from files to the child.

Precedence chooses **presence of a key**, then checks whether its value is nonempty: process > `.env` > explicit config. An empty process override blocks a nonempty `.env`; an empty `.env` blocks nonempty JSON. Neither falls through. `configured` means a nonempty file value exists, `availableInProcess` means a nonempty current-process value exists, and `availableForChild` reflects the effective source. Thus `configured: true` does not prove the current shell or child can use it. `source` is `process-env`, `project-env-file`, `project-config`, or `absent` (CLI uses `process-command`/`absent`).

## Run an offline example

Use the edited package copy containing the example entries above. Run the blocks **inside a PowerShell 7 session** (or a PowerShell driver script), where `@(...)` really binds as a string array. Native `pwsh -File ... -Skills ...` is not an equivalent way to pass multi-element arrays. These snippets use fake values and a local probe; they select no real provider and make no network request.

Create a fresh temporary execution root and files:

```powershell
$project = Join-Path ([IO.Path]::GetTempPath()) ('orca-extension-demo-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $project | Out-Null
@'
EXAMPLE_EXPORT_KEY=synthetic-not-a-credential
EXAMPLE_EXPORT_MODE=fixture
EXAMPLE_UNDECLARED=not-injected
'@ | Set-Content -LiteralPath "$project/.env" -Encoding utf8
@'
{"schemaVersion":1,"env":{"EXAMPLE_EXPORT_MODE":"json-fallback"}}
'@ | Set-Content -LiteralPath "$project/project-config.json" -Encoding utf8
@'
param([string]$Label)
if ($env:EXAMPLE_EXPORT_KEY -ne 'synthetic-not-a-credential') { exit 11 }
if ($env:EXAMPLE_EXPORT_MODE -ne 'fixture') { exit 12 }
if (Test-Path Env:EXAMPLE_UNDECLARED) { exit 13 }
if ($Label -ne 'local probe with spaces') { exit 14 }
if (-not (Test-Path -LiteralPath './.env')) { exit 15 }
Write-Output 'Synthetic child checks passed; no values printed.'
exit 23
'@ | Set-Content -LiteralPath "$project/probe.ps1" -Encoding utf8
```

Run this in a fresh demo session where the three `EXAMPLE_` variables above are absent. If they are already set, use a separate clean session rather than clearing someone else's configuration. The parent snapshot below proves the wrapper leaves these variables unchanged:

```powershell
$demoNames = @('EXAMPLE_EXPORT_KEY', 'EXAMPLE_EXPORT_MODE', 'EXAMPLE_UNDECLARED')
foreach ($name in $demoNames) {
  if (Test-Path "Env:$name") { throw "Use a demo session without $name" }
}
$parentBefore = [Environment]::GetEnvironmentVariables()
$selectedSkills = @('export-contract-check', 'integration-verification')
& "$package/scripts/check-requirements.ps1" -ProjectRoot $project -Role export-reviewer -Skills $selectedSkills -ConfigPath 'project-config.json'
$checkExit = $LASTEXITCODE
if ($checkExit -ne 0) { throw 'Dependency preflight failed' }
$executable = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
$childArguments = @('-NoProfile', '-File', (Join-Path $project 'probe.ps1'), '-Label', 'local probe with spaces')
& "$package/scripts/invoke-with-requirements.ps1" -ProjectRoot $project -Role export-reviewer -Skills $selectedSkills -ConfigPath 'project-config.json' -Executable $executable -Arguments $childArguments
$childExit = $LASTEXITCODE
if ($childExit -ne 23) { throw "Unexpected child exit: $childExit" }
$parentAfter = [Environment]::GetEnvironmentVariables()
foreach ($name in $demoNames) {
  if ($parentAfter.Contains($name) -ne $parentBefore.Contains($name) -or $parentAfter[$name] -ne $parentBefore[$name]) { throw "Parent changed: $name" }
}
```

Expected: preflight exit 0; env/API file configuration true, process availability false, child availability true; `.env` beats JSON for the mode; API `networkVerified` is false. The child prints only the fixed success sentence and exits **23**, which the wrapper forwards. The undeclared file variable is absent from the child, while pre-existing process variables are inherited even if undeclared. This is not an environment isolation sandbox. In an outer driver that must return the child status, capture it immediately and end with `exit $childExit`.

The shared helper parameters are mandatory `-ProjectRoot <string>` and `-Role <id>`, optional `-Skills <string[]>` (default empty) and `-ConfigPath <string>` (default none). The invocation helper additionally requires `-Executable <string>` and accepts `-Arguments <string[]>` (default empty). There is no implicit all-catalog selection. Check exits 1 for missing/invalid requirements; invoke refuses to start on missing requirements, returns 1 for preflight/start errors, and otherwise forwards the child exit code.

`-Executable` is an explicitly user/Task-authorized command or path. Relative paths resolve from `ProjectRoot`; an authorized absolute executable may be **outside** that root. Config path confinement does not confine executables. Prefer a real executable/interpreter and an argument array: Windows `.cmd`/`.bat` launchers are not guaranteed with direct `ProcessStartInfo` execution. Arguments use `ArgumentList`, without a shell command string. The child's working directory is `ProjectRoot`; helpers preserve the parent environment and inject only selected declared file variables over inherited environment. Wrapper diagnostics print no values or child arguments, but child stdout/stderr pass through unchanged: a child can print secrets, and the helper does not redact arbitrary output. These examples were exercised on Windows; separate non-Windows execution is unverified.

## Diagnose failures

| Symptom | Next check |
| --- | --- |
| Unknown Role/Skill or invalid path | Check native catalog IDs or explicit external registrations and the execution ProjectRoot; links/traversal are unsupported, but absolute external paths may be outside the root |
| Count/routing failure | Align manifest counts and register the new Role's route |
| `configured: true`, `availableForChild: false` | Look for an empty process override; do not print its value |
| File exists only in coordinator worktree | Provision the intended file at the explicit execution-host root; no automatic copying occurs |
| API presence passes but a real operation fails | Presence is not authentication or network verification; use separately authorized diagnostics |
| Config rejected despite process override | All supplied JSON names and schema are validated, including unused or overridden names |
| CLI check passes but launcher cannot start | Use the actual executable/interpreter; PATH presence does not guarantee batch-launch compatibility |
| Child leaks values | Fix the child's output; the wrapper cannot sanitize arbitrary child logs |

For lifecycle, review and reporting, continue with [Usage](usage.md); this extension workflow does not change those boundaries.
