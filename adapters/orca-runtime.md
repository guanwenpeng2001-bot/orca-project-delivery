# Orca Runtime Adapter

## Authority

This adapter describes when to use Orca, not the exact current CLI syntax.

Before any Run, Task, Dispatch, Worker, Message, Gate, worktree, terminal, or cleanup operation:

1. Load the current global `orchestration` Skill.
2. Load `orca-cli` or `orca-per-workspace-env` when needed.
3. Confirm syntax with the installed Skill and `--help`.
4. Do not copy commands from this package when the installed Orca contract differs.

## Business-to-runtime mapping

| Business action | Orca concept |
| --- | --- |
| One delivery effort | Run |
| One independently executable unit | Task |
| Dependency | Task dependency |
| One attempt by an Agent | Dispatch / Worker |
| Human or coordinator decision | Gate or message, depending on ownership |
| Worker question | Question message and reply |
| Blocked attempt | Escalation |
| Authoritative worker completion | `worker_done` lifecycle event |
| Agent process placement | Terminal + worktree |
| Attempt cleanup | Release/stop/abandon according to authoritative state |

## Rules

- `.dev-work` records identifiers and reports, not duplicate lifecycle state.
- The authoritative Dispatch is the attempt allowed to write.
- A new attempt cannot start while the old writer may still be active.
- Reuse an existing terminal only after the prior Task is settled and the Agent is idle.
- Model/effort overrides cannot be assumed available for every Agent.
- Runtime receipts and worker projections override local assumptions.
- Timeouts and silence are observation checkpoints, not proof of failure.
- A non-zero `worker-start` receipt (`state: outcome_unknown`, `stage: turn_start_unobserved`) is
  unobserved, not failed: read `failedStage` and `residualResources`, inspect with `worker-show`
  and `worker-read`, repair the same Agent's launch topology, and never re-dispatch on that
  evidence alone.
- Orca exposes no merge primitive. Integration is an explicit coordinator-run `git merge` into the
  worktree that has `delivery_branch` checked out, recorded with its diff, tests, and
  process-artifact exclusion check.
