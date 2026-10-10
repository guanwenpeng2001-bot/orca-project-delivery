# Coordinator Lock and Release

## Honest limitation

Orca has **no coordinator-lock primitive**. Two terminals in the same worktree can each
run `orca orchestration run-create` and Orca will not refuse either one. This lock is a
**local convention** stored in `.dev-work/coordinator-lock.json`; it protects one
worktree only, and only when every coordinator honours it.

Authority for Run, Task, Dispatch and Worker lifecycle stays with the current global
`orchestration` Skill. Never duplicate Orca lifecycle state here.

## Lock record

Written by `scripts/bootstrap-project.ps1`; `activeRun` is updated by `scripts/create-run.ps1`.
`updatedAt` is refreshed by every ledger write (`create-run.ps1`, `dispatch-task.ps1`), so a stale
`updatedAt` tells the user nothing has been recorded recently — it is an observability signal for a
human reader, not a liveness test. Liveness stays with the `orca terminal show` probe below.

| Field | Meaning |
| --- | --- |
| `schemaVersion` | `1` — validated against `schemas/coordinator-lock.schema.json` |
| `status` | `active` or `released` |
| `coordinatorTerminalHandle` | `ORCA_TERMINAL_HANDLE` of the coordinator session (null outside an Orca terminal) |
| `coordinatorWorktreeId` | `ORCA_WORKTREE_ID` of the control worktree |
| `livenessProbe` | The exact command used to test liveness |
| `hostProcessId` / `processId` | Diagnostic only — **never** the liveness signal (the bootstrap process exits immediately) |
| `coordinatorControlBranch` | Control branch; must differ from `delivery_branch` (control/delivery branch separation rule in [SKILL.md — Bootstrap](../SKILL.md#bootstrap)) |
| `coordinatorWorktree` | Absolute control worktree path |
| `startedAt`, `updatedAt`, `releasedAt`, `releaseReason` | Timestamps and release audit |
| `activeRun` | Run slug currently owned by this coordinator |

## Liveness rule

`Get-CoordinatorLiveness` in `bootstrap-project.ps1` returns three states:

| State | Test | Bootstrap behaviour (without `-ForceLock`) |
| --- | --- | --- |
| `live` | `orca terminal show --terminal <handle> --json` returns `ok` | Refuse: a live coordinator owns this worktree |
| `dead` | a handle is recorded and the probe returns non-zero | Warn, archive the old lock, take over |
| `unknown` | no recorded handle, no `orca` on PATH, or an unparsable response | Refuse (absence is not proof — invariants 4 and 7) |

`-ForceLock` archives the existing lock into `.dev-work/archive/coordinator-lock-<timestamp>.json`
and writes a new one regardless of state. Use it only after the holder is confirmed gone.
The `unknown` refusal follows the shared recovery principles in
`references/recovery-and-idempotency.md`: absence is never proof of holder death.

## Release

`scripts/release-coordinator.ps1 -ConfirmRunClosed -Reason "<why>"`:

1. refuses to run without `-ConfirmRunClosed`;
2. reports (best effort) `orca orchestration worker-list --terminal-state reclaimable --json`
   and warns if any worker terminal still owes a decision — an unverifiable result is
   reported as such, never treated as failure;
3. archives `active-run.json` and `coordinator-lock.json` into
   `.dev-work/archive/released-<timestamp>/`;
4. sets the lock to `status = released` with `releasedAt`/`releaseReason` (it does not
   delete the lock file, so a later `bootstrap` sees a `released` holder, archives it and
   takes over deliberately — even when the previous coordinator terminal is still alive);
5. deletes `active-run.json`.

The Orca Run is a namespace and is **not** deleted. `orca orchestration reset` is a
global-scope operation — never use it to clean up a single run.

## Worker terminal retention

`worker-release` is post-settlement cleanup, not cancellation. On a host whose default new-tab
mode is a terminal, Orca can answer `state: retained` / `reason: user_takeover` /
`ownershipState: user_owned` and keep the worker terminal alive. The completion accounting still
holds (`worker-list --terminal-state reclaimable` returns none), but the terminal is not closed.
Decide explicitly between reuse, retain, and close. Removing a task worktree orphans its
terminal — close it explicitly instead of leaving a dead pane.
