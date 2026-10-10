# Orca Runtime

## Authority

This reference describes when to use Orca, not the exact current CLI syntax.

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
| One attempt by a Worker | Dispatch / Worker |
| Human or coordinator decision | Gate or message, depending on ownership |
| Worker question | Question message and reply |
| Blocked attempt | Escalation |
| Authoritative worker completion | `worker_done` lifecycle event |
| Worker process placement | Terminal + worktree |
| Dispatch visibility to the user | Worker-start receipt `mode` and terminal `surface`; record both in the assignment (`runtime.mode`, `runtime.surface`) |
| Fix / re-review session reuse | New follow-up Task/Dispatch on the original settled implementer / reviewer terminal, with its explicit worktree |
| Preserve context until final review verdict | Explicit terminal retention; no release during repair rounds |
| Attempt cleanup | Release/stop/abandon according to authoritative state |

`.dev-work` records identifiers and reports, not duplicate lifecycle state. Receipt handling
and the waiting loop belong to `SKILL.md`; evidence classification belongs to
`references/failure-taxonomy.md`, and writer replacement to `references/worker-handoff.md`.
For session reuse, verify installed support for `worker-start --terminal <settled worker terminal>` together with `--worktree <that terminal's worktree>`; do not combine reuse with model/effort launch overrides. Retention records an ownership decision, not a process action. A missing terminal or failed reuse permits a cold session only with a recorded reason and resolved runtime state; follow [Fix returns to original implementer session](worker-handoff.md#fix-returns-to-original-implementer-session), including the replacement gate for a new writer.

Orca exposes no merge primitive; follow `references/branch-model.md` for coordinator-run Git integration.

## Waiting and wakeup

Run `check --wait` as a backgrounded call; its receipt file is created empty and filled only when the call returns, so a 0-byte file is in-flight, not failed. A wait that is dropped with `runtime_unavailable` (the code the runtime returns when the connection closes before a response) is `outcome_unknown`, not failure: run the recovery block the receipt itself carries (`request-show` → `check --wait --retry-request`) in the same terminal, and never treat a severed wait as evidence about the worker.

Reconcile `.dev-work` report files on disk at every wake point. A report on disk is reconciliation evidence, never a completion signal, and never a second lifecycle database. Until Orca pushes lifecycle mail into an idle coordinator (Run-mailbox `worker_done` is not pushed today), a coordinator may register a bounded self-wakeup as a recorded fallback and note it in run-state; it does not replace runtime authority.

A worker placed in the control worktree, or a background (`structured`) session reported as a visible terminal, is a placement defect: re-dispatch with an explicit `--worktree`, record `runtime.mode`/`runtime.surface`, and say plainly in the next user-facing report which workers are background sessions.
