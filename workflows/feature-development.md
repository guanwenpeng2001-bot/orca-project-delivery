# Feature Development Workflow

## Goal

Turn a product or engineering objective into reviewed, integrated, and verified source changes.

## Entry contract

Record:

- objective;
- users and problem;
- in-scope and out-of-scope behavior;
- acceptance criteria;
- delivery branch;
- user-pinned Agent/model choices;
- external side effects or approval gates.

## Adaptive stages

### Intake

Clarify only information that can change direction. Do not ask for engineering details the coordinator can infer from repository evidence.

### Reconnaissance

Dynamically identify unknowns that could change scope or solution. Create isolated Scout Tasks by information domain.

Possible outputs:

- current behavior map;
- affected modules and interfaces;
- prior attempts;
- dependency constraints;
- data and migration constraints;
- UI/product conventions;
- operational constraints.

### Product and requirements

Use the Requirements Analyst Role (`requirements-analyst`) only when the feature has genuine product ambiguity, user-flow surface, or acceptance uncertainty.

Outputs may include:

- problem statement;
- user flow;
- states and edge cases;
- functional and non-functional requirements;
- explicit non-goals;
- measurable acceptance.

### Design

Design is conditional at standard and high-risk depth. Evaluate `routing/design-triggers.json` once after reconnaissance closes (and after product/requirements when that ran), before planning. The coordinator records `required` or `skipped`, with reason and evidence, in run-state `stageDecisions.design`; a skipped stage is not added to `completedStages`.

On `required`, dispatch read-only design Tasks by deliverable key through `routing/role-selection.json`. Design outputs must identify boundaries, interfaces, data ownership, migrations, integration points, rollback, and verification; planning consumes these outputs. On `skipped`, proceed directly to planning. At light depth, a trigger hit is evidence to upgrade to standard under the existing scale rule.

### Planning

For low-risk work, one plan may be enough.

For material alternatives or high risk:

- dispatch independent Solution Planner Tasks;
- keep their contexts isolated;
- dispatch a Plan Adjudicator;
- record accepted and rejected decisions.

### Task graph

Create self-contained Tasks with:

- one Primary Role;
- exact branch base;
- allowed and forbidden scope;
- inputs and dependencies;
- outputs;
- acceptance criteria;
- tests;
- report path;
- required Skills.

Encode only real dependencies. Parallelize independent work.

A Task is ready when its real dependencies have settled successfully through their existing gates — a source dependency needs its review and integration first, not `worker_done` alone — its write scope is disjoint from in-flight Tasks, and its baseline and Agent are usable. Dispatch ready Tasks as they become ready; do not hold a batch barrier for unrelated in-flight Tasks.

### Implementation

Each source Task runs in an independent worktree. Implementers do not merge themselves. Workers run Task-relevant verify suites and affected tests, plus any explicit Task-required checks; record coverage and skips.

### Independent review

Dispatch the independent review Task as soon as the source Task's `worker_done` is confirmed, in parallel with other in-flight implementation.

Give each reviewer the Task objective, acceptance criteria, exact `base..branch` diff bound to SHAs, and relevant contract clauses. Use `taskKind: read-only`, `briefProfile: review` and applicable `agentsSections`; append applicable `AGENTS.md` sections verbatim, always last. Inspect affected code, tests and implementation evidence as needed; do not require a whole-package re-read.

Keep the original implementer and reviewer terminals retained until the final review verdict. On CHANGES_REQUIRED, return the fix to the original implementer session and re-review to the original reviewer session under [Session reuse](../references/worker-handoff.md#fix-returns-to-original-implementer-session), including explicit worktree placement and recorded cold-session fallback.

### Integration

After approval, merge the source branch directly into `delivery_branch`. Do not use the coordinator control branch. Orca has no merge primitive: this is an explicit coordinator `git merge` in the worktree that has `delivery_branch` checked out, recorded together with the diff, the tests, and the process-artifact exclusion check.

Integrate each approved branch as soon as its review passes: with several branches pending, merge serially, one at a time in dependency order, recording the diff, tests and process-artifact exclusion for every merge, and base Tasks created afterwards on the updated `delivery_branch`. Run the full verification suite at each post-merge integrated HEAD before satisfying source dependencies. Final verification still starts only after all intended changes are integrated.

### Final verification

Create a clean verification worktree from the latest `delivery_branch`. Run the full suite again and verify end-to-end acceptance, integration, regressions, and process-artifact exclusion.

### Close

Write final delivery and pending-user-decision reports, settle workers, and clean worktrees.

## Re-entry loops

- Missing evidence: return to reconnaissance.
- Requirements ambiguity: return to product/requirements.
- Plan defect: revise planning artifacts before implementation.
- Review finding: create a fix Task in the original implementer session, then re-review in the original reviewer session under the session-reuse contract above.
- Integration failure: create a scoped fix Task from the latest delivery state.
- Boundary, interface, or data-model discovery: return to design. If the stage was skipped, re-evaluate the trigger and record the flipped verdict (`stageDecisions`); if a design artifact exists, revise it. Then revise planning artifacts before further implementation. Preserve completed work and append-only `completedStages`; record the flip and its reason in `decisions.md`.
