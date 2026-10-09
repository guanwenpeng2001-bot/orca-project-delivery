# Architecture

**English** | [简体中文](zh-CN/architecture.md)

This document explains how `orca-project-delivery` is designed: the two
planes it separates, the authorities it never duplicates, the roles,
workflows, and Skills it routes to, its Git evidence model, its coordinator
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
| **`.dev-work/`** (control tree only) | Business stages, mappings, plans, reports, decisions, evidence — never a second lifecycle database. |
| **This Skill** | The workflow, role/Skill/model routing, degradation rules, input assembly. |

Before any orchestration verb, the coordinator loads the installed global
`orchestration` Skill and confirms syntax with current `--help`; this package
maps business actions to runtime concepts; command examples must be checked
against the installed contract.
Only the coordinator edits global process state; workers write only their
assigned report paths.

## The 16 roles

One Primary Role per Task, selected by deliverable via
`routing/role-selection.json`. Identity comes from the role, method from the
professional Skills, and the objective from the Task.

| Role | Category | Default Skills | Model chain (default at index 1) |
| --- | --- | --- | --- |
| codebase-scout | research | codebase-reconnaissance | haiku low → **haiku medium** → haiku high → sonnet medium |
| technical-researcher | research | technical-research | haiku medium → **haiku high** → sonnet medium → sonnet high |
| issue-investigator | research | systematic-debugging, codebase-reconnaissance | haiku high → **sonnet medium** → sonnet high → opus medium |
| requirements-analyst | product | requirements-analysis, product-discovery | sonnet medium → **sonnet high** → opus medium → opus high |
| solution-planner | architecture | implementation-planning, solution-architecture | opus high → **fable high** → fable xhigh → fable max |
| plan-adjudicator | architecture | implementation-planning, solution-architecture | fable high → **fable xhigh** → fable max |
| software-architect | architecture | solution-architecture | opus xhigh → **fable high** → fable xhigh |
| software-implementer | engineering | test-driven-development, integration-verification | sonnet medium → **sonnet high** → sonnet xhigh → opus medium |
| code-reviewer | quality | code-review, integration-verification | sonnet xhigh → **opus high** → opus xhigh → fable high |
| security-reviewer | quality | security-review, code-review | opus high → **opus xhigh** → fable high |
| release-verifier | quality | integration-verification | sonnet high → **opus high** → opus xhigh |
| merge-resolver | quality | merge-conflict-resolution, integration-verification | sonnet medium → **sonnet high** → opus medium |
| ui-designer | product | product-design, frontend-visual-design | sonnet high → **opus medium** → opus high → opus xhigh |
| browser-test-engineer | quality | browser-e2e, integration-verification | sonnet medium → **sonnet high** → sonnet xhigh → opus medium |
| media-producer | media | (none; the task selects) | sonnet medium → **sonnet high** → opus medium → opus high |
| document-specialist | product | document-production | sonnet medium → **sonnet high** → opus medium → opus high |

The four routes at the bottom are current routes for the Roles added in 2.3.0.
They are not a copy of `routing/model-routing.json`, which remains the
authority; where the two differ, the routing file wins and this table needs
updating.

Conflicting identities — design, implementation, independent review — are
split into separate Tasks. Escalation moves one step right along the chain
(effort first, then tier); downgrades require explicit rate-limit, quota, or
model-unavailability evidence and never go below the role's floor.

## The 4 workflows

Selected via `routing/workflow-selection.json`; each has a full definition
under `workflows/`. Depth adapts to evidence — light, standard, or high-risk —
and the choice plus any scale reduction is recorded.

| Workflow | When | Stage shape |
| --- | --- | --- |
| feature-development (default) | New or changed product/system behavior is the target | intake → reconnaissance → plan → task graph → implementation → review → final verification |
| bug-fix | Objective is defect correction; reproduction or regression is central | intake → reproduction → investigation → fix planning → implementation → review → integration and verification |
| refactor | External behavior stays stable; internal structure is the target | define invariants → reconnaissance → refactor plan → implementation → review → integration |
| audit | Objective is assessment/findings; implementation is not the initial goal | intake → dynamic audit fan-out → finding contract → validation and deduplication → optional remediation |

The high-risk depth inserts parallel reconnaissance, independent plans,
adjudication, and architecture before the task graph, and review loops during
implementation.

## The 38 professional Skills

Skills are vendored under the package `skills/` directory and are delivered to
workers by `explicit-path` (the absolute `SKILL.md` path named in the Task)
or, as a fallback, by `inline-extract` with the source path and hash
recorded. A Skill name alone is never loading evidence, and a Skill supplies
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
| browser-e2e | Browser regression: selectors, traces, fixtures, on the project's Node and Playwright |
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

The twenty-two added Skills are specified in
[Professional capabilities](professional-capabilities.md), including which are
methods, which depend on a local tool, and which are real online calls that
this release has not verified.

## Native extension and execution configuration

Roles and Skills extend the existing `roles/catalog.json` and `routing/skill-catalog.json`, with exact package-local paths, matching Role model routes, manifest counts and current Skill hashes. Counts are catalog-driven. Skill bodies are package-maintained adaptations with domain methods and evaluation cases. This project's original work is MIT; third-party Skills keep the license they arrived with, recorded per Skill in `skills/README.md`. No project overlay registry or executable catalog hooks are added.

Optional `requires` metadata names CLI, env and API dependencies. Assembly labels required and conditional sets without adding a new top-level contract section. On the actual execution host, helpers use explicit selectors and ProjectRoot. Configuration precedence is inherited process values (even empty), root `.env`, then explicit non-secret JSON. Only selected declared file variables are added to the child; inherited variables remain and the parent is unchanged. API checks are presence-only. Config paths stay inside the root, while an authorized executable may be outside; direct batch-launch compatibility is not guaranteed. See [Extending](extending.md) for registration and runnable examples.

## The evidence model

`scripts/validate-git-evidence.ps1` is a **read-only** validator over
JSON evidence documents written by the coordinator from observations. The
coordinator gathers and writes first, validates second, and acts only on
`PASS` for the relevant scope. The validator never writes JSON, runs tests,
merges, or queries the runtime. PASS cannot authenticate a worker message or
prove that a recorded test command ran; the coordinator must verify Runtime
ownership and collect actual command results. A valid review record with a
CHANGES_REQUIRED or UNVERIFIABLE verdict can pass the `review` phase, so
validation PASS is not itself review approval.

Per-Task evidence lives at `runs/<run>/evidence/git/<task-key>.json`; the run
has exactly one final record at `runs/<run>/evidence/git/run-final-verification.json`.
Task evidence states are `source-registered` → `reviewed` → `integrated`;
pre-merge is a checkpoint within `reviewed`, and final belongs to the run
record, never to per-Task files.

Six validation phases:

| Phase | Gate | What is checked |
| --- | --- | --- |
| `sourceRegistered` | After a matched, active `worker_done` | Schema, run/path/assignment scope, recorded commit existence |
| `review` | After independent review is recorded | Reviewer independence (Task and Dispatch both differ from the source worker's), target/baseline binding, baseline is an ancestor of target, APPROVED target is clean |
| `preMerge` | After the latest APPROVED review, while still `reviewed` | Admission binds the approved SHA; live source HEAD equals it; source and delivery worktrees are clean; delivery HEAD equals the recorded baseline |
| `postMerge` | After the actual merge plus fresh checks at `headAfter` | Integration result, merge evidence (`git merge --no-edit <branch>`, exit 0, conflict-free), ancestry, verification checks bound to `headAfter` |
| `final` | After all intended integrations, from a clean independent verification worktree | Unique run-final record, verified + READY, complete exact coverage of integrated Tasks, checks at the current delivery HEAD |
| `audit` | Any time, for historical runs | Schema/commits plus state-appropriate checks, with **no** live HEAD-equality or clean-tree requirements |

**Moment equations vs. time-invariant relations.** The live phases assert
equalities that must hold *at the moment of validation* — the source branch
HEAD equals the approved SHA, the delivery HEAD equals the recorded baseline,
the trees are clean. The `audit` phase checks historical bindings, recorded checks, commit
existence, and ancestry without comparing them to live branch HEADs or
worktree cleanliness. Historical Task records also use historical checks
under `final`; selecting a Task alone does not establish run completion.
By contrast, run-scoped `final` (or the canonical run-final selector)
requires the run-final target to equal the current delivery HEAD. A historical
run-final can therefore legitimately FAIL `final` after delivery advances,
while still passing `audit`. Historical `headAfter` remains an ancestor of a
later final target; it need not equal that target.

The validator's exit semantics: `PASS` exits 0 for the selected scope only;
`NOT_APPLICABLE` also exits 0 and is not acceptance; `FAIL` exits 1 and blocks
merging or READY claims until the evidence is rebuilt.

## Coordinator lock and release

The runtime has **no coordinator-lock primitive** — two terminals in one
worktree can each create runs unchecked. The lock is therefore a local
convention stored in `.dev-work/coordinator-lock.json`, written by
`scripts/bootstrap-project.ps1`, protecting one worktree when every
coordinator honors it.

Liveness has three states, probed through the recorded terminal handle:

| State | Test | Bootstrap behavior |
| --- | --- | --- |
| `live` | The terminal probe returns ok | Refuse: a live coordinator owns this worktree |
| `dead` | A handle is recorded and the probe fails | Warn, archive the old lock, take over |
| `unknown` | No handle, no runtime on PATH, or an unparsable response | Refuse — absence is not proof of the holder's death |

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
structural side of this design — routing chain monotonicity, role/skill path
existence, the 17-section entry outline, Claude-only content, encoding, and
negative evidence mutations — so the package can be verified without a
runtime.
