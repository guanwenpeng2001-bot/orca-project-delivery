# Worker Handoff: <task>

## Reason

<quota / process exit / model unavailable / user change / other>

## Original Attempt

- Agent/profile:
- Orca Task/Dispatch:
- Branch/worktree:
- HEAD:

## Git State

- Status:
- Commits:
- Diff summary:
- Untracked files:

## Completed

- <item>

## Remaining

- <item>

## Tests

- <command and result>

## Open Questions / Risks

- <item>

## Replacement Preconditions

- [ ] Evidence shows the original writer is stopped, fenced, isolated, or has completed an explicit handoff
- [ ] Original Dispatch has settled; Task has also settled if replaced rather than retried
- [ ] Git state (branch/worktree, HEAD/commits, status/diff, untracked files) and work preserved in this handoff
- [ ] Replacement profile eligible and takeover sequential

Admission evidence and source: <record proof for the selected term using references/recovery-and-idempotency.md; isolation proves inability to write, not necessarily exit>
Settlement evidence: <record separately; failed alone never proves writer admission>
