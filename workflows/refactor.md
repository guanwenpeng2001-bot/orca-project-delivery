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

Each refactor Task uses an isolated branch. Do not combine behavior changes with structural changes unless the Task explicitly requires both.

### Review

Independent review checks:

- invariant preservation;
- hidden behavior changes;
- error and lifecycle equivalence;
- compatibility;
- test adequacy;
- whether complexity was actually reduced.

### Integration

Integrate approved steps into `delivery_branch` in dependency order. Run final verification from a fresh worktree.

## Failure handling

When a refactor reveals a product or behavior ambiguity, stop that path and create a separate decision or feature Task rather than silently choosing new behavior.
