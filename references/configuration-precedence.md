# Configuration Precedence

Highest to lowest:

1. User's explicit instruction for the current run or Task.
2. Applicable project and nested `AGENTS.md`.
3. Task Contract.
4. Role Contract.
5. Required professional Skills.
6. Package catalog selection and `routing/model-routing.json` policies.
7. Agent defaults.

This is instruction precedence, not an implemented JSON overlay loader. Run decisions
may record explicit choices, but no generic `.dev-work/config/` or run-level override
resolver merges catalogs, routing or execution environment files.

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
argument array, inherits process variables and adds only selected declared file values
to the child without changing the parent. Child output is not redacted. Config paths
stay inside ProjectRoot; an explicitly authorized executable may be outside it.

See [Extending and configuration](../docs/extending.md) for literal dotenv grammar,
JSON restrictions, exact interfaces, bootstrap behavior and runnable offline examples.
Workers never need a `.dev-work/` copy or an automatic coordinator `.env` transfer.

## Important consequences

- A user-pinned model/effort allows no automatic upgrade or downgrade. If the choice is rejected or the receipt mismatches, suspend the Task and ask.
- AGENTS project rules override fixed thresholds or technology assumptions in a generic Role/Skill.
- Task scope overrides a Skill's broad checklist.
- Runtime evidence overrides requested model names.
- Installed Orca behavior overrides this package's source snapshot.
