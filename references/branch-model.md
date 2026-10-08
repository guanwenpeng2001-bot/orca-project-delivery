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

- Read-only Task: report only, no integration evidence; explicitly declare `branch.mergeTarget: null` in assignment JSON, including review and final-verification Tasks. Missing or string-valued null does not identify read-only work to the evidence validator.
- Source Task: commit, independent review, merge directly into delivery branch.
- Review Task: base on the reviewed branch; no source edits.
- Final verification Task: base on latest delivery branch in a clean worktree; no source edits.
- Fix Task: base on the source state named by the coordinator.

One task branch has one writer at a time. Replacement requires evidence the writer is stopped, fenced, isolated, or has completed an explicit handoff, plus a settled Dispatch (and settled Task if replaced) and preserved Git state/handoff. `failed` alone never admits a writer; use the definitions and procedure in `references/worker-handoff.md` and `references/recovery-and-idempotency.md`.

## Integration

The coordinator merges accepted source directly into the actual worktree that has `delivery_branch` checked out. Never route source through the control branch. Follow `references/evidence-binding.md`: register worker source, record independent target/baseline SHA reviews, then record and validate preMerge admission while state is reviewed. The live source HEAD must equal the latest approved SHA, and source/delivery trees must be clean; drift requires re-review.

Integrate serially and record baselineBefore, actual headAfter, merge process, diff/artifact exclusions and fresh verification at headAfter before postMerge validation. A normal conflict-free three-way merge is valid with the recorded parents; conflict resolution requires abort, an isolated resolution Task, re-review and renewed admission. Historical headAfter remains historical as delivery advances.

After all intended integrations, final verification runs in an independent clean worktree at latest delivery; the coordinator writes and validates the unique run-final with complete integrated coverage. Remove Task worktrees and branches only after integration, rejection or explicit abandonment and terminal ownership resolution; retain Git objects and reports needed for historical audit.

## Branch changes

Changing `delivery_branch` mid-run is a user decision. Reconcile existing task bases, integrated commits, and final verification before continuing.
