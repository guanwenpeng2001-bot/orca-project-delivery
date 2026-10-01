---
name: orca-project-delivery
description: Coordinate software delivery in Orca from intake through dynamic reconnaissance, planning, isolated implementation, independent review, direct integration into the agreed delivery branch, final verification, degradation handling, and cleanup. Coordinator-only; do not invoke from a worker dispatch.
---

# Orca Project Delivery

## Purpose

This is the single coordinator entry point for multi-agent project delivery.

It defines the business workflow. It does **not** replace Orca's global `orchestration`, `orca-cli`, or `orca-per-workspace-env` skills. Load those skills whenever current Orca commands, lifecycle rules, worktree operations, or environment behavior are needed.

## Coordinator-only guard

Do not run this skill when the current session is an Orca worker carrying a dispatch preamble, unless the Task explicitly authorizes nested coordination.

A normal worker must execute only its assigned Task, Role, Skills, branch contract, report contract, and Worker Contract.

## System boundaries

- `AGENTS.md`: project-local policy for coordinator and workers.
- `.dev-work/`: coordinator-owned process state, reports, decisions, and evidence.
- Git: source, branches, commits, and integration truth.
- Orca Runtime: Run, Task, Dispatch, Worker, Message, Gate, and lifecycle truth.
- This skill: workflow, routing, Role selection, Skill selection, Agent selection, degradation, and prompt assembly.

Never duplicate Orca lifecycle state inside `.dev-work/`; store only identifiers and business mappings.

## Required invariants

1. One coordinator control workspace per project.
2. One active Coordinator Agent in that workspace.
3. The coordinator control branch is not a development or integration branch.
4. Every run has one `delivery_branch`: user-specified (`-DeliveryBranch`); otherwise the repository default branch, resolved as `origin/HEAD` → `init.defaultBranch` → `main` → `master` → the current branch, recorded in run-state with its source. A repository whose default branch is none of these must state it explicitly; the resolution never silently makes the control branch the delivery branch.
5. Every worker Task uses an isolated branch and worktree.
6. One task branch has one writer at a time.
7. All process artifacts end in the coordinator's `.dev-work/`.
8. Worker worktrees do not create their own `.dev-work/`.
9. Reviewed source changes merge directly into `delivery_branch`.
10. Final verification runs from a fresh worktree based on the latest `delivery_branch`.
11. Existing `AGENTS.md` is preserved and appended last to worker input.
12. Agent, model, effort, permissions, Skill delivery, and fallbacks are recorded as requested and effective values.
13. A fallback never creates a concurrent second writer.
14. Empty waits or unverifiable observations do not prove failure, quota exhaustion, or process exit.
15. Current Orca skills and `--help` remain authoritative for commands.

## Bootstrap

At coordinator start:

1. Locate the coordinator control worktree root.
2. Refuse a second live coordinator according to `references/coordinator-lock.md`.
3. If `AGENTS.md` is absent, create it from `templates/AGENTS.md`; otherwise preserve it unchanged.
4. If `.dev-work/` is absent, initialize it with `scripts/bootstrap-project.ps1`; the files in
   `templates/dev-work/` are schema-validated references for what the script writes, not copies.
   If it already exists, validate and reuse it.
5. Add `/AGENTS.md` and `/.dev-work/` to the local Git exclude file unless the user explicitly tracks them.
6. Resolve the run's `delivery_branch`:
   - an explicit branch (`-DeliveryBranch`, on bootstrap and on `create-run`);
   - otherwise `origin/HEAD`, then `init.defaultBranch`, then `main`, then `master`, then the
     current branch — recorded with the source that produced it.
   A repository whose default branch is none of these must be given explicitly; if the resolved
   branch is the one already checked out, stop and pass `-DeliveryBranch` rather than waiving the
   guard. The control branch must differ from `delivery_branch` (invariant 3). Choose the control
   branch **before** bootstrapping: `scripts/bootstrap-project.ps1` refuses a worktree whose
   current branch is the resolved delivery branch unless `-AllowControlEqualsDelivery` is passed
   deliberately.
7. Create or resume a `.dev-work/runs/<run-slug>/` record.
8. Create or bind an Orca Run through the global `orchestration` skill.
9. Probe relevant Agent backends before automatic routing.
10. Record the active coordinator, delivery branch, Orca Run id, and schema versions.

Use `scripts/bootstrap-project.ps1` to initialize the control worktree (it refuses a
detached HEAD, a second live coordinator whose lock is still `active`, and a control branch equal
to the resolved delivery branch unless `-AllowControlEqualsDelivery` is passed deliberately; an
existing lock that is already `released` is archived and taken over; pass
`-DeliveryBranch <branch>` whenever the repository default branch is not `main`/`master`), `scripts/probe-agent-capabilities.ps1` to
probe agent backends and model/effort evidence, `scripts/create-run.ps1` to create the run
record (it archives prior state when `-Force` reuses a run), `scripts/assemble-task.ps1`
to build a worker assignment from a Task Definition, `scripts/validate-run.ps1` to check
documents against `schemas/` plus the run invariants, `scripts/reconcile-state.ps1` to
compare assignments with Git, and `scripts/release-coordinator.ps1 -ConfirmRunClosed` to
clear the active run and lock safely.

## Workflow selection

Choose one workflow from `workflows/`:

- `feature-development.md`
- `bug-fix.md`
- `refactor.md`
- `audit.md`

The workflows are adaptive, not mandatory fixed pipelines.

A small, clear, low-risk change may go directly from intake to implementation and independent review. A large or high-risk change may require dynamic reconnaissance, product analysis, several independent plans, adjudication, architecture, staged implementation, and repeated verification.

Use `routing/workflow-selection.json`.

## Dynamic reconnaissance

Do not mechanically launch a fixed list of scouts.

Before planning, ask:

> Which unknown facts could materially change the solution, scope, risk, or acceptance decision?

Create one isolated Scout Task per independent information domain. Possible sources include:

- current `delivery_branch` code and call paths;
- Git diff and history;
- prior `.dev-work` records;
- issue and pull-request history;
- official documentation;
- dependency source;
- logs and failure samples;
- schemas and data;
- configuration and deployment;
- UI behavior;
- tests;
- user feedback;
- performance or security evidence.

Stop reconnaissance when the remaining unknowns are unlikely to alter the selected approach, or are explicitly recorded as unverifiable.

## Role and Skill routing

For every Task:

1. Select exactly one Primary Role from `roles/catalog.json` (deliverable routing rules: `routing/role-selection.json`).
2. Select 1–3 required professional Skills (`routing/skill-catalog.json` lists the 16 available sibling Skills; selection rules: `routing/skill-selection.json`).
3. Add at most 0–2 conditional Skills for material risk.
4. Derive capability, permission, branch, input, output, and completion requirements.
5. Select an Agent Runtime Profile (`routing/agent-selection.json` holds the role→profile table; `agents/role-compatibility.json` mirrors it and `scripts/validate-run.ps1` fails if the two drift).
6. Assemble the worker input according to `adapters/prompt-delivery.md`.

Role answers **who the worker is**.  
Skill answers **how the worker works**.  
Task answers **what this attempt must do**.

Do not give one Task conflicting roles. Split product design, implementation, and independent review into separate Tasks.

## Agent routing

Read:

- `agents/registry.json`
- `agents/configured-profiles.json`
- `agents/role-compatibility.json`
- `agents/fallback-policy.json`
- `agents/permission-presets.json`
- `agents/skill-loading.json`

Routing sequence:

1. User-pinned Agent/model, if any.
2. Run-level override.
3. Project-level `.dev-work/config/` override.
4. Configured default route for the Role and risk.
5. Eligible probed fallback profiles.
6. Pause for user decision when no candidate satisfies the Role floor.

Never auto-route to a backend whose CLI, runtime, authentication, model control, Skill delivery, or permission mode has not been validated for the current host.

## Model and effort control

Model control modes:

- `orca-launch-preferences`: use structured worker launch preferences supported by current Orca.
- `custom-terminal-args`: launch an exact CLI command, wait for readiness, then attach to supervision.
- `session-command`: select model/effort inside the Agent session and verify.
- `agent-config`: use the Agent's own configuration and record available evidence.
- `unverified`: manual-only; no automatic routing or fallback.

Always record:

- requested Agent/model/effort;
- effective Agent/model/effort;
- how the effective value was verified;
- any mismatch or unverifiable field.

Do not claim requested values became effective without evidence.

`scripts/probe-agent-capabilities.ps1` writes the per-profile verdicts (`verified`,
`supportedEfforts`, `evidence`, `verificationPath`) to `.dev-work/runtime/model-capabilities.json`
and records the path as `probeEvidenceRef` in `agents/configured-profiles.json`. A profile
whose model or effort cannot be verified on this host stays manual — it is not eligible for
automatic routing.

## Skill delivery

Professional Skills live as sibling global skills under `.agents/skills`.

Skill delivery modes:

- `native`: the Agent discovers the canonical Skill root.
- `provider-alias`: Orca-managed provider path points to the canonical root.
- `explicit-path`: Task asks the Agent to read exact `SKILL.md` paths.
- `inline-extract`: coordinator includes only required sections and records source/hash.

Do not assume every supported Agent reads `.agents/skills`. Follow `agents/skill-loading.json` and `adapters/skill-delivery.md`.

## Task and branch creation

Every Scout, Auditor, Product, Planner, Architect, Implementer, Reviewer, Fixer, Merge Resolver, and Verifier Task receives its own branch and worktree.

Default base:

```text
task_base_branch = delivery_branch
```

Override only when:

- the user specifies a base;
- the Task reviews another branch;
- a true dependency has not yet entered `delivery_branch`;
- a historical state must be reproduced.

Prefer reviewing and merging completed prerequisites into `delivery_branch` before creating dependent implementation Tasks. Avoid deep branch chains.

## Worker input order

Use `templates/task-spec.md` and append sections in this order:

1. Task Objective
2. Primary Role
3. Required and conditional Skills
4. Inputs and dependencies
5. Allowed and forbidden scope
6. Branch and worktree contract
7. `.dev-work` report contract
8. Acceptance and tests
9. Orca Worker Contract
10. Applicable `AGENTS.md` content

`AGENTS.md` content is always last. Preserve existing files; do not silently rewrite project policy.

## Execution loop

Use the global `orchestration` skill to:

- create Tasks and dependencies;
- start supervised workers;
- deliver follow-up guidance;
- receive questions, escalations, and completion;
- verify authoritative attempt ownership;
- decide reuse, retain, release, stop, or abandon;
- clean up residual resources.

The coordinator remains active while workers run:

1. Consume and fully process messages before acknowledgement.
2. Answer worker questions.
3. Handle escalations.
4. Start newly ready Tasks.
5. Validate reports and Git state.
6. Trigger independent review.
7. Create fix Tasks from accepted findings.
8. Integrate reviewed source into `delivery_branch`.
9. Start final verification from the latest delivery branch.
10. Record each Task's machine-readable assignment under `runs/<run>/assignments/<task>.json`
    (shape: `templates/dev-work/assignment.json`) whenever the Task has a branch and a report path;
    the assembled `.md` brief alone leaves `reconcile-state.ps1` with nothing to compare against Git.

### Unobservable and failed receipts

- A non-zero `worker-start` receipt is not a failed attempt. Read `failedStage` and
  `residualResources`, classify it with `references/agent-failure-taxonomy.md`, and never
  re-dispatch from that evidence alone.
- `outcome_unknown`, `turn_start_unobserved`, an empty wait, and a timeout are unobserved, not
  failed. `unverifiable` liveness never authorizes stop, abandon, retry, or release.
- After three consecutive empty waits, enumerate the fleet and act on each row's attention
  categories and its literal `nextAction`; use `worker-read` for bounded inspection instead of
  screenshots. Current syntax lives in the global `orchestration` skill.
- Release is post-settlement cleanup. A worker terminal that stays `retained` or `user_owned` is a
  recorded decision, not a leak; removing its worktree orphans it, so close it explicitly.

### Decisions and ordering

- Encode a user decision as an Orca decision gate so it suspends only the dependent Tasks, and
  resolve the gate once the user decides. The gate verbs live in the global `orchestration` skill.
- Express real ordering as a Task dependency at creation time; prefer parallel waves over chains
  deeper than three or four steps.

## Review and integration

Implementer self-review is not independent acceptance.

For source-producing Tasks:

1. Worker tests and reports.
2. Coordinator creates an independent review Task based on the implementation branch.
3. Reviewer reports `APPROVED`, `CHANGES_REQUIRED`, or `UNVERIFIABLE`.
4. Findings create separate fix Tasks; Reviewer does not edit the source.
5. After approval, merge the source branch directly into the worktree that has `delivery_branch`
   checked out. Orca exposes no merge primitive, so this is an explicit coordinator `git merge`,
   recorded together with the diff, the tests, and the process-artifact exclusion check.
6. Remove the task worktree and safe-to-delete branch only after integration or explicit abandonment.

Never merge source into the coordinator control branch.

After all intended source changes enter `delivery_branch`, create a separate final-verification worktree from its latest state.

## Degradation and handoff

Classify failures using `references/agent-failure-taxonomy.md`.

Recovery order:

1. Correct launch topology for the same Agent.
2. Retry a confirmed failed/stopped attempt when allowed, and only after confirming the previous
   attempt is not still writing.
3. Use another model/effort on the same Agent.
4. Use another Agent profile in the same capability tier — same provider only, unless the user
   authorized cross-provider fallback for this run (`allowCrossProviderFallback`).
5. Use a lower tier only if the Role floor still passes.
6. Pause for user decision when the user pinned the unavailable choice, when crossing providers
   would be required without authorization, or when no eligible candidate remains.

A writing Worker may be replaced only after:

- the original worker is confirmed stopped, failed, fenced, or explicitly handed off;
- Git status, diff, commits, and untracked files are captured;
- a handoff report is written;
- the old worker is released or otherwise settled;
- the new worker starts sequentially.

For read-only Tasks, preserve each attempt under a unique report path and let the coordinator synthesize the final report.

## Completion

A run closes only when:

- required Tasks are settled;
- accepted source is integrated into `delivery_branch`;
- final verification is complete or explicitly marked unverifiable;
- process reports and decisions are stored;
- no reclaimable worker resources remain: `worker-list --terminal-state reclaimable` returns none.
  A worker terminal that stays `retained` or `user_owned` is a recorded decision, not a leak;
- `final-report.md` and a separate user-decision report are written;
- active run and coordinator lock are cleared safely with `scripts/release-coordinator.ps1 -ConfirmRunClosed`.

Keep `.dev-work/runs/<run>/` as local history.

## Do not do

- Do not treat the coordinator branch as an integration branch.
- Do not create `.dev-work/` inside worker worktrees.
- Do not run multiple writers on one task branch.
- Do not copy stale Orca commands into this skill.
- Do not hard-code a model as effective without probing or runtime evidence.
- Do not assume all Agents discover global Skills.
- Do not trigger cross-Agent fallback when the user fixed the provider without permission.
- Do not equate silence, timeout, or unverifiable output with quota exhaustion.
- Do not re-dispatch a Task because a `worker-start` receipt was unobserved or a wait came back
  empty.
- Do not treat a retained or user-owned worker terminal as a failed release, and do not leave an
  orphaned terminal behind after removing its worktree.
- Do not merge process artifacts into the delivery branch.
