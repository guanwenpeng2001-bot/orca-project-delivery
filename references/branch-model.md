# Branch Model

## Control plane

The coordinator control worktree exists only to host:

- one Coordinator Agent;
- local `AGENTS.md`;
- `.dev-work/`;
- orchestration context.

Its branch is a parking/control branch. It may remain at an old commit. It is not a source-development branch, task base, integration target, review target, or final-verification source. Read current source facts from the actual delivery or Task worktree.

## Delivery plane

`delivery_branch` is resolved at intake by `scripts/bootstrap-project.ps1` in this order:

1. Explicit `-DeliveryBranch` supplied by the user (source: `user`).
2. The symbolic `refs/remotes/origin/HEAD`, with the `origin/` prefix removed (source: `origin-head`).
3. Git `init.defaultBranch`, only when that local branch exists (source: `init-default`).
4. Local `main`, when it exists (source: `main`).
5. Local `master`, when it exists (source: `master`).
6. The current branch (source: `current`).

Record the selected branch and its source. The control worktree must have a checked-out branch; detached HEAD is rejected. If the resolved delivery branch equals the control branch, bootstrap rejects it by default. Its explicit `-AllowControlEqualsDelivery` override acknowledges an invariant violation; it does not make the control branch a normal integration target. Supply the intended `-DeliveryBranch` or use a separate control branch.

The one selected delivery branch is the default Task base, reviewed-source integration target, and final-verification source.

## Task plane

Every Task gets an isolated branch/worktree, including read-only research and review. Use `delivery_branch` as the default base; an explicit user base, review target, true unintegrated prerequisite, or historical reproduction may require a different base recorded in the Task Contract.

- Read-only Task: report only, normally no merge.
- Source Task: commit, independent review, merge directly into delivery branch.
- Review Task: base on the reviewed branch; no source edits.
- Final verification Task: base on latest delivery branch in a clean worktree; no source edits.
- Fix Task: base on the source state named by the coordinator.

One task branch has one writer at a time. A replacement starts only after authoritative stop/failure/fencing or explicit handoff; follow `references/worker-handoff.md`.

## Integration

The coordinator merges accepted source directly into the actual worktree that has `delivery_branch` checked out. Never route source through the control branch. Record the diff, tests, and process-artifact exclusion check. Remove Task worktrees and branches only after their result is integrated, rejected, or explicitly abandoned.

## Branch changes

Changing `delivery_branch` mid-run is a user decision. Reconcile existing task bases, integrated commits, and final verification before continuing.
