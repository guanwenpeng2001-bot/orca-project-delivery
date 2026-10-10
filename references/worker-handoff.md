# Worker Handoff and Replacement

## Writing Task handoff

Before a writing retry or replacement, pass the [writer-replacement gate](recovery-and-idempotency.md#writer-replacement-hardened-gate); this file owns its required capture and takeover procedure.

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

Write a handoff report under the control tree's `.dev-work/runs/<run>/handoffs/`; preserve uncommitted work as well as commits and do not skip capture for a clean-looking branch.

After the gate passes, the replacement takes over sequentially and must read all of the following before writing:

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

Do not bypass the [admission terms](recovery-and-idempotency.md#writer-replacement-hardened-gate) or lose uncommitted work during fallback.
