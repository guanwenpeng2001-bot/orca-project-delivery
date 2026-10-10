# Refactor Workflow

## Goal

Improve internal structure while preserving explicitly defined external behavior and operational invariants.

## Stages

### Define invariants

Before editing, record:

- public behavior that must not change;
- performance or resource constraints;
- data compatibility;
- interfaces;
- tests that characterize current behavior;
- allowed cleanup scope.

### Reconnaissance

Map dependencies, callers, data flow, and change impact. Identify areas that cannot safely move in parallel.

### Refactor plan

Break work into small, reversible transformations. Each stage must have a verification checkpoint.

Prefer:

- characterization tests first;
- one boundary at a time;
- adapters around volatile details;
- no unrelated modernization.

### Implementation

Each refactor Task uses an isolated branch. Do not combine behavior changes with structural changes unless the Task explicitly requires both. Workers run Task-relevant verify suites and affected tests, plus explicit Task-required checks; record coverage and skips.

### Review

Dispatch the independent review Task as soon as the refactor Task settles, in parallel with other in-flight work. Supply the Task objective, acceptance criteria, exact `base..branch` diff bound to SHAs and relevant contract clauses; whole-package re-reading is not required.

Retain original implementer and reviewer terminals until the final verdict. On CHANGES_REQUIRED, dispatch the fix to the original implementer session and re-review to the original reviewer session, following [Session reuse](../references/worker-handoff.md#fix-returns-to-original-implementer-session) and its fallback/replacement gates.

Independent review checks:

- invariant preservation;
- hidden behavior changes;
- error and lifecycle equivalence;
- compatibility;
- test adequacy;
- whether complexity was actually reduced.

### Integration

Integrate each approved branch as soon as its review passes: merge serially into `delivery_branch`, one at a time in dependency order, recording the diff, tests and process-artifact exclusion for each merge; base Tasks created afterwards on the updated `delivery_branch`. Run the full verification suite at each post-merge integrated HEAD. Run the full suite again at final verification from a clean independent worktree on latest `delivery_branch`, only after all intended changes are integrated.

## Failure handling

When a refactor reveals a product or behavior ambiguity, stop that path and create a separate decision or feature Task rather than silently choosing new behavior.
