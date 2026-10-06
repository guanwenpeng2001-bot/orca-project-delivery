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

### Planning and architecture

For low-risk work, one plan may be enough.

For material alternatives or high risk:

- dispatch independent Solution Planner Tasks;
- keep their contexts isolated;
- dispatch a Plan Adjudicator;
- record accepted and rejected decisions.

Architecture Tasks must identify boundaries, interfaces, data ownership, migrations, integration points, rollback, and verification.

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

### Implementation

Each source Task runs in an independent worktree. Implementers do not merge themselves.

### Independent review

Review each source branch against requirements, Task Contract, project rules, diff, tests, and implementation report.

### Integration

After approval, merge the source branch directly into `delivery_branch`. Do not use the coordinator control branch. Orca has no merge primitive: this is an explicit coordinator `git merge` in the worktree that has `delivery_branch` checked out, recorded together with the diff, the tests, and the process-artifact exclusion check.

### Final verification

Create a clean verification worktree from the latest `delivery_branch`. Verify end-to-end acceptance, integration, regressions, and process-artifact exclusion.

### Close

Write final delivery and pending-user-decision reports, settle workers, and clean worktrees.

## Re-entry loops

- Missing evidence: return to reconnaissance.
- Requirements ambiguity: return to product/requirements.
- Plan defect: revise planning artifacts before implementation.
- Review finding: create a fix Task, then re-review.
- Integration failure: create a scoped fix Task from the latest delivery state.
