# Usage

**English** | [简体中文](zh-CN/usage.md)

Use the [installed external Skill walkthrough](external-skills.md) for version 2 project registration, mixed bindings, resolved requirement selectors and original sibling resources. No separate installation is required for bundled Skills.

This walkthrough shows one complete delivery from the coordinator's seat. It
summarizes the workflow defined in `SKILL.md` and its references; the Skill
itself is the authority at runtime, and the installed global `orchestration`
Skill plus current `--help` output are the authority for every Orca command.

This guide targets 4.0.0: **69 Skills, 18 Roles, 5 workflows**. Select
only the methods needed by the Task: shared tokens use `design-system`, domain
invariants use `domain-modeling`, upgrades use `migration-upgrade`, and tool
protocols use `mcp-server-development`. Diagrams, localization, Skill evaluation
and subtitle conversion have dedicated Skills. See the [capability guide](professional-capabilities.md)
and [offline tutorial](professional-capability-tutorial.md) for inputs, commands,
and verification limits. Loading a Skill does not create a Role or expand authority; the two game Roles are explicitly registered.

## Game-development delivery

Choose [game-development](../workflows/game-development.md) when developing a game or game feature. Intake records target platforms, engine or selection-needed, genre, IAA/IAP/both/none, and novice/veteran familiarity. These probes select Skills and beginner versus core-method chapters for each brief. Game design is mandatory; upgrade light depth to standard. `game-designer` produces gameplay, applicable level/3C and economy specifications (economy is mandatory for IAA/IAP).

Run gameplay implementation (`software-implementer`) and asset production (`media-producer`) in parallel once their real design dependencies settle; monetization implementation depends on economy design. `game-test-engineer` applies smoke, story, regression, soak, real-device and certification checks, then checks `game-publishing` platform and applicable China compliance lists for every release before final verification. Final verification still belongs to `release-verifier`; successful completion supplies a `game-live-ops` handoff. Engine/platform operations stay in project-side guidance and external Skills, and publication needs explicit authorization.

## Starting a delivery (coordinator entry)

You run the Skill from a **coordinator control worktree** — a checkout of the
project on a control branch that is *not* the delivery branch. One worktree
hosts one coordinator; the control worktree never develops or integrates
source.

Bootstrap sequence (from `SKILL.md`):

1. Locate the coordinator control worktree. If a second coordinator is
   suspected, apply `references/coordinator-lock.md` before anything else: a
   live coordinator is refused, an unknown lock state is preserved for
   investigation, never bypassed.
2. Preserve an existing project `AGENTS.md`; only create one from
   `templates/AGENTS.md` when absent.
3. Initialize or validate `.dev-work/` with `scripts/bootstrap-project.ps1`.
   The script resolves and records the delivery branch, writes the
   coordinator lock, and refuses to run on the delivery branch itself.
4. Bootstrap preserves existing `.env.example` and `project-config.example.json`, creating missing examples only; it excludes `/AGENTS.md`, `/.dev-work/` and `/.env` through local Git `info/exclude`, shared across the clone's worktrees.
5. Create or resume the run record with `scripts/create-run.ps1`, then create
   or bind the Orca Run.
6. Select an Orca-supported Agent configured and usable on the execution host; do not probe models or effort.
7. Record the coordinator, delivery branch and Orca Run id in the control tree.

To start from a coordinator session, explicitly ask it to read
`~/.agents/skills/orca-project-delivery/SKILL.md` and give the objective,
delivery branch, scope, and acceptance criteria. For example:

```text
Use the installed orca-project-delivery Skill as coordinator.
Deliver a validated configuration change into main.
Inspect the repository to determine the exact scope and tests, use isolated
Tasks, and obtain independent review before integration.
```

These package-script examples are for the coordinator. Replace `<project>`
with its control worktree, already on a distinct control branch. These
commands do not dispatch workers or create the Orca Run:

```powershell
$package = Join-Path $env:USERPROFILE '.agents/skills/orca-project-delivery'
pwsh -NoProfile -File "$package/scripts/bootstrap-project.ps1" -ProjectRoot '<project>' -DeliveryBranch main
pwsh -NoProfile -File "$package/scripts/create-run.ps1" -ProjectRoot '<project>' -Objective 'Validate configuration behavior' -Workflow feature-development -RunSlug configuration-validation -DeliveryBranch main
```

Bind the actual Orca Run through the installed global Skill and record that
binding. Never copy template placeholders into live records as observations.

## The delivery, end to end

The stage order for a standard run:

```text
intake -> reconnaissance -> design (conditional, verdict recorded) -> plan -> task graph -> dispatch
       -> wait & process -> review -> integration -> final verification -> close
```

### 1. Intake

Record in run-state: the objective, the scale, the delivery branch, any
user-pinned Agent/model choices, and side-effect boundaries. Choose the
workflow (`feature-development`, `game-development`, `bug-fix`, `refactor`, or `audit`) with
`routing/workflow-selection.json`, and the depth — light, standard, or
high-risk — recording the reasons if you reduce scale. After reconnaissance,
record the design verdict (`required` or `skipped`), with reason and evidence,
in run-state `stageDecisions.design` before planning.

### 2. Reconnaissance

Do not launch a fixed list of scouts. Ask: *which unknown facts could
materially change the solution, scope, risk, or acceptance decision?* Create
one isolated Scout Task per independent information domain, in parallel —
current code and call paths, prior process records, official documentation,
logs and failure samples, configuration and deployment behavior, user
feedback. Stop when remaining unknowns cannot change the approach, or record
them explicitly as unverifiable.

### 3. Plan

When the design stage ran, its output is planning's input.

Use the Solution Planner role. When alternatives or risk are material,
dispatch independent planner Tasks with isolated contexts and a Plan
Adjudicator to decide. Resolve genuine product ambiguity with a Requirements
Analyst first.

### 4. Task graph

Write a task definition per Task and assemble its input with
`scripts/assemble-task.ps1`. Each Task carries: one Primary Role, required
(and optionally conditional) Skills, allowed and forbidden scope, a branch
and worktree contract, a `.dev-work` report path, acceptance criteria, and
the Orca Worker Contract. Record the machine-readable assignment under
`runs/<run>/assignments/<task>.json` — including the requested and effective
runtime values — even when a Markdown brief exists. Encode only true
dependencies; use parallel waves and avoid chains deeper than 3–4 steps.

Assembly checks every acceptance/tests command against the real package
scripts and their declared parameters and fails without writing a brief when
a command cannot run. Review briefs take optional `reviewInput.deltaPaths`
(scaling re-verification by the delta) and `reviewInput.coordinatorEvidence`
(coordinator-precomputed mechanical checks the reviewer audits instead of
re-running); standard briefs name the minimum
relevant suites, with full gates at post-merge and final. Named suites run as
`scripts/verify-package.ps1 -Suites '<name>'`; prerequisites are added automatically.
`-SuiteTimeoutSeconds` budgets only the package runtime suite's child processes; other
checks use a 60-second per-child default.

Bundled professional Skills resolve from this package's `skills/<skill-id>/SKILL.md`.
External Skills require explicit registration in version 2 project config; see
[External Skills](external-skills.md). Assembly delivers resolved paths (`explicit-path`)
or inlines the same bodies (`inline-extract`). A missing bundled file fails at assembly
without silently falling back to sibling installations under `~/.agents/skills`.
Bundled provenance is documented in
`skills/README.md`. See [professional-skills.md](professional-skills.md),
[professional-capabilities.md](professional-capabilities.md), and
[installation.md](installation.md). A walkthrough that checks the install and runs
local tools and dependency helpers without calling a provider is in
[professional-capability-tutorial.md](professional-capability-tutorial.md).

Assembly places catalog `requires` names/purposes under Inputs and Dependencies, separating Role plus required-Skill dependencies from conditional Skills. Conditional dependencies activate only when the Task calls for them. On the execution host, run `check-requirements.ps1` with explicit `-ProjectRoot`, `-Role`, and an in-session `-Skills @(...)` array of selected IDs. Helpers do not select Role defaults for you. File configuration does not mean the current shell has those values; an authorized child can receive selected file additions through `invoke-with-requirements.ps1`, preserving its parent's environment. See [Extending and configuration](extending.md) for exact interfaces and an offline walkthrough. The ten-part Task order and applicable `AGENTS.md` last are unchanged.

### 5. Dispatch

A Task is **ready** when its real dependencies have settled successfully
through their gates — a source dependency counts only after its own review
*and* integration, never on `worker_done` alone — its write scope is disjoint
from in-flight Tasks, and its baseline and Agent are usable. Dispatch ready
Tasks immediately (rolling dispatch); do not hold a batch barrier for
unrelated in-flight work.

Every dispatch goes through the runtime's worker-start verb with a usable Agent and no model/effort flags by default. Permission comes from the selected Agent configuration and user Orca settings; record it rather than inventing a permission flag.

Record the dispatch with `scripts/dispatch-task.ps1` from the
coordinator-captured `worker-start --json` receipt (`-ReceiptPath`): it
derives the requested/effective verification, refuses a receipt whose
worktree effect lands on the coordinator control worktree or contradicts the
task definition, and refuses a duplicate live dispatch of the same Task
unless `-ForceReDispatch` records the earlier dispatch under
`runtime.previousDispatches`. Record
`runtime.mode` and the terminal `surface`; a background (`structured`)
worker is a background session, and the next milestone report names it as
such.

Execution-loop and review/integration mechanics live in [Execution Loop](../references/execution-loop.md); read that reference before dispatching and processing workers.

### 6. Wait and process

Wait on the runtime's check verb; process every question and escalation.
Confirm each `worker_done` belongs to the active Dispatch before
acknowledging it, and decide each terminal's next owner. After each confirmed
settle, re-evaluate readiness and dispatch newly ready Tasks. After three
consecutive empty waits, enumerate workers and act on the projected next
action, using bounded worker reads where needed.

For a source Task whose `worker_done` is confirmed, advance the assignment to
`review`; the worker's report at the assignment's report path names the commit
under review.

### 7. Review

After a confirmed source `worker_done`, dispatch an independent review of the actual
implementation branch in an isolated worktree, in parallel with other
implementation. Reviewers report `APPROVED`, `CHANGES_REQUIRED`, or
`UNVERIFIABLE`, never edit source, and record the reviewed target as one observed
line. File completed review reports under `runs/<run>/reviews/`; the coordinator
re-checks the source HEAD itself before merging.
Accepted findings become fix Tasks followed by re-review.

### 8. Integration

After each approval, merge serially in the worktree that has `delivery_branch`
checked out (the runtime has no merge primitive — this is your `git merge`).
Immediately before merging, confirm the live source HEAD still equals the
approved commit and both source and delivery worktrees are clean; drift
requires re-review. Run the full verification suite at the integrated HEAD
before treating the source dependency as settled. On
conflict: abort, create an isolated resolution Task, review it independently,
and merge it under the same conditions.

Base Tasks created afterwards on the updated delivery branch, then reclaim
eligible worktrees.

### 9. Final verification

After **all** intended changes integrate, dispatch a release-verifier Task
against the latest delivery branch in a clean, independent worktree. Only its
passing result authorizes READY.
This barrier never moves earlier and is never skipped.

### 10. Close

Write the final report linked to the final-verification report, plus a separate
user-decision report for anything pending. Settle workers, ensure no
reclaimable resources remain, recheck that process artifacts never entered
the delivery branch, then release with
`scripts/release-coordinator.ps1 -ConfirmRunClosed`. Keep
`.dev-work/runs/<run>/` as local history.

## Choosing roles and Agents

Select exactly one Primary Role per Task by deliverable using `routing/role-selection.json`; select 1–3 required Skills following Role defaults and `routing/skill-selection.json`, plus 0–2 conditional Skills for material risk. Role defines responsibility, Skill defines method, Task defines a bounded objective, and Agent is the runtime executor.

Choose an Orca-supported Agent configured and usable on the execution host. Default launches pass only the Agent and omit model/effort so native Agent configuration decides. Forward only explicit user pins; if they cannot be honored, suspend the affected choice and ask the user without automatic substitution.

Native subagents may assist within a Task. The parent worker owns their scope, write isolation, results and cleanup; read-only helpers may share context, concurrent writers require isolated branches and worktrees. They create no extra project-level Orca Runs/Tasks and never replace independent review.

## Branch and worktree conventions

- Every top-level Orca Task — including read-only scout, audit, review, and verification
  work — gets its own branch and worktree. Default base is the delivery
  branch; record the reason for any other base.
- One task branch has one writer at a time. Replacing a writer requires
  evidence the old writer stopped (or is fenced, isolated, or handed off
  explicitly) plus a settled Dispatch and a preserved Git-state handoff.
- Workers commit authorized changes on their task branches before reporting
  and never merge their own branches.
- Read-only Tasks declare `branch.mergeTarget: null` in their assignments.
- Source merges happen only in the delivery worktree, serially, in
  dependency order, performed by the coordinator.

## Record and report locations

Everything process-side lives under the control worktree's `.dev-work/`:

| Artifact | Path (relative to `.dev-work/`) |
| --- | --- |
| Run state, decisions | `runs/<run>/run-state.json`, `runs/<run>/decisions.md` |
| Machine-readable assignments | `runs/<run>/assignments/<task>.json` |
| Worker reports | `runs/<run>/worker-reports/<task>.md` |
| Review reports | `runs/<run>/reviews/` |
| Final verification report | `runs/<run>/verification/` |
| Handoffs | `runs/<run>/handoffs/` |
| Degradation events | `runs/<run>/degradation-events.json` |
| Final report | `runs/<run>/final-report.md` |

Workers write only their own assigned report path; the coordinator
writes everything else.

## Reading worker receipts

On every dispatch, compare what you requested with what the runtime actually
launched:

- **requested** — the literal agent/model/effort you sent;
- **effective** — only the values from the **first** `worker-start` receipt's
  `launch.effective` block; anything you could not verify stays `null`;
- **verification** — `verified`, `mismatch`, or `unverified`, with evidence.

Record all three in the assignment's `runtime` block. Compare the requested Agent and explicit user model/effort pins only. Missing unrequested internal model/effort does not block a default dispatch. Parameter acceptance does not prove effectiveness; never claim an explicit pin was honored without matching effective evidence. A nonzero start
receipt alone does not prove a failed attempt — inspect `failedStage` and
residual resources using `references/failure-taxonomy.md`.

## Common usage questions

**How do I pick the workflow?**
Match the objective: defect correction → `bug-fix`; assessment/findings →
`audit`; behavior-preserving structure work → `refactor`; game or gameplay-feature development → `game-development`; other new or changed
behavior → `feature-development` (the default). Depth (light / standard /
high-risk) follows evidence; record reasons when reducing scale.

**How do I know a Task is ready to dispatch?**
Its real dependencies settled successfully through their gates (a source
dependency needs review *and* integration, not just `worker_done`), its write
scope is disjoint from in-flight Tasks, and its baseline and Agent are
usable. Dispatch ready Tasks as they become ready.

**What must I record on every dispatch?**
The assignment JSON with requested and effective runtime values, permission
mode, Skill delivery mode, Task/Dispatch ids, branch/worktree/report paths,
and any fallback reason — even when an assembled Markdown brief exists.

**When may I merge a reviewed branch?**
After the latest review is `APPROVED`, the
source HEAD still equals the approved SHA, and both source and delivery trees
are clean. Merge serially, in the delivery worktree, and run the full
verification suite at the integrated HEAD.

**What if a review returns CHANGES_REQUIRED?**
Convert accepted findings into fix Tasks (new branches, new writers), re-review
the fix, and renew admission. Reviewers never edit the source themselves.

**A worker sent a question or escalation mid-run. What now?**
Answer through the runtime's reply path so the worker resumes. If the answer
is a user decision, open a decision gate that suspends only the dependent
Tasks — independent work keeps moving.

**Can two Tasks write the same files?**
No. Ready-Task dispatch requires disjoint write scopes; conflicting needs are
sequenced through real dependencies instead.

**How do I finish?**
Final verification passing on a clean worktree from the latest delivery branch,
reports written, workers settled,
process artifacts confirmed absent from the delivery branch, then
`scripts/release-coordinator.ps1 -ConfirmRunClosed`.
