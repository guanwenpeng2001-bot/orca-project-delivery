# Branch Model

## Control plane

The coordinator control worktree exists only to host:

- one Coordinator Agent;
- local `AGENTS.md`;
- `.dev-work/`;
- orchestration context.

Its branch is a parking/control branch. It may remain at an old commit. It is not a source-development branch, task base, integration target, review target, or final-verification source. Read current source facts from the actual delivery or Task worktree.

The coordinator may use native read-only helpers for its own analysis, planning and synthesis without creating separate Orca Tasks or worktrees. Helpers do not develop source, edit global process state, become another coordinator or replace formal implementation Tasks and independent review; the coordinator retains decisions, dispatch, state ownership and helper cleanup.

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

Every top-level Orca Task gets an isolated branch/worktree, including read-only research and review. Use `delivery_branch` as the default base; an explicit user base, review target, true unintegrated prerequisite, or historical reproduction may require a different base recorded in the Task Contract.

- Read-only Task: report only; declare `branch.mergeTarget: null` in the assignment, including review and final-verification Tasks.
- Source Task: commit, independent review, merge directly into delivery branch.
- Review Task: base on the reviewed branch; no source edits.
- Final verification Task: base on latest delivery branch in a clean worktree; no source edits.
- Fix Task: base on the source state named by the coordinator.

One task branch has one writer at a time; before replacement or retry, pass the [writer-replacement gate](recovery-and-idempotency.md#writer-replacement-hardened-gate) and follow [Writing Task handoff](worker-handoff.md#writing-task-handoff).

Worker-native helpers remain inside their parent Task. Read-only helpers may share context; concurrent writers require isolated branches and worktrees. The parent owns the combined result and cleanup, and internal checks do not replace the separate review Task.

## Integration

The coordinator merges accepted source directly into the actual worktree that has `delivery_branch` checked out. Never route source through the control branch. Merge only after an independent review APPROVED, with the live source HEAD equal to the approved commit and both source and delivery worktrees clean; drift requires re-review.

Integrate serially in dependency order; record the merge result and run the full verification suite at the resulting HEAD before later Tasks base on it. Conflict resolution requires abort, an isolated resolution Task, re-review and a fresh merge attempt.

After all intended integrations, final verification runs in an independent clean worktree at latest delivery; only its passing result authorizes READY. Remove Task worktrees and branches only after integration, rejection or explicit abandonment and terminal ownership resolution; retain Git history and reports.

## Branch changes

Changing `delivery_branch` mid-run is a user decision. Reconcile existing task bases, integrated commits, and final verification before continuing.
