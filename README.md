# Orca Project Delivery

A coordinator-only Skill for Orca and Claude Code users, turning software objectives into isolated, independently reviewed, integrated, and verified changes.

![Version](https://img.shields.io/badge/version-2.2.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-5391FE)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)

Orca Project Delivery is a coordinator-only Skill that runs a complete software
delivery pipeline with Claude Code worker agents. It solves the problem of
supervising many autonomous agents on one repository without losing branch
discipline, independent review, or verifiable evidence. It is written for the
person who acts as coordinator: you already have Orca (a multi-agent IDE) and
Claude Code, and you want large changes produced, reviewed, integrated, and
final-verified by isolated workers under explicit contracts.

- [What this is](#what-this-is)
- [What this is not](#what-this-is-not)
- [Capabilities at a glance](#capabilities-at-a-glance)
- [Quick start](#quick-start)
- [Repository structure](#repository-structure)
- [Documentation](#documentation)
- [License](#license)

## What this is

A single coordinator entry point (`SKILL.md`) that drives project delivery
from intake to final verification:

1. **Intake** — record the objective, scale, delivery branch, user-pinned
   choices, and side-effect boundaries.
2. **Dynamic reconnaissance** — one isolated Scout Task per independent
   information domain, dispatched in parallel.
3. **Plan** — a Solution Planner, plus multiple plans and a Plan Adjudicator
   when risk warrants.
4. **Task graph** — self-contained Tasks with role, skills, branch, scope,
   acceptance criteria, and report paths.
5. **Dispatch and rolling execution** — every Task gets its own branch and
   worktree; ready Tasks are dispatched as their real dependencies settle.
6. **Independent review** — reviewers never edit source; findings become fix
   Tasks followed by re-review.
7. **Integration** — the coordinator merges approved branches serially into
   the one `delivery_branch`, recording commit evidence at every gate.
8. **Final verification** — a clean, independent worktree from the latest
   delivery branch; the run is not closed until it passes or is explicitly
   marked unverifiable.

Everything the coordinator asserts is backed by a written record: model
routing (requested vs. effective), Git evidence (source registration, review,
pre-merge admission, merge result, run-final coverage), degradation events,
and user decisions.

## What this is not

- **Not a general-purpose orchestration framework.** It defines one business
  workflow: project delivery with Claude Code workers. It does not manage
  arbitrary agent fleets or other agent runtimes.
- **Not a replacement for the global Orca Skills.** The installed
  `orchestration`, `orca-cli`, and `orca-per-workspace-env` skills remain the
  authority for Run/Task/Dispatch/Worker lifecycle, commands, and receipts.
  This package maps business actions to runtime concepts; confirm any command
  examples against the installed Skills and current help.
- **Coordinator-only.** Workers carrying a dispatch preamble must not run this
  Skill. A worker executes exactly its assigned Task, Role, professional
  Skills, branch, and report contract.
- **Depends on Claude Code and the Orca Runtime.** All workers are Claude
  Code agents launched through Orca; there is no standalone mode.
- **Windows only in practice.** Every script is PowerShell 7 and has only been
  exercised on Windows. There is no installer for other platforms.
- **Not distributed through a package registry.** There is no npm or pip
  package; installation is a plain Git clone or copy (see
  [docs/installation.md](docs/installation.md)).

## Capabilities at a glance

| Capability | Detail | Source |
| --- | --- | --- |
| Roles | 12 (research, product, architecture, engineering, quality) | `roles/catalog.json` |
| Professional Skills | 16 sibling Skills under `~/.agents/skills` | `routing/skill-catalog.json` |
| Workflows | 4: feature-development, bug-fix, refactor, audit | `workflows/` |
| Adaptive depth | light / standard / high-risk stage chains | `routing/workflow-selection.json` |
| Model routing | per-role chains over haiku / sonnet / opus / fable with effort levels, defaults, floors | `routing/model-routing.json` |
| Required invariants | 12 binding rules for isolation, review, evidence, and integration | `SKILL.md` |
| Helper scripts | 9 PowerShell scripts (bootstrap, run creation, task assembly, probes, validation, release) | `scripts/` |
| Offline acceptance | 55-check self-verification suite, exit 0 on success | `scripts/verify-package.ps1` |
| Git evidence | 6 validation phases: sourceRegistered, review, preMerge, postMerge, final, audit | `scripts/validate-git-evidence.ps1` |

## Quick start

Requirements: Windows, PowerShell 7+, Git, Claude Code, the Orca Runtime, and
the [16 professional Skills](docs/professional-skills.md) from
[orca-professional-skills](https://github.com/guanwenpeng2001-bot/orca-professional-skills).
Full details and troubleshooting:
[docs/installation.md](docs/installation.md).

```powershell
# 1. Place the package next to its sibling skills (default convention)
git clone https://github.com/guanwenpeng2001-bot/orca-project-delivery.git "$env:USERPROFILE\.agents\skills\orca-project-delivery"

# 2. Verify the package offline (expects: SUMMARY PASS=55 FAIL=0, exit 0)
pwsh -NoProfile -File "$env:USERPROFILE\.agents\skills\orca-project-delivery\scripts\verify-package.ps1"
```

Then, as coordinator, open the Skill from your control worktree and follow
`SKILL.md`: bootstrap the project, create a run, dispatch workers, review,
integrate, and close. The walkthrough lives in
[docs/usage.md](docs/usage.md).

## Repository structure

```text
orca-project-delivery/
├── SKILL.md                  # Coordinator entry point (17 sections, <= 250 lines)
├── LICENSE                   # MIT
├── VERSION                   # 2.2.0
├── PACKAGE-MANIFEST.json     # Package metadata and deliverable counts
├── CHANGELOG.md
├── docs/
│   ├── installation.md       # Install, verify, upgrade, uninstall, troubleshooting
│   ├── usage.md              # End-to-end coordinator walkthrough
│   ├── architecture.md       # Design: planes, roles, workflows, evidence, invariants
│   └── faq.md                # FAQ and troubleshooting
├── references/               # 11 deep-dive references (runtime, branch model, evidence, ...)
├── roles/                    # 12 role contracts + catalog.json
├── routing/                  # Model, role, skill, and workflow routing tables
├── workflows/                # 4 workflow definitions
├── schemas/                  # 8 JSON schemas for .dev-work state and evidence
├── scripts/                  # 9 PowerShell scripts
└── templates/                # AGENTS.md, task/review/report templates, .dev-work seeds
```

## Documentation

| Document | Contents |
| --- | --- |
| [Installation](docs/installation.md) | Prerequisites, directory conventions, install steps, verification, upgrade, uninstall, common install failures |
| [Professional Skills](docs/professional-skills.md) | The 16 worker Skills, source repository, install layout, and troubleshooting |
| [Usage](docs/usage.md) | Starting a delivery from the coordinator entry, the full stage sequence, role/model routing, branch and worktree rules, evidence and reports, worker receipts, Q&A |
| [Architecture](docs/architecture.md) | Control vs. delivery plane, authority sources, role/workflow/skill tables, evidence model, coordinator lock, the 12 invariants |
| [FAQ](docs/faq.md) | Common questions and failure-mode troubleshooting |
| [Changelog](CHANGELOG.md) | Release history |

Reference documentation inside the package (`references/`) is written for the
coordinator at runtime and goes deeper than the public docs; start with
`SKILL.md` and follow its links.

## License

This project is licensed under the MIT License — see
[LICENSE](LICENSE). In short: you may use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of this software, provided the
copyright notice and permission notice are included in all copies or
substantial portions of the Software. The software is provided "as is",
without warranty of any kind.
