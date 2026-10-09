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
2. Select 1–3 required Skills from the current `routing/skill-catalog.json`, following Role defaults and `routing/skill-selection.json`; explain irrelevant defaults in the Task.
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

Professional Skills are package-maintained MIT adaptations under `skills/`; `skills/README.md` records provenance and current hashes. See `docs/extending.md` for native authoring/registration and metadata/full verification.
- `explicit-path` is the default: give the absolute `SKILL.md` path in the Task and require reading it.
- `inline-extract` is the fallback: include the required sections and record source path and hash.
A Skill name alone is not loading evidence. Skills supply method and cannot expand Task scope or grant orchestration control.
Catalog `requires` declares CLI/env/API names and purposes only. Assembly lists required and conditional requirements inside Inputs and Dependencies, preserving the ten-part order and AGENTS last.
On the execution host, use `check-requirements.ps1` with explicit `-ProjectRoot`, `-Role` and in-session `-Skills @(...)` for required plus activated conditional IDs; helpers do not infer Role defaults.
File configuration is not process availability. Process values (including empty) override root `.env`, then explicit non-secret `-ConfigPath`; no `.dev-work` resolver or coordinator `.env` copying exists.
For authorized local execution, use `invoke-with-requirements.ps1` with those selectors, `-Executable` and `-Arguments @(...)`; file additions are selected declarations only, inherited process variables remain, and the parent stays unchanged.
API checks are presence-only, without network/install actions. Child output is not redacted. Config paths stay under the root; authorized executables may be outside it. Prefer real executables/interpreters over batch launchers.

## Task and branch creation

Read `references/branch-model.md` before choosing a branch or baseline.
Every Task, including scout, audit, review and verification, receives its own branch/worktree; default base is `delivery_branch`.
Override only for an explicit user base, a review of another branch, a true unintegrated prerequisite, or historical reproduction; record the reason.
Prefer reviewing and merging prerequisites before creating dependent implementation Tasks. Encode only true dependencies; use parallel waves and avoid chains deeper than 3–4 steps.
Workers commit authorized source changes on their task branches before reporting and never merge their own branches.
Read-only Tasks must explicitly declare `branch.mergeTarget: null` in assignments; source Tasks name the delivery branch and `evidence.gitEvidencePath` under `runs/<run>/evidence/git/`.
Assignment status also permits `integrating`, `integrated` and `superseded`. Replaced repair rounds retain assignments with `status: superseded` and `supersededBy` naming the integrated logical task in the same run; optional `supersedes` is a descriptive backlink. The validator waives the replaced round's own evidence obligation only after verifying a unique different formal successor in an entered status, matching delivery branch and valid integrated evidence; missing/invalid/unintegrated successors fail.
Follow `references/evidence-binding.md`: the coordinator records observations and writes evidence before each read-only validation; only `PASS` authorizes the applicable gate.

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
5. Dispatch every ready Task; ready means its real dependencies settled successfully through their existing gates — a source dependency counts only after its own review and integration, never on `worker_done` alone — write scope disjoint from in-flight Tasks, and a usable baseline and route. Verify the first `launch.effective` receipt and fill assignment runtime evidence.
6. Wait using `check --wait`; process every question/escalation, confirm worker_done belongs to the active Dispatch, decide the terminal's next owner, then acknowledge. After each confirmed settle, immediately re-evaluate readiness and dispatch newly ready Tasks (rolling dispatch) without waiting for unrelated in-flight Tasks.
7. After three consecutive empty waits, enumerate using `worker-list` and act on `projection.nextAction`; use bounded `worker-read` inspection where needed.
8. After matching `worker_done` to the active Task/Dispatch, register `source.*` in its `source-registered` evidence; run `validate-git-evidence.ps1 -EvidencePath <evidence-json> -Phase sourceRegistered` with the control tree as `-ProjectRoot`, where `<evidence-json>` is the Git evidence file at `runs/<run>/evidence/git/<task-key>.json`. For a source Task, on PASS immediately dispatch independent review of the actual implementation branch in an isolated worktree, alongside other implementation.
9. Record completed reviews in `reviews[]`, set `state: reviewed`, then validate `-Phase review`; convert accepted findings into fix Tasks and re-review. Validation failure is UNVERIFIABLE, never approval.
10. After each approval, record admission/baseline and pass `-Phase preMerge`, then merge serially in the delivery worktree. Capture the merge and fresh checks at `headAfter`, write complete `integrated` evidence, and pass `-Phase postMerge` before treating the source dependency as integrated. Record diff/artifact exclusions, base later Tasks on updated delivery, then reclaim eligible worktrees.
11. After all intended changes integrate, release-verifier verifies latest delivery in a clean independent worktree; the coordinator writes the unique run-final evidence and validates `-Run <run> -Phase final`. Write reports, summarize decisions, settle workers and release the coordinator. This final barrier never moves earlier and is never skipped.

`source.workerDone` IDs require `msg_` / `task_` / `ctx_` plus 12 lowercase hexadecimal characters. `messageId` authenticity cannot be mechanically verified by the local validator: it is the recorder's honesty declaration, with credibility no higher than the recorder; format validation cannot prove message existence or ownership.

A nonzero start receipt alone does not prove a failed attempt: inspect `failedStage` and `residualResources` using `references/failure-taxonomy.md`.
`outcome_unknown`, `turn_start_unobserved`, timeouts and unverifiable liveness do not authorize stop, abandon, retry or release.
User decisions use decision gates suspending only dependent Tasks; independent work proceeds. Resolve gates after the user decides.
Release is post-settlement cleanup. Record `retained` or `user_owned` decisions; explicitly resolve terminal ownership before removing its worktree.
Rolling dispatch changes no stage or gate: stages and gates are neither added nor removed, `AGENTS.md` stays verbatim, model routing and failure/unverifiable semantics are unchanged; only artificial batch waits between independent Tasks are removed.

## Review and integration

Implementer self-check does not replace independent acceptance. Reviewers report `APPROVED`, `CHANGES_REQUIRED`, or `UNVERIFIABLE` and never edit source.
Dispatch independent review after source registration passes, in parallel with other in-flight work, always against the actual implementation branch; record target/baseline SHAs and clean status using `templates/review-report.md`.
Findings become separate fix Tasks followed by re-review; unclear evidence remains explicitly unverifiable.
After approval and pre-merge admission PASS, the coordinator runs Git merge in the actual delivery worktree; Orca has no merge primitive. Source HEAD must still equal the latest approved SHA and both trees must be clean; drift requires re-review.
Integrate serially in dependency order. A clean three-way merge is valid with recorded parents/process evidence; conflicts require abort, an isolated resolution Task, independent re-review and renewed admission. Never repair unreviewed source in delivery.
`mergeEvidence` proves only the Git operation; `checks[]` must include actual successful verification at `headAfter`, not source-branch test results. The validator checks records and Git; it never runs tests.
New Tasks created afterwards base on the updated delivery baseline. Never integrate through the control branch or treat its HEAD as delivery evidence.
Remove task worktrees and safe-to-delete branches only after integration or explicit abandonment and terminal ownership resolution.
Final verification stays a global barrier: create it from the latest delivery branch in a clean worktree only after all intended changes are integrated, never earlier and never skipped; do not reuse stale test claims.

## Degradation and handoff

Before any failure recovery, abnormal-receipt action or route change, read `references/failure-taxonomy.md`; use `model-routing.json` policies without inventing extra fallback routes.
Escalation follows the chain for demonstrated complexity or quality shortfalls. Explicit rate limiting allows at most two same-tier backoff retries; quota/model unavailability excludes that tier before searching leftward above floor.
No available route above floor, an unavailable pinned choice, or repeated same-class failures reaching the circuit breaker (at most three recommended) suspends only the affected Task.
Record time, Task/Dispatch, classification, evidence, original route and action in `degradation-events.json`; summarize pending decisions for the user.
Authentication failures require diagnosis; silence and unknown observations do not trigger downgrades.
Before replacing a writing worker, read `references/worker-handoff.md`: require evidence the writer is stopped, fenced, isolated, or has completed an explicit handoff; its Dispatch (and Task if replaced) must settle separately. Preserve Git status/diff/commits/untracked files in handoff, then replace sequentially; `failed` alone never admits a writer.
For read-only retries, preserve each attempt under a unique report path; the coordinator synthesizes the result.

## Completion

Close only after required Tasks settle, accepted source enters delivery, final verification completes or is explicitly marked unverifiable, and reports/decisions are stored.
Ensure the fleet has zero reclaimable resources; `retained`/`user_owned` terminals require recorded ownership decisions and are not leaks.
Write `final-report.md` linked to the unique `evidence/git/run-final-verification.json`, plus a separate user-decision report: what needs deciding, consequence of deferral, options and recommendation.
Final evidence must cover every intended integrated Task, with nonempty coverage/inputs, no uncovered Tasks and successful checks at the latest delivery SHA; never create per-task final records or equate historical `headAfter` with current delivery HEAD.
Use `-Run <run> -Phase audit` for historical evidence; use run scope or the canonical run-final file for final acceptance, never a single Task's `-Phase final` result.
Validator JSON `PASS` and `NOT_APPLICABLE` both exit 0; `FAIL` exits 1. NOT_APPLICABLE is not acceptance. New runs/Tasks require this evidence chain; old runs remain readable, but resumed merges require rebuilt evidence. `validate-run.ps1` remains a separate unchanged default gate.
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
