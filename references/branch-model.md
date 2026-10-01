# Branch Model

## Control plane

The coordinator control worktree exists only to host:

- one Coordinator Agent;
- local `AGENTS.md`;
- `.dev-work/`;
- orchestration context.

Its branch is a parking/control branch. It may remain at an old commit. It is not part of the source dependency or integration graph.

## Delivery plane

`delivery_branch` is selected at intake:

- explicit user branch; otherwise
- `main`.

It is the default base, source integration target, and final-verification source.

## Task plane

Every Task gets an isolated branch/worktree.

- Read-only Task: report only, normally no merge.
- Source Task: commit, independent review, merge directly into delivery branch.
- Review Task: base on the reviewed branch; no source edits.
- Final verification Task: base on latest delivery branch; no source edits.
- Fix Task: base on the source state named by the coordinator.

## Branch changes

Changing `delivery_branch` mid-run is a user decision. Reconcile existing task bases, integrated commits, and final verification before continuing.
