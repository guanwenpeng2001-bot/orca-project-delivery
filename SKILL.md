---
name: orca-project-delivery
description: 以 Claude Code 为唯一 Worker 的 Orca 项目交付协调：intake、动态侦察、fable 方案、sonnet 实施、opus 独立审查、合入 delivery_branch、最终验证、降级与收尾。仅协调者使用；worker 派发中不得调用。
---

# Orca Project Delivery

## Purpose

This is the single coordinator entry point for project delivery with Claude Code workers.
It defines the business workflow; it does not replace the global `orchestration`, `orca-cli`, or `orca-per-workspace-env` skills.
Before any orchestration verb, load the installed global Skill and consult current `--help`; `references/orca-runtime.md` provides only business-to-runtime mappings.
For installation or upgrade, read `references/installation.md`; for configuration conflicts, read `references/configuration-precedence.md`.

## Coordinator-only guard

A worker carrying a dispatch preamble must not run this Skill unless its Task explicitly authorizes nested coordination.
Normal workers execute only their assigned Task, Role, professional Skills, branch/report contracts, and injected Worker Contract.

## System boundaries

- `AGENTS.md`: project-local policy, preserved and appended last to worker input.
- `.dev-work/`: process state, reports, decisions and evidence, physically only in the coordinator control tree.
- Git: source, branches, commits and integration truth.
- Orca Runtime: Run, Task, Dispatch, Worker, Message, Gate and lifecycle truth.
- This Skill: workflow, role/Skill/model routing, degradation and input assembly.
Only the coordinator edits global process state; workers write only their assigned report paths. Store runtime identifiers and business mappings, never a second lifecycle database.
When unsure where an artifact belongs, read `references/artifact-model.md`.

## Required invariants

1. Every Task, including read-only work, has an isolated branch and worktree.
2. One task branch has one writer at a time; replacement never creates a concurrent writer.
3. Self-check is not independent review; reviewers do not edit source; findings require fix Tasks and re-review.
4. Silence, empty waits and unverifiable observations do not prove failure, quota exhaustion or process exit.
5. Each run has one `delivery_branch`: explicit user choice, otherwise `origin/HEAD` → existing `init.defaultBranch` → `main` → `master` → current branch; record the source and integrate directly there.
6. `.dev-work/` exists only in the control tree; its global state belongs to the coordinator, not workers or a duplicate runtime database.
7. One active coordinator holds the control-tree lock; use live/dead/unknown evidence, release by marking, never delete the lock or use orchestration reset.
8. Record requested and effective values separately; only the first launch receipt proves effective values.
9. Installed global Orca Skills and current help govern commands; do not embed stale command lines.
10. Process artifacts never enter `delivery_branch`; inspect Git status and diff before commit or merge.
11. The control branch is neither development nor integration source; its HEAD may lag and is not current delivery evidence.
12. Review the actual implementation baseline; final verification uses a clean worktree from the latest `delivery_branch`, marking unverifiable evidence explicitly.

## Bootstrap

1. Locate the coordinator control worktree; read `references/coordinator-lock.md` at bootstrap or whenever a second coordinator is suspected.
2. Refuse a second live coordinator; preserve unknown liveness for investigation instead of taking over.
3. Preserve existing `AGENTS.md`; only when absent create it from `templates/AGENTS.md`.
4. Initialize missing `.dev-work/` using `scripts/bootstrap-project.ps1`; otherwise validate and reuse it. Templates are schema references, not copies to overwrite state with.
5. Locally exclude `/AGENTS.md` and `/.dev-work/` from Git unless the user explicitly tracks them.
6. Resolve and record `delivery_branch` and its source using the invariant's chain; choose a distinct control branch before bootstrap. Detached HEAD and control=delivery are refused. The explicit override acknowledges a violation, not a normal integration path.
7. Create or resume a run record using `scripts/create-run.ps1`; forced reuse archives prior state.
8. Create or bind the Orca Run using current global Skill instructions.
9. Run `scripts/probe-claude-capabilities.ps1` at bootstrap or after changing hosts; inspect the JSON and warnings, not merely its exit code.
10. Record the coordinator, delivery branch, Orca Run id, schema versions and probe evidence in the control tree.

The probe writes `.dev-work/runtime/claude-capabilities.json`; `accepted` proves only parameter acceptance, never actual model/effort effectiveness.
Any `launched` verdict is an abnormal sentinel launch: stop probing and dispatch, mark unverified, inspect residual resources and escalate immediately. Exit 0 does not override this stop.
Missing/unusable Claude CLI or unreadable routing is a hard failure; missing Orca produces unknown combinations. Unknown/rejected combinations are not verified routes; investigate before automatic routing.
Use `scripts/assemble-task.ps1` to assemble definitions, `scripts/validate-run.ps1` for schemas and invariants, and `scripts/reconcile-state.ps1` to compare assignments with Git.
Use `scripts/verify-package.ps1` for offline package acceptance and `scripts/release-coordinator.ps1 -ConfirmRunClosed` for safe closure.

## Workflow selection

Select `feature-development`, `bug-fix`, `refactor`, or `audit` using `routing/workflow-selection.json` and the corresponding file in `workflows/`.
- Lightweight: intake → implementation → independent review → final verification.
- Standard: intake → reconnaissance → plan → task graph → implementation → review → final verification.
- High risk: parallel reconnaissance/audit → independent plans → adjudication → architecture → staged implementation and review loops → final verification.
Record scale in run-state/decisions; upgrade as evidence warrants, and record reasons for reducing scale. Workflows adapt to the problem.

## Dynamic reconnaissance

Do not launch a fixed list of scouts. Ask: **Which unknown facts could materially change the solution, scope, risk, or acceptance decision?**
Create one isolated Scout Task per independent information domain, in parallel where possible:
- current delivery code and call paths; Git diff and history;
- prior process records; issue and pull-request history;
- official documentation and dependency source;
- logs, failure samples, schemas and data;
- configuration, deployment, UI behavior and tests;
- user feedback, performance and security evidence.
Stop when remaining unknowns cannot change the approach, or explicitly record them as unverifiable.

## Role and Skill routing

1. Select exactly one Primary Role from `roles/catalog.json`, by deliverable using `routing/role-selection.json`.
2. Select 1–3 required Skills from the 16 in `routing/skill-catalog.json`, following `routing/skill-selection.json`.
3. Add 0–2 conditional Skills only for material risk.
4. Derive capability, permission, scope, branch, input, output and completion contracts from the role and Task.
5. Choose the role's model/effort route, then assemble the input.
Role defines identity, Skill defines method, and Task defines this attempt's objective. Split conflicting design, implementation and independent-review identities into separate Tasks.

## Model and effort routing

All workers use Claude Code: haiku for reconnaissance, fable for planning/adjudication, sonnet for implementation, opus for independent review/verification.
The sole routing authority is `routing/model-routing.json`: select the role's `chain`, start at `default`, never go below `floor`.
Dispatch through `worker-start` with `--agent claude` and the selected `--model` / `--effort`; obtain exact syntax from installed help, not a copied command line.
Use the tier's request shape. Haiku prefers `claude-haiku-4-5` plus effort; on parameter rejection or first receipt mismatch, use alias `haiku` without effort and record the degradation, unless the user pinned the choice.
A pinned model or effort forbids automatic changes, including the haiku fallback: suspend the affected Task and ask the user if rejected or mismatched.
On every dispatch, write `runs/<run>/assignments/<task>.json`, even when an assembled Markdown brief exists:
- `runtime.requested`: literal agent/model/effort sent to Orca;
- `runtime.effective`: only values from the first `launch.effective` receipt; unknown fields are null;
- `runtime.verification.status`: `verified`, `mismatch`, or `unverified`, with evidence;
- permission mode, Skill delivery, Task/Dispatch, branch/worktree/report paths and top-level `fallbackReason`.
Parameter acceptance does not prove effectiveness; reconcile mismatches before treating the requested route as verified.
The coordinator model is outside routing: do not choose, probe or validate it. Only record a user-reported value in `run-state.coordinatorModelReported`.
Upgrade, downgrade, suspension, trivial read-only adjustment and user-pinned behavior follow this file's `policies`; do not recreate route tables in workflow or role files.
`worker-start` has no permission flag; permission comes from actual Claude configuration and user Orca settings, which must be recorded rather than invented.

## Skill delivery

Professional Skills are sibling global directories under `.agents/skills`.
- `explicit-path` is the default: give the absolute `SKILL.md` path in the Task and require reading it.
- `inline-extract` is the fallback: include the required sections and record source path and hash.
A Skill name alone is not loading evidence. Skills supply method and cannot expand Task scope or grant orchestration control.

## Task and branch creation

Read `references/branch-model.md` before choosing a branch or baseline.
Every Task, including scout, audit, review and verification, receives its own branch/worktree; default base is `delivery_branch`.
Override only for an explicit user base, a review of another branch, a true unintegrated prerequisite, or historical reproduction; record the reason.
Prefer reviewing and merging prerequisites before creating dependent implementation Tasks. Encode only true dependencies; use parallel waves and avoid chains deeper than 3–4 steps.
Workers commit authorized source changes on their task branches before reporting and never merge their own branches.

## Worker input order

Use `templates/task-spec.md`; `assemble-task` automatically inlines the role and worker-contract reference.
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
Preserve project policy verbatim; `AGENTS.md` is always last.

## Execution loop

1. Intake: record objective, scale, delivery branch, user-pinned choices and side-effect boundaries in run-state.
2. Reconnaissance: dispatch independent information domains as needed; stop when unknowns cease to affect the solution.
3. Plan: use solution-planner, multiple plans plus plan-adjudicator when needed; resolve real product ambiguity with requirements-analyst first.
4. Task graph: write task-definition and assemble input; record machine-readable assignments, true dependencies and parallel waves.
5. Dispatch all ready Tasks; verify the first `launch.effective` receipt and fill assignment runtime evidence.
6. Wait using `check --wait`; process every question/escalation, confirm worker_done belongs to the active Dispatch, decide the terminal's next owner, then acknowledge.
7. After three consecutive empty waits, enumerate using `worker-list` and act on `projection.nextAction`; use bounded `worker-read` inspection where needed.
8. Review completed source Tasks independently, based on the implementation branch.
9. Convert accepted findings into fix Tasks and re-review until resolved or explicitly unverifiable.
10. Integrate approved source by explicit Git merge in the delivery worktree; record diff/tests/artifact exclusions, then reclaim eligible task worktrees.
11. Verify the latest delivery state in a clean worktree with release-verifier; write reports, summarize user decisions, settle workers and release the coordinator.

A nonzero start receipt alone does not prove a failed attempt: inspect `failedStage` and `residualResources` using `references/failure-taxonomy.md`.
`outcome_unknown`, `turn_start_unobserved`, timeouts and unverifiable liveness do not authorize stop, abandon, retry or release.
User decisions use decision gates suspending only dependent Tasks; independent work proceeds. Resolve gates after the user decides.
Release is post-settlement cleanup. Record `retained` or `user_owned` decisions; explicitly resolve terminal ownership before removing its worktree.

## Review and integration

Implementer self-check does not replace independent acceptance. Reviewers report `APPROVED`, `CHANGES_REQUIRED`, or `UNVERIFIABLE` and never edit source.
Findings become separate fix Tasks followed by re-review; unclear evidence remains explicitly unverifiable.
After approval, the coordinator explicitly runs Git merge in the actual worktree with `delivery_branch` checked out; Orca has no merge primitive.
Record the baseline, diff, tests, Git status and exclusion of all process artifacts. Never integrate through the control branch or treat its HEAD as delivery evidence.
Remove task worktrees and safe-to-delete branches only after integration or explicit abandonment and terminal ownership resolution.
After all intended changes are integrated, create final verification from the latest delivery branch in a clean worktree; do not reuse stale test claims.

## Degradation and handoff

Before any failure recovery, abnormal-receipt action or route change, read `references/failure-taxonomy.md`; use `model-routing.json` policies without inventing extra fallback routes.
Escalation follows the chain for demonstrated complexity or quality shortfalls. Explicit rate limiting allows at most two same-tier backoff retries; quota/model unavailability excludes that tier before searching leftward above floor.
No available route above floor, an unavailable pinned choice, or repeated same-class failures reaching the circuit breaker (at most three recommended) suspends only the affected Task.
Record time, Task/Dispatch, classification, evidence, original route and action in `degradation-events.json`; summarize pending decisions for the user.
Authentication failures require diagnosis; silence and unknown observations do not trigger downgrades.
Before replacing a writing worker, read `references/worker-handoff.md`: confirm stop/failure/fencing or explicit handoff, preserve Git status/diff/commits/untracked files, write handoff, settle the old attempt, then start its replacement sequentially.
For read-only retries, preserve each attempt under a unique report path; the coordinator synthesizes the result.

## Completion

Close only after required Tasks settle, accepted source enters delivery, final verification completes or is explicitly marked unverifiable, and reports/decisions are stored.
Ensure the fleet has zero reclaimable resources; `retained`/`user_owned` terminals require recorded ownership decisions and are not leaks.
Write `final-report.md` plus a separate user-decision report: what needs deciding, consequence of deferral, options and recommendation.
Recheck status/diff for process-artifact exclusion, then use `scripts/release-coordinator.ps1 -ConfirmRunClosed`; it archives active state and marks the lock released.
Keep `.dev-work/runs/<run>/` as local history. Unverifiable acceptance must not be described as READY.

## Do not do

- Do not use the control branch as development, integration or final-verification source.
- Do not create `.dev-work/` in worker worktrees.
- Do not run concurrent writers on one task branch.
- Do not copy stale Orca command lines instead of reading current global Skills/help.
- Do not treat requested or parameter-accepted values as effective.
- Do not interpret silence, timeout or unverifiable output as quota exhaustion.
- Do not treat retained/user-owned terminals as leaks or orphan them by deleting their worktrees.
- Do not commit or merge process artifacts into delivery.
- Do not re-dispatch because a receipt was unobserved or a wait was empty.
- Do not delete coordinator locks to bypass release or use orchestration reset.
