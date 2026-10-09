# Professional Skills

**English** | [简体中文](zh-CN/professional-skills.md)

Orca Project Delivery coordinates workers that load **professional Skills** —
method-only instruction packs (`SKILL.md`) for reconnaissance, product work,
architecture, implementation, review, and verification. All sixteen Skills ship
**inside this package** under `skills/<skill-id>/SKILL.md`.

## Upstream source

| Item | Value |
| --- | --- |
| Repository | [orca-professional-skills](https://github.com/guanwenpeng2001-bot/orca-professional-skills) |
| Source commit (import) | `d9a174c7143bfb4c76ed042f457fb7785c35cea3` |
| Vendored layout | `skills/<skill-id>/SKILL.md` in this repository |
| License | MIT — `skills/LICENSE` (see also package root `LICENSE`) |
| Integrity table | `skills/README.md` (SHA256 per file) |

Re-import from upstream when you intentionally refresh content; do not edit vendored
`SKILL.md` bodies in place.

## The sixteen Skills

Paths in `routing/skill-catalog.json` are relative to this package and resolve as
`skills/<skill-id>/SKILL.md` under the package root.

| Skill ID | Purpose |
| --- | --- |
| `codebase-reconnaissance` | Inspect code, branch, history, configuration, and tests for scoped factual questions without modifying source. |
| `technical-research` | Research technical behavior from primary sources, code, standards, and reproducible experiments. |
| `product-discovery` | Turn vague product intent into problem, users, outcomes, scope, non-goals, and acceptance direction. |
| `product-design` | Design flows, information architecture, interaction states, accessibility, and testable UX acceptance. |
| `requirements-analysis` | Produce traceable, testable functional and non-functional requirements from objectives and evidence. |
| `solution-architecture` | Design boundaries, interfaces, data flow, migration, rollback, and operational behavior for scoped changes. |
| `api-design` | Design HTTP/RPC/event/CLI/module contracts with validation, errors, idempotency, auth, and compatibility. |
| `database-design` | Design models, constraints, migrations, transactions, indexes, queries, retention, and rollback. |
| `implementation-planning` | Break approved design into Tasks with scope, acceptance, tests, roles, skills, branches, and reports. |
| `test-driven-development` | Implement behavior with RED-GREEN-REFACTOR and focused automated tests. |
| `systematic-debugging` | Reproduce, isolate, explain, fix, and verify defects with evidence-driven hypotheses. |
| `code-review` | Independent review for correctness, lifecycle, concurrency, errors, maintainability, and tests. |
| `security-review` | Review trust boundaries, auth, input, secrets, injection, dependencies, and abuse paths. |
| `performance-review` | Measure and analyze latency, throughput, queries, memory, concurrency, and capacity. |
| `integration-verification` | Verify acceptance with commands, runtime evidence, integration checks, and explicit skips. |
| `merge-conflict-resolution` | Resolve merge conflicts using branch intent, base, history, interfaces, and tests. |

## Installation

1. Clone this coordinator package (see [installation.md](installation.md)).
2. Run `scripts/verify-package.ps1` — skill-path checks expect each bundled
   `skills/<skill-id>/SKILL.md` to exist inside the package. No separate Skills
   clone or copy step is required.

## What these Skills are not

- They are **not** orchestration control: they do not start Runs, dispatch
  workers, merge branches, or widen Task scope.
- They are **not** a substitute for the global Orca Skills (`orchestration`,
  `orca-cli`, `orca-per-workspace-env`).
- They do **not** imply affiliation with Anthropic, Orca, or any vendor beyond
  the MIT-licensed repositories linked above.

## When something is missing

| Symptom | Likely cause | What to check |
| --- | --- | --- |
| `verify-package.ps1` skill-path FAIL | Bundled file missing or corrupt | `Test-Path <package>/skills/<skill-id>/SKILL.md`; compare hashes in `skills/README.md` |
| Worker cannot read assigned Skill | Wrong path in Task or sandbox | Task `explicit-path` matches an existing bundled `SKILL.md` |
| Catalog lists Skill but file missing | Incomplete checkout or local deletion | Restore from Git; re-run integrity check |
| Hash mismatch after manual edit | In-place edit of vendored body | Re-import from upstream at the recorded commit |

For coordinator behavior and evidence paths, see [usage.md](usage.md) and
`references/evidence-binding.md`.
