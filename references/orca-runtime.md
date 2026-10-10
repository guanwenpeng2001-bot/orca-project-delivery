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
| Fix / re-review session reuse | New follow-up Task/Dispatch on the original settled implementer / reviewer terminal, with its explicit worktree |
| Preserve context until final review verdict | Explicit terminal retention; no release during repair rounds |
| Attempt cleanup | Release/stop/abandon according to authoritative state |

`.dev-work` records identifiers and reports, not duplicate lifecycle state. Receipt handling
and the waiting loop belong to `SKILL.md`; evidence classification belongs to
`references/failure-taxonomy.md`, and writer replacement to `references/worker-handoff.md`.
For session reuse, verify installed support for `worker-start --terminal <settled worker terminal>` together with `--worktree <that terminal's worktree>`; do not combine reuse with model/effort launch overrides. Retention records an ownership decision, not a process action. A missing terminal or failed reuse permits a cold session only with a recorded reason and resolved runtime state; follow [Fix returns to original implementer session](worker-handoff.md#fix-returns-to-original-implementer-session), including the replacement gate for a new writer.

Orca exposes no merge primitive; follow `references/branch-model.md` for coordinator-run Git integration.
