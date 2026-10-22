# Configuration Precedence

Highest to lowest:

1. User's explicit instruction for the current run or Task.
2. Applicable project and nested `AGENTS.md`.
3. Task Contract.
4. Role Contract.
5. Required professional Skills.
6. Package catalog selection and `routing/model-routing.json` policies.
7. Agent defaults.

## Skill configuration and delivery

Under `skills/`, the original 16 Skills are package-maintained adaptations of the MIT-licensed baseline; the 30 methods added in versions 2.3.0 and 2.4.0 are original package content. `skills/README.md` records provenance. See [Extending](../docs/extending.md) for native authoring/registration and metadata/full verification.

- `explicit-path` is the default: give the absolute `SKILL.md` path in the Task and require reading it.
- `inline-extract` is the fallback: embed required Skill bodies as a snapshot and record source path.

A Skill name alone never proves loading. Skills supply method and cannot expand Task scope or grant orchestration control.

The list above is instruction precedence. Version 2 project config has a narrow explicit
`externalSkills` / `roleBindings` resolver through `-ConfigPath`; it does not merge
arbitrary catalogs or routing, scan installed directories, or load `.dev-work/config/`.
Version 1 remains env-only; both versions require `env`, even when `{}`.

Assembly uses a configured Role binding only when the entire Task `skills` property
is absent; without that Role's binding, omission fails before output. Explicit
required/conditional arrays, including empty arrays, override bindings. Whole-Task
schema validation applies. Only `skillz` is specially rejected; legacy top-level
extension fields remain accepted. With a binding, embedded Role Skill metadata
reflects effective selection, while JSON `roleBinding` preserves the configured value.
Requirement helpers never infer this selection: pass assembly's `skills.required`
plus activated conditional selectors explicitly to both helpers.

External absolute paths may be outside ProjectRoot; relative registrations resolve
from ProjectRoot. Config files remain confined to that root. Traversal and linked
paths are unsupported. Both delivery modes retain the original resource base for
relative scripts/resources via the original `resourceBase`. Provenance distinguishes observed entry SHA256 from unverified `declaredVersion`; `configPath` echoes the supplied argument. Registration never rewrites originals or changes bundled counts. No automatic install/scanning or host-feature emulation occurs; arbitrary host loading/effectiveness is not guaranteed.

Catalog and external `requires` use the existing CLI/env/API schema of names and purposes, never prose or frontmatter inference. Assembly lists required and conditional requirements inside Inputs and Dependencies, preserving the ten-part order and AGENTS last. Pass the execution root/config with the selected IDs to both requirement helpers.

See [installed external Skills](../docs/external-skills.md) for
registration, provenance, declared requirements and an executable offline walkthrough.

## Execution configuration

The dependency helpers require an explicit execution-host `-ProjectRoot` and `-Role`.
Pass selected required and activated conditional IDs as an in-session PowerShell
`-Skills @('test-driven-development', 'integration-verification')` array; Role defaults
are not automatically selected. Values resolve by key presence: process environment
(including empty overrides) > project-root `.env` > explicitly selected non-secret
`-ConfigPath`. Empty effective values are unavailable and do not fall through.

`check-requirements.ps1` reports names/purposes, configured-file status, current-process
availability and effective child availability; API checks never verify authentication
or network access. `invoke-with-requirements.ps1` accepts an authorized executable and
`-Arguments @(...)` array with `-Executable`, inherits process variables and adds only selected declared file values
to the child without changing the parent. Child output is not redacted. Config paths
stay inside ProjectRoot; an explicitly authorized executable may be outside it. API checks are presence-only and perform no network or install actions. Prefer real executables/interpreters over batch launchers.

See [Extending and configuration](../docs/extending.md) for literal dotenv grammar,
JSON restrictions, exact interfaces, bootstrap behavior and runnable offline examples.
Workers never need a `.dev-work/` copy or an automatic coordinator `.env` transfer.

For 2.4.0 local tools, a declared Node command does not prove a sufficient Node
version, Python Playwright availability, a usable Chromium executable, document
libraries, or FFmpeg availability. Check the selected tool at its actual entry
point; optional browser skips and header-only image checks remain limited
evidence. These dependencies do not require provider credentials.

## Important consequences

- A user-pinned model/effort allows no automatic upgrade or downgrade. If the choice is rejected or the receipt mismatches, suspend the Task and ask.
- AGENTS project rules override fixed thresholds or technology assumptions in a generic Role/Skill.
- Task scope overrides a Skill's broad checklist.
- Runtime evidence overrides requested model names.
- Installed Orca behavior overrides this package's source snapshot.
