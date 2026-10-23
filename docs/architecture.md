# Architecture

**English** | [简体中文](zh-CN/architecture.md)

This document explains how `orca-project-delivery` is designed: the two
planes it separates, the authorities it never duplicates, the roles,
workflows, and Skills it routes to, its coordinator
lock, and the invariants that bind all of it together.

## Control plane vs. delivery plane

The package rigidly separates three Git planes:

| Plane | What lives there | What never happens there |
| --- | --- | --- |
| **Control plane** — the coordinator control worktree, on a control branch | One Coordinator Agent, the project `AGENTS.md`, `.dev-work/` process state, orchestration context | No source development, no task baselines, no merges, no reviews, no final verification. Its HEAD may lag and is never delivery evidence. |
| **Delivery plane** — the one `delivery_branch` | Reviewed, accepted source. The default task base, the integration target, and the final-verification source | No process artifacts (`.dev-work/`, plans, reports) ever enter it. |
| **Task plane** — per-Task branches and worktrees | Every Task's isolated work, including read-only scout, audit, review, and verification Tasks | No second writer on one branch; workers never merge their own branches. |

The delivery branch is resolved once at intake by `scripts/bootstrap-project.ps1`
in this order: an explicit user-supplied branch → `origin/HEAD` →
`init.defaultBranch` (when that local branch exists) → local `main` → local
`master` → the current branch. The selection and its source are recorded.
Bootstrap refuses a control worktree that sits on the resolved delivery
branch; the explicit override acknowledges a violation rather than creating a
normal path.

## System boundaries and authorities

Four authorities, each owning exactly one kind of truth:

| Authority | Owns |
| --- | --- |
| **Git** | Source, branches, commits, integration truth. |
| **Orca Runtime** | Run, Task, Dispatch, Worker, Message, Gate, lifecycle truth. |
| **`.dev-work/`** (control tree only) | Business stages, mappings, plans, reports, decisions — never a second lifecycle database. |
| **This Skill** | The workflow, Role/Skill selection, Agent execution, recovery rules, input assembly. |

Before any orchestration verb, the coordinator loads the installed global
`orchestration` Skill and confirms syntax with current `--help`; this package
maps business actions to runtime concepts; command examples must be checked
against the installed contract.
Only the coordinator edits global process state; workers write only their
assigned report paths.

## The 18 roles

One Primary Role per Task, selected by deliverable via
`routing/role-selection.json`. Identity comes from the role, method from the
professional Skills, and the objective from the Task.

| Role | Category | Default Skills |
| --- | --- | --- |
| codebase-scout | research | codebase-reconnaissance |
| technical-researcher | research | technical-research |
| issue-investigator | research | systematic-debugging, codebase-reconnaissance |
| requirements-analyst | product | requirements-analysis, product-discovery |
| solution-planner | architecture | implementation-planning, solution-architecture |
| plan-adjudicator | architecture | implementation-planning, solution-architecture |
| software-architect | architecture | solution-architecture |
| software-implementer | engineering | test-driven-development, integration-verification |
| code-reviewer | quality | code-review, integration-verification |
| security-reviewer | quality | security-review, code-review |
| release-verifier | quality | integration-verification |
| merge-resolver | quality | merge-conflict-resolution, integration-verification |
| ui-designer | product | product-design, frontend-visual-design |
| browser-test-engineer | quality | browser-e2e, integration-verification |
| media-producer | media | (none; the task selects) |
| document-specialist | product | document-production |
| game-designer | product | game-design, game-economy-design, game-level-design |
| game-test-engineer | quality | game-testing-ladders |

Role defines responsibility, Skill defines method, Task defines a bounded objective, and Agent is the runtime executor. Select a usable Orca Agent without a Role-specific model route; omit model/effort unless the user pins them. Native helpers remain under the parent worker’s scope, isolation, results and cleanup responsibilities. Independent review remains a separate Task.

## The 5 workflows

Selected via `routing/workflow-selection.json`; each has a full definition
under `workflows/`. Depth adapts to evidence — light, standard, or high-risk —
and the choice plus any scale reduction is recorded.

| Workflow | When | Stage shape |
| --- | --- | --- |
| feature-development (default) | New or changed product/system behavior is the target | intake → reconnaissance → design (conditional; verdict recorded either way) → plan → task graph → implementation → review → final verification |
| game-development | Developing a game or game feature | intake → reconnaissance → mandatory design → planning → parallel gameplay/assets task graph → implementation → review → publishing readiness → final verification; live-ops handoff |
| bug-fix | Objective is defect correction; reproduction or regression is central | intake → reproduction → investigation → fix planning → implementation → review → integration and verification |
| refactor | External behavior stays stable; internal structure is the target | define invariants → reconnaissance → refactor plan → implementation → review → integration |
| audit | Objective is assessment/findings; implementation is not the initial goal | intake → dynamic audit fan-out → finding contract → validation and deduplication → optional remediation |

The high-risk depth follows parallel reconnaissance/audit → design (conditional;
verdict recorded either way) → independent plans → adjudication → task graph →
staged implementation and review loops → final verification.

Design trigger rules live in `routing/design-triggers.json`.

## The 69 professional Skills

The 23 game methods added in 3.1.0 are listed in [Professional Skills](professional-skills.md#the-twenty-three-added-in-310), with per-Skill provenance in `skills/README.md`. The five workflow definitions include [game-development](../workflows/game-development.md); it retains the global chain and adds mandatory gameplay design, parallel production, per-release publishing readiness and an operations handoff.

Skills are bundled under the package `skills/` directory and are delivered to
workers by `explicit-path` (the absolute `SKILL.md` path named in the Task)
or, as a fallback, by `inline-extract` with the source path
recorded. A Skill name alone never proves delivery, and a Skill supplies
method — it cannot expand Task scope or grant orchestration control.

| Skill | Purpose |
| --- | --- |
| codebase-reconnaissance | Answer scoped factual questions about code, branches, history, configuration, and tests without modifying source |
| technical-research | Research current technical behavior from primary sources and reproducible experiments |
| product-discovery | Turn a vague request into a validated problem, users, outcomes, scope, and non-goals |
| product-design | Design user flows, information architecture, interaction states, and testable UX acceptance |
| requirements-analysis | Convert objectives and evidence into traceable, testable requirements |
| solution-architecture | Design minimal boundaries, responsibilities, interfaces, migration, and rollback |
| api-design | Design stable HTTP, RPC, event, CLI, or module contracts |
| database-design | Design data models, constraints, migrations, and rollback |
| implementation-planning | Turn an approved design into small, dependency-aware Tasks |
| test-driven-development | Implement behavior with RED-GREEN-REFACTOR evidence |
| systematic-debugging | Reproduce, isolate, explain, fix, and verify defects via hypothesis testing |
| code-review | Independent, evidence-based review before integration |
| security-review | Review trust boundaries, auth, secrets, injection, and abuse paths |
| performance-review | Measure and analyze latency, throughput, complexity, and capacity |
| integration-verification | Verify Task and final-delivery acceptance with commands and runtime evidence |
| merge-conflict-resolution | Resolve Git merge conflicts from branch intent, history, and tests |
| frontend-visual-design | Typography, color, and visual hierarchy for a page or component |
| browser-e2e | Browser regression: selectors, traces, fixtures, with a local Python Playwright sample hosted by Node |
| accessibility-audit | Accessibility evidence: focus order, labels, error association, contrast |
| postgres-practices | PostgreSQL indexes, EXPLAIN, and row-level security |
| observability | Decide the runtime question first, then place metrics, logs, and traces |
| ci-pipeline | Organize quality gates around the checks the project actually has |
| react-performance | React and Next.js waterfall and bundle-cost rules |
| react-composition | Component composition, shared state, and boolean-prop sprawl |
| icon-assets | Icon selection with per-set source and license; Iconify lookup needs a network |
| svg-logo-design | SVG logo design and export check |
| web-assets | Favicon, manifest, and social-image sizes from a local master |
| image-compression | Local compression with the measured ratio and transparency preserved |
| image-generation | Prompt and acceptance checks for one selected image backend; generation unverified |
| infographic-design | Layout, reading order, and the claims an infographic must carry |
| editorial-illustration | Cover and article-illustration direction |
| visual-slide-deck | Slides as images; not editable Office objects |
| code-video-production | Code-explainer video planned as frames; HyperFrames is the preferred method |
| generated-video | Online video request; no provider selected, no call verified |
| speech-production | Online speech synthesis; no provider selected, no call verified |
| audio-transcription | Online transcript and timestamps; no provider selected, no call verified |
| media-transcoding | Local cut, remux, and transcode with FFmpeg |
| document-production | Editable documents, slides, spreadsheets, and PDF |
| skill-authoring-evaluation | Score triggering, counterexamples, and observable outcomes |
| design-system | Shared primitive, semantic, and component tokens |
| domain-modeling | Entities, value objects, aggregates, and invariant ownership |
| migration-upgrade | Expand, dual-run, switch, contract and rollback boundaries |
| mcp-server-development | MCP tool schemas, transports, and protocol/tool error separation |
| technical-diagrams | Readable SVG and Mermaid source with accessible descriptions |
| localization | Glossaries, ICU placeholders, expansion, and right-to-left layout |
| subtitle-production | Offline text-cue conversion between SRT and WebVTT |

The fifty-three added Skills are specified in
[Professional capabilities](professional-capabilities.md), including which are
methods, which depend on a local tool, and which are real online calls that
this release has not verified.

## Native extension and execution configuration

Roles and Skills extend the existing `roles/catalog.json` and `routing/skill-catalog.json`, with exact package-local paths, matching Role bindings and manifest counts. Counts are catalog-driven. The original sixteen Skill bodies are maintained MIT adaptations; the other fifty-three are original methods with public references. This project's original work is MIT; third-party Skills keep the license they arrived with, recorded per Skill in `skills/README.md`. Explicit version 2 project configuration additionally registers installed external Skills and mixed Role bindings without editing these catalogs; see [external Skills](external-skills.md). No executable catalog hooks or generic routing overlays are supported.

Optional `requires` metadata names CLI, env and API dependencies. Assembly labels required and conditional sets without adding a new top-level contract section. On the actual execution host, helpers use explicit selectors and ProjectRoot. Configuration precedence is inherited process values (even empty), root `.env`, then explicit non-secret JSON. Only selected declared file variables are added to the child; inherited variables remain and the parent is unchanged. API checks are presence-only. Config paths stay inside the root, while an authorized executable may be outside; direct batch-launch compatibility is not guaranteed. See [Extending](extending.md) for registration and runnable examples.

## Dispatch records and integration checks

The coordinator writes each assignment with `scripts/dispatch-task.ps1` from
the captured `worker-start` receipt; the script refuses a control-worktree
placement and a duplicate live dispatch for one Task.

Integration safety comes from the process itself, checked directly by the
coordinator at the moment it acts:

- **Independent review** — a reviewer who is not the implementer inspects the
  actual branch and reports `APPROVED`, `CHANGES_REQUIRED`, or
  `UNVERIFIABLE`; only APPROVED branches merge.
- **Pre-merge check** — immediately before merging, the coordinator confirms
  the live source HEAD still equals the approved commit and both source and
  delivery worktrees are clean; drift requires re-review.
- **Post-merge verification** — the full package suite runs at the integrated
  HEAD before the source dependency counts as settled.
- **Final verification** — after all intended integrations, a release-verifier
  runs in a clean, independent worktree from the latest `delivery_branch`;
  only its passing result authorizes READY.

## Coordinator lock and release

The runtime has **no coordinator-lock primitive** — two terminals in one
worktree can each create runs unchecked. The lock is therefore a local
convention stored in `.dev-work/coordinator-lock.json`, written by
`scripts/bootstrap-project.ps1`, protecting one worktree when every
coordinator honors it.

Liveness has three states, probed through the recorded terminal handle:

| State | Test | Bootstrap behavior |
| --- | --- | --- |
| `live` | The terminal probe succeeds and returns ok | Refuse: a live coordinator owns this worktree |
| `dead` | The probe parses and answers not ok with the positive not-found error code `terminal_handle_stale` | Warn, archive the old lock, take over |
| `unknown` | No handle, no runtime on PATH, empty or unparsable output, or any other probe failure without the positive not-found signal | Refuse without `-ForceLock` — a failed probe alone is not proof of the holder's death |

Release uses `scripts/release-coordinator.ps1 -ConfirmRunClosed`: it reports
reclaimable workers (an unverifiable result is reported as such, never
treated as failure), archives the active-run and lock files, marks the lock
`released` with timestamps rather than deleting it, and deletes
`active-run.json`. A later bootstrap sees the `released` holder, archives it,
and takes over deliberately. The lock file is never deleted to bypass
release, and a global orchestration reset is never used to clean up one run.

## The 12 required invariants

Quoted from `SKILL.md`; every workflow decision in this package defers to
them.

| # | Invariant (verbatim) |
| --- | --- |
| 1 | Every Task, including read-only work, has an isolated branch and worktree. |
| 2 | One task branch has one writer at a time; replacement never creates a concurrent writer. |
| 3 | Self-check is not independent review; reviewers do not edit source; findings require fix Tasks and re-review. |
| 4 | Silence, empty waits and unverifiable observations do not prove failure, quota exhaustion or process exit. |
| 5 | Each run has one `delivery_branch`: explicit user choice, otherwise `origin/HEAD` → existing `init.defaultBranch` → `main` → `master` → current branch; record the source and integrate directly there. |
| 6 | `.dev-work/` exists only in the control tree; its global state belongs to the coordinator, not workers or a duplicate runtime database. |
| 7 | One active coordinator holds the control-tree lock; use live/dead/unknown evidence, release by marking, never delete the lock or use orchestration reset. |
| 8 | Record requested and effective values separately; only the first launch receipt proves effective values. |
| 9 | Installed global Orca Skills and current help govern commands; do not embed stale command lines. |
| 10 | Process artifacts never enter `delivery_branch`; inspect Git status and diff before commit or merge. |
| 11 | The control branch is neither development nor integration source; its HEAD may lag and is not current delivery evidence. |
| 12 | Review the actual implementation baseline; final verification uses a clean worktree from the latest `delivery_branch`, marking unverifiable evidence explicitly. |

The offline acceptance suite (`scripts/verify-package.ps1`) enforces the
structural side of this design — role/Skill path
existence, the 17-section entry outline, content structure, and
encoding — so the package can be verified without a
runtime.
