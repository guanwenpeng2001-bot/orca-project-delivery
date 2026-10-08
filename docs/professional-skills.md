# Professional Skills

Orca Project Delivery coordinates workers that load **professional Skills** —
method-only instruction packs (`SKILL.md`) for reconnaissance, product work,
architecture, implementation, review, and verification. This package does **not**
ship those files; they live in a separate public repository.

## Source repository

| Item | Value |
| --- | --- |
| Repository | [orca-professional-skills](https://github.com/guanwenpeng2001-bot/orca-professional-skills) |
| Layout | One directory per Skill at the repository root (`<skill-id>/SKILL.md`) |
| License | MIT (same copyright holder as this package) |
| Coordinator package | [orca-project-delivery](https://github.com/guanwenpeng2001-bot/orca-project-delivery) |

## The sixteen Skills

Paths in `routing/skill-catalog.json` are relative to this package and resolve
as `..\<skill-id>\SKILL.md`, so each Skill directory must be a **sibling** of
`orca-project-delivery` under your skills root (typically `~/.agents/skills/`).

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
2. Clone the professional Skills repository to a temporary or sibling path:

   ```powershell
   git clone https://github.com/guanwenpeng2001-bot/orca-professional-skills.git "$env:USERPROFILE\.agents\skills\orca-professional-skills"
   ```

3. Copy each of the sixteen `<skill-id>` directories from that clone into
   `~/.agents/skills/` so they sit next to `orca-project-delivery` (not inside
   the `orca-professional-skills` folder). On Windows PowerShell:

   ```powershell
   $root = "$env:USERPROFILE\.agents\skills"
   $ids = @(
     'codebase-reconnaissance','technical-research','product-discovery','product-design',
     'requirements-analysis','solution-architecture','api-design','database-design',
     'implementation-planning','test-driven-development','systematic-debugging',
     'code-review','security-review','performance-review','integration-verification',
     'merge-conflict-resolution'
   )
   foreach ($id in $ids) {
     Copy-Item -Recurse -Force "$root\orca-professional-skills\$id" "$root\$id"
   }
   ```

4. Re-run `scripts/verify-package.ps1`; skill-path checks expect each
   `..\<skill-id>\SKILL.md` to resolve from the package directory.

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
| `verify-package.ps1` skill-path FAIL | Skill not installed as sibling | `Test-Path ~/.agents/skills/<skill-id>/SKILL.md` |
| Worker cannot read assigned Skill | Wrong path in Task or sandbox | Task `explicit-path` matches an existing `SKILL.md` |
| Catalog lists Skill but file missing | Only coordinator package cloned | Complete [Installation](#installation) step 3 |
| Old copy after upgrade | Stale sibling directories | Re-copy from latest `orca-professional-skills` tag or `main` |

For coordinator behavior and evidence paths, see [usage.md](usage.md) and
`references/evidence-binding.md`.
