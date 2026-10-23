# Worker Handoff and Replacement

## Fix returns to original implementer session

After a confirmed source completion, retain the original implementer terminal while independent review runs; retain the original reviewer terminal through any repair rounds. Record retention and ownership before acknowledging settlement, and do not release either terminal until the final review verdict.

On CHANGES_REQUIRED, create a scoped fix Task carrying the accepted findings, current target SHA, acceptance criteria and a unique report path. Dispatch it to the original implementer's settled session with `worker-start --terminal <settled worker terminal>` and `--worktree <that terminal's worktree>`. After the fix settles, dispatch a re-review Task to the original reviewer's settled terminal with that review terminal's own worktree. The reviewer remains read-only and checks the new target SHA; reused context is not fresh evidence, but re-verification scope scales with the delta: carry the changed paths in the re-review Task (`reviewInput.deltaPaths`), re-run the acceptance items those paths touch, and re-run everything only when the delta reaches shared core files.

This is sequential continuation by the same writer, not writer replacement or a retry of an unresolved attempt. Confirm the prior Task/Dispatch settled and branch ownership still belongs to that writer before dispatching; never add a concurrent writer. Keep a fresh assignment record and review report for each round. Session reuse preserves Task isolation and the review/integration rules.

Consult installed help for exact placement syntax. Explicit `--worktree` must identify the selected terminal's worktree; `current` would select the coordinator worktree. Reuse does not accept `--model` or `--effort`; honoring a new user pin that changes session configuration requires a cold session under the recovery rules. Default launches still omit model/effort.

If the terminal is gone or reuse fails, record the reason and runtime evidence, then allow a cold session only after resolving the attempt's state. Unknown start outcomes, timeouts or silence do not authorize fallback. A different writer, or any writing retry after failure, must pass the unchanged [writer-replacement gate](recovery-and-idempotency.md#writer-replacement-hardened-gate) and the handoff procedure below; session reuse is not an exemption for recovery. Preserve the original reports and give each cold review attempt a unique report path.

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
