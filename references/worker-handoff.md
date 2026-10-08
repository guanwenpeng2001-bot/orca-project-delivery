# Worker Handoff and Replacement

## Writing Task handoff

A replacement writer may start only after the old worker is confirmed stopped, fenced, or
explicitly handing off. `failed` alone does not prove the writer stopped: an accepted `failed`
completion settles the attempt, but the writer's terminal and process can still be live, and a
silent or timed-out writer proves nothing. Confirm the writer itself has stopped or been
isolated and its Dispatch has settled first — see the writer-replacement gate in
`references/recovery-and-idempotency.md`.

Capture:

- branch and worktree;
- HEAD and commits;
- `git status`;
- diff summary;
- untracked files;
- tests run and results;
- current Task state;
- completed and incomplete requirements;
- open questions;
- report paths.

Write a handoff report under `.dev-work/runs/<run>/handoffs/`.

Settle or release the old worker before starting the replacement.

The replacement must read:

- original Task;
- Role;
- required Skills;
- project rules;
- prior report and handoff;
- current Git state.

## Read-only Task retry

Keep each attempt in a unique path:

`<artifact>/<task>/attempt-<profile-or-number>.md`

The coordinator validates and synthesizes a final report.

## Prohibited

- Two live writers in one worktree.
- Deriving a second writer from `failed`, silence, or timeout alone.
- Assuming timeout means the process exited.
- Starting a new writer while the old worker is unverifiable.
- Losing uncommitted work during fallback.
