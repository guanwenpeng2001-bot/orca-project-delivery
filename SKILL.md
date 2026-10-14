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

- `AGENTS.md`: project-local policy; applicable sections are preserved verbatim, always last in worker input.
- `.dev-work/`: process state, reports, decisions and evidence, physically only in the coordinator control tree.
- Git: source, branches, commits and integration truth.
- Orca Runtime: Run, Task, Dispatch, Worker, Message, Gate and lifecycle truth.
- This Skill: workflow, role/Skill/model routing, degradation and input assembly.
Only the coordinator edits global process state; workers write only their assigned report paths. Store runtime identifiers and business mappings, never a second lifecycle database.
When unsure where an artifact belongs, read `references/artifact-model.md`.

## Required invariants

1. **Task isolation:** Every Task, including read-only work, has an isolated branch and worktree.
2. **Single writer:** One task branch has one writer at a time; replacement never creates a concurrent writer.
3. **Independent review:** Self-check is not independent review; reviewers do not edit source; findings require fix Tasks and re-review.
4. **Positive evidence:** Silence, empty waits and unverifiable observations do not prove failure, quota exhaustion or process exit.
5. **Delivery target:** Each run has one `delivery_branch`: explicit user choice, otherwise `origin/HEAD` → existing `init.defaultBranch` → `main` → `master` → current branch; record the source and integrate directly there.
6. **Process ownership:** `.dev-work/` exists only in the control tree; its global state belongs to the coordinator, not workers or a duplicate runtime database.
7. **Coordinator lock:** One active coordinator holds the control-tree lock; use live/dead/unknown evidence, release by marking, never delete the lock or use orchestration reset.
8. **Effective receipt:** Record requested and effective values separately; only the first launch receipt proves effective values.
9. **Runtime authority:** Installed global Orca Skills and current help govern commands; do not embed stale command lines.
10. **Artifact exclusion:** Process artifacts never enter `delivery_branch`; inspect Git status and diff before commit or merge.
11. **Control separation:** The control branch is neither development nor integration source; its HEAD may lag and is not current delivery evidence.
12. **Current verification:** Review the actual implementation baseline; final verification is a global barrier after all intended integrations, never earlier or skipped, using a clean independent worktree from latest `delivery_branch`. Mark unverifiable evidence explicitly; stale test claims cannot substitute.

## Bootstrap

1. Locate the coordinator control worktree; read `references/coordinator-lock.md` at bootstrap or whenever a second coordinator is suspected.
2. Refuse a second live coordinator; preserve unknown liveness for investigation instead of taking over.
3. Preserve existing `AGENTS.md`; only when absent create it from `templates/AGENTS.md`.
4. Initialize missing `.dev-work/` using `scripts/bootstrap-project.ps1`; otherwise validate and reuse it. Templates are schema references, not copies to overwrite state with.
5. Bootstrap preserves existing `.env.example` and `project-config.example.json`, creating only missing examples; locally excludes `/AGENTS.md`, `/.dev-work/` and `/.env` through clone-shared `info/exclude`.
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
- Standard: intake → reconnaissance → design (conditional; verdict recorded either way) → plan → task graph → implementation → review → final verification.
- High risk: parallel reconnaissance/audit → design (conditional; verdict recorded either way) → independent plans → adjudication → staged implementation and review loops → final verification.
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
2. Select 1–3 required Skills from `routing/skill-catalog.json` or explicit project external registrations, following effective Role defaults and `routing/skill-selection.json`; explain irrelevant defaults in the Task.
3. Add 0–2 conditional Skills only for material risk.
4. Derive capability, permission, scope, branch, input, output and completion contracts from the role and Task.
5. Choose the role's model/effort route, then assemble the input.
Role defines identity, Skill defines method, and Task defines this attempt's objective. Split conflicting design, implementation and independent-review identities into separate Tasks.

## Model and effort routing

All workers use Claude Code: haiku for reconnaissance, fable for planning/adjudication, sonnet for implementation, opus for independent review/verification.
The sole routing authority is `routing/model-routing.json`: select the role's `chain`, start at `default`, never go below `floor`. For narrowly bounded read-only comparison, link-check and document Tasks with explicit output, apply `trivialTaskAdjustment`: move one step left from default, dispatching at the haiku floor when that step reaches it; never skip chain steps or override a pinned choice.
Dispatch fresh sessions through `worker-start` with `--agent claude` and the selected `--model` / `--effort`; reused terminals keep their session route and omit those launch flags. Obtain exact syntax from installed help.
Use the tier's request shape. Haiku prefers `claude-haiku-4-5` plus effort; on parameter rejection or first receipt mismatch, use alias `haiku` without effort and record the degradation, unless the user pinned the choice.
A pinned model or effort forbids automatic changes, including the haiku fallback: suspend the affected Task and ask the user if rejected or mismatched.
On every dispatch, apply **Effective receipt** and record [Dispatch assignment evidence](references/evidence-binding.md#dispatch-assignment-evidence), even with an assembled brief; reconcile mismatches before declaring a verified route.
The coordinator model is outside routing: do not choose, probe or validate it. Only record a user-reported value in `run-state.coordinatorModelReported`.
Upgrade, downgrade, suspension, trivial read-only adjustment and user-pinned behavior follow this file's `policies`; do not recreate route tables in workflow or role files.
`worker-start` has no permission flag; permission comes from actual Claude configuration and user Orca settings, which must be recorded rather than invented.

## Skill delivery

Read [Skill configuration and delivery](references/configuration-precedence.md#skill-configuration-and-delivery) before selecting delivery mode, registering external Skills, or assembling bindings; read [Execution configuration](references/configuration-precedence.md#execution-configuration) before checking or invoking dependencies on the execution host. `explicit-path` is the default and `inline-extract` the recorded fallback; a Skill name alone is not loading evidence, and Skills cannot expand Task scope or grant orchestration control.

## Task and branch creation

Read `references/branch-model.md` before choosing a branch or baseline.
Every Task, including scout, audit, review and verification, receives its own branch/worktree; default base is `delivery_branch`.
Override only for an explicit user base, a review of another branch, a true unintegrated prerequisite, or historical reproduction; record the reason.
Prefer reviewing and merging prerequisites before creating dependent implementation Tasks. Encode only true dependencies; use parallel waves and avoid chains deeper than 3–4 steps.
Workers commit authorized source changes on their task branches before reporting and never merge their own branches.
Before recording assignments or entering a validation gate, read [Evidence Binding](references/evidence-binding.md): Storage and ownership covers read-only declarations, source evidence paths and superseded repair rounds; Phase obligations defines the write-before-validate sequence. Only JSON `PASS` authorizes the applicable gate.

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
10. Applicable `AGENTS.md` sections, verbatim, always last
Use `taskKind` (`source` or `read-only`, default `source`), `briefProfile` (`standard` or `review`, default `standard`) and `agentsSections` (section numbers or titles, default all) to scope assembly; preserve every applicable project rule verbatim.

## Execution loop

1. Intake: record objective, scale, delivery branch, user-pinned choices and side-effect boundaries in run-state.
2. Reconnaissance: dispatch independent information domains as needed; stop when unknowns cease to affect the solution.
3. Design: after reconnaissance closes, evaluate `routing/design-triggers.json`; record `required`/`skipped`, reason and evidence in run-state `stageDecisions`. If required, dispatch read-only design Tasks by deliverable key via `routing/role-selection.json`; if skipped, proceed to planning.
4. Plan: use solution-planner, multiple plans plus plan-adjudicator when needed; resolve real product ambiguity with requirements-analyst first.
5. Task graph: write task-definition and assemble input; record machine-readable assignments, true dependencies and parallel waves.
6. Dispatch: launch all independent ready Tasks in parallel; verify the first effective receipt. Follow [dispatch mechanics](references/execution-loop.md#dispatch-wait-and-evidence-gates).
7. Wait and settle: process active-Dispatch messages, resolve terminal ownership and acknowledge; immediately dispatch newly ready work. Follow [wait mechanics](references/execution-loop.md#dispatch-wait-and-evidence-gates).
8. Empty waits: after three consecutive empty waits, inspect the fleet and its projected next action. Follow [inspection mechanics](references/execution-loop.md#dispatch-wait-and-evidence-gates).
9. Register source: match completion to the active Task/Dispatch, pass `sourceRegistered`, then immediately dispatch independent review alongside other implementation. Follow [registration mechanics](references/execution-loop.md#dispatch-wait-and-evidence-gates).
10. Review: record verdicts and pass `review`; route fixes and re-review through the original sessions. Validation failure is UNVERIFIABLE, never approval. Follow [review mechanics](references/execution-loop.md#review-and-integration).
11. Integrate: after approval pass `preMerge`, integrate serially, run full verification at integrated HEAD and pass `postMerge` before satisfying source dependencies. Follow [integration mechanics](references/execution-loop.md#review-and-integration).
12. Final verification: at the **Current verification** barrier, dispatch release-verifier on latest delivery, write unique run-final evidence and pass run-scoped `final`; report and close. Follow [final mechanics](references/execution-loop.md#dispatch-wait-and-evidence-gates).

Before executing steps 6–12, read [Execution Loop](references/execution-loop.md), including its mandatory [settlement and recovery boundaries](references/execution-loop.md#settlement-and-recovery-boundaries) and evidence-recording obligations. Rolling dispatch preserves every stage and gate.

## Review and integration

Apply **Independent review**, **Control separation**, and **Current verification**. Verdicts are `APPROVED`, `CHANGES_REQUIRED`, or `UNVERIFIABLE`; fixes require re-review. Read [Review and integration mechanics](references/execution-loop.md#review-and-integration) before preparing review input, retaining or reusing sessions, selecting verification coverage, admitting a merge, resolving conflicts or reclaiming worktrees. It defines the unchanged SHA/clean-tree admission, serial integration, full post-merge/final verification and terminal-ownership requirements.

## Degradation and handoff

Before any failure recovery, abnormal-receipt action or route change, read `references/failure-taxonomy.md`; use `model-routing.json` policies without inventing extra fallback routes.
Escalation follows the chain for demonstrated complexity or quality shortfalls. Explicit rate limiting allows at most two same-tier backoff retries; quota/model unavailability excludes that tier before searching leftward above floor.
No available route above floor, an unavailable pinned choice, or repeated same-class failures reaching the circuit breaker (at most three recommended) suspends only the affected Task.
Record time, Task/Dispatch, classification, evidence, original route and action in `degradation-events.json`; summarize pending decisions for the user.
Authentication failures require diagnosis; silence and unknown observations do not trigger downgrades.
Before replacing or retrying a writer, pass the [writer-replacement gate](references/recovery-and-idempotency.md#writer-replacement-hardened-gate) and follow [Writing Task handoff](references/worker-handoff.md#writing-task-handoff) for state capture and sequential takeover.
For read-only retries, preserve each attempt under a unique report path; the coordinator synthesizes the result.

## Completion

Close only after required Tasks settle, accepted source enters delivery, final verification completes or is explicitly marked unverifiable, and reports/decisions are stored.
Ensure the fleet has zero reclaimable resources; `retained`/`user_owned` terminals require recorded ownership decisions and are not leaks.
Write `final-report.md` linked to the unique `evidence/git/run-final-verification.json`, plus a separate user-decision report: what needs deciding, consequence of deferral, options and recommendation.
Before closure, read [Final coverage and exit semantics](references/evidence-binding.md#final-coverage-and-exit-semantics) and [Selector and coverage semantics](references/evidence-binding.md#selector-and-coverage-semantics) for complete coverage, current-SHA checks, audit/final scope, legacy runs and validator exit handling. `NOT_APPLICABLE` is not acceptance; keep `validate-run.ps1` as a separate gate.
Recheck status/diff for process-artifact exclusion, then use `scripts/release-coordinator.ps1 -ConfirmRunClosed`; it archives active state and marks the lock released.
Keep `.dev-work/runs/<run>/` as local history. Unverifiable acceptance must not be described as READY.

## Do not do

Do not bypass the [Required invariants](#required-invariants), including **Control separation**, **Process ownership**, **Single writer**, **Runtime authority**, **Effective receipt**, **Positive evidence**, **Artifact exclusion**, and **Coordinator lock**.
Do not re-dispatch because a receipt was unobserved or a wait was empty; use the recovery references above. Do not treat retained/user-owned terminals as leaks or orphan them by deleting their worktrees.
