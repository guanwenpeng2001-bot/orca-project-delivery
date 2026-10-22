# Orca Project Delivery

**English** | [简体中文](README.zh-CN.md)

A coordinator-only Skill for Orca and Claude Code users, turning software objectives into isolated, independently reviewed, integrated, and verified changes.

![Version](https://img.shields.io/badge/version-3.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-5391FE)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)

These guides describe the **3.0.0 package: 46 Skills, 16 Roles, and 4 workflows**. Install the complete matching release, and check `VERSION`, both catalogs, and the manifest before following the [capability tutorial](docs/professional-capability-tutorial.md). A version that does not match is not this release.

New in 3.0.0: the delivery flow is reduced to its load-bearing stages. The six-phase Git-evidence validator, its schema and templates, the dispatch-wave ledger, the brief digest and the bundled-Skill hash table are removed; integration safety rests where it actually came from — task isolation, one writer per branch, an independent reviewer who is not the implementer, a clean-tree/approved-commit check the coordinator runs directly before merging, and a full verification suite at the integrated HEAD and again at the latest delivery before closure. Machine-readable assignments, model-routing receipts, the coordinator lock and the writer-replacement gate remain. Bundled counts stay 46 Skills, 16 Roles, and 4 workflows; [installed external Skills](docs/external-skills.md) remain available through explicit project configuration.

Orca Project Delivery is a coordinator-only Skill that runs a complete software
delivery pipeline with Claude Code worker agents. It solves the problem of
supervising many autonomous agents on one repository without losing branch
discipline, independent review, or a verified result. It is written for the
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
   the one `delivery_branch`, verifying the approved commit and clean trees
   first and running the full suite at the integrated HEAD.
8. **Final verification** — a clean, independent worktree from the latest
   delivery branch; the run is not closed until it passes or is explicitly
   marked unverifiable.

Everything the coordinator asserts is backed by a written record: model
routing (requested vs. effective), per-Task assignments, degradation events,
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
- **Windows only in practice.** Delivery helpers use PowerShell 7; capability tools also use Node.js and Python.
  Validation has only been performed on Windows. There is no installer for other platforms.
- **Not distributed through a package registry.** There is no npm or pip
  package; installation is a plain Git clone or copy (see
  [docs/installation.md](docs/installation.md)).

## Capabilities at a glance

| Capability | Detail | Source |
| --- | --- | --- |
| Roles | 16 (research, product, architecture, engineering, quality, media) | `roles/catalog.json` |
| Professional Skills | 46 bundled under package `skills/` | `routing/skill-catalog.json` |
| Workflows | 4: feature-development, bug-fix, refactor, audit | `workflows/` |
| Adaptive depth | light / standard / high-risk stage chains | `routing/workflow-selection.json` |
| Model routing | per-role chains over haiku / sonnet / opus / fable with effort levels, defaults, floors | `routing/model-routing.json` |
| Required invariants | 12 binding rules for isolation, review, evidence, and integration | `SKILL.md` |
| Helper scripts | PowerShell bootstrap, assembly, dependency checks, scoped child execution, validation and release | `scripts/` |
| Offline acceptance | Full synthetic package suite; require exit 0 and `FAIL=0` | `scripts/verify-package.ps1` |
| Native extensions | Register Roles and Skills, declare optional CLI/env/API requirements | [Extension guide](docs/extending.md) |
| Professional capabilities | 8 new Skills and 6 enhancement groups in 2.4.0; 16 Roles and 4 workflows retained | [Capability guide](docs/professional-capabilities.md) |

## Quick start

Requirements: Windows, PowerShell 7+, Git, Claude Code, the Orca Runtime, and
this package (professional Skills are included under `skills/`). The original
sixteen trace to
[orca-professional-skills](https://github.com/guanwenpeng2001-bot/orca-professional-skills);
the later thirty are original MIT methods with public references, per
[docs/professional-capabilities.md](docs/professional-capabilities.md).
Full details and troubleshooting:
[docs/installation.md](docs/installation.md).

```powershell
# 1. Clone the package into your skills root
git clone https://github.com/guanwenpeng2001-bot/orca-project-delivery.git "$env:USERPROFILE\.agents\skills\orca-project-delivery"

# 2. Verify the package offline (expects: SUMMARY PASS=<n> FAIL=0, exit 0)
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
├── VERSION                   # 3.0.0
├── PACKAGE-MANIFEST.json     # Package metadata and deliverable counts
├── CHANGELOG.md
├── README.md                 # English (default)
├── README.zh-CN.md           # Simplified Chinese
├── docs/
│   ├── installation.md       # Install, verify, upgrade, uninstall, troubleshooting
│   ├── usage.md              # End-to-end coordinator walkthrough
│   ├── architecture.md       # Design: planes, roles, workflows, invariants
│   ├── extending.md          # Native Role/Skill extensions and execution configuration
│   ├── professional-skills.md
│   ├── professional-capabilities.md
│   ├── professional-capability-tutorial.md
│   ├── faq.md                # FAQ and troubleshooting
│   └── zh-CN/                # Simplified Chinese translations of the guides above
├── references/               # 10 deep-dive references (runtime, branch model, handoff, ...)
├── roles/                    # 16 role contracts + catalog.json
├── routing/                  # Model, role, skill, and workflow routing tables
├── skills/                   # 46 maintained professional Skills + LICENSE + README
├── workflows/                # 4 workflow definitions
├── schemas/                  # State, requirements and configuration schemas
├── scripts/                  # Delivery and configuration PowerShell helpers
└── templates/                # AGENTS.md, task/review/report templates, .dev-work seeds
```

## Documentation

| Document | Contents |
| --- | --- |
| [Installation](docs/installation.md) | Prerequisites, directory conventions, install steps, verification, upgrade, uninstall, common install failures |
| [Professional Skills](docs/professional-skills.md) | All 46 worker Skills, per-Skill sources, install layout, and troubleshooting |
| [Professional capabilities](docs/professional-capabilities.md) | All 30 later methods and 6 enhancement groups: scope, evidence, licenses |
| [Capability tutorial](docs/professional-capability-tutorial.md) | Offline checks, local-tool examples and dependency helpers; no provider calls |
| [Extending and configuration](docs/extending.md) | Native Role/Skill recipes, dependency declarations, literal configuration, offline child-execution walkthrough |
| [Usage](docs/usage.md) | Starting a delivery from the coordinator entry, the full stage sequence, role/model routing, branch and worktree rules, records and reports, worker receipts, Q&A |
| [Architecture](docs/architecture.md) | Control vs. delivery plane, authority sources, role/workflow/skill tables, coordinator lock, the 12 invariants |
| [FAQ](docs/faq.md) | Common questions and failure-mode troubleshooting |
| [简体中文](README.zh-CN.md) | Chinese README, with links to the Chinese guides under `docs/zh-CN/` |
| [Changelog](CHANGELOG.md) | Release history |

Reference documentation inside the package (`references/`) is written for the
coordinator at runtime and goes deeper than the public docs; start with
`SKILL.md` and follow its links.

## License

This project's original work is licensed under the MIT License — see
[LICENSE](LICENSE). In short: you may use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of this software, provided the
copyright notice and permission notice are included in all copies or
substantial portions of the Software. The software is provided "as is",
without warranty of any kind.

Third-party material keeps the license it was included under. Adapted Skills
record their upstream, pinned commit, and license in `skills/README.md`; an
Apache-2.0 Skill is not relicensed as MIT. See
[Professional capabilities](docs/professional-capabilities.md#licenses-and-sources).
