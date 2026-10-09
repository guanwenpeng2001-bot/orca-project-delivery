---
name: integration-verification
description: Verify Task and final-delivery acceptance with commands, runtime evidence, integration checks, and explicit skipped items. Use before completion claims and final delivery.
---

# Integration Verification

## Core principle

A completion claim is only as strong as the fresh evidence behind it. Evidence must come from the branch and environment actually being delivered, and it must have been produced by running the thing, not recalled from an earlier run.

## Decision criteria

Verify against the acceptance criteria one by one, and record each as a row: the criterion, the command or action run, the observed result, and whether it passed. A criterion with no row is unverified, not passed.

Capture the environment with the result. Record the commit verified, the branch, and anything the result depends on such as runtime version, configuration, or seed data. A result that cannot be tied back to a commit cannot be trusted later, because the tree may have moved.

Treat skipped and flaky checks as first-class facts. Record each skipped check and the reason, and record any check that does not give the same result twice. Never convert a skip into a pass by omission, and never report a flaky check as green.

Match evidence freshness to the claim. Results from before the last change, results copied from another branch, and results remembered rather than rerun are not evidence for the current tree. Rerun when the tree has changed.

Choose the verdict from the rows, not from overall confidence:

| Verdict | When |
| --- | --- |
| READY | Every required criterion has a passing row from this commit |
| NOT_READY | A required criterion has a failing row |
| UNVERIFIABLE | A required criterion could not be run or confirmed |

A single unverifiable required criterion keeps the verdict at UNVERIFIABLE no matter how many others passed. Do not average a verdict out of mixed evidence.

### What counts as having run it

Exercise the behavior, not just its tests, where the acceptance criterion is about a flow. A unit test can pass while the wiring that connects it to the real entry point is broken. For a flow criterion, drive it through the entry point a real caller uses and record what happened, including the failure path: what the user or caller sees when a dependency fails, not only when it succeeds.

Confirm the tree is clean and relevant. The verification should run against the committed state being delivered, with no uncommitted local changes mixed in, because those will not be present for anyone else. Note the difference between "passes on my worktree" and "passes at the commit being reviewed."

### Reading a failure honestly

When a check fails, record the actual result rather than rerunning until it passes and reporting only the pass. An intermittent failure is a finding, not noise to be averaged away: if a test fails once in five runs, the criterion is not met and the report should say so. Rerun specifically to characterize flakiness, then report the flake rate, so the underlying defect gets fixed instead of hidden.

Separate pre-existing failures from ones the change introduced. A failing check that also fails on the baseline is worth naming but is not a regression; confirm which it is by checking the baseline rather than assuming.

## Workflow

1. Confirm the exact commit, branch, environment, and the acceptance criteria being verified.
2. Run the focused checks for the changed behavior.
3. Run the project's required gates: type checking, lint, build, and tests as applicable.
4. Exercise the critical flows and their failure paths.
5. Inspect the working tree to confirm the change contains nothing that should not ship.
6. Record every command, its result, and every skip or anomaly.
7. Return READY, NOT_READY, or UNVERIFIABLE based on the rows.

## Worked example

A task claims the export feature is complete.

The matrix, run at commit `a31f0c` on the task branch:

| Criterion | Command | Result |
| --- | --- | --- |
| Export contains only the caller's data | the export integration test | Pass, asserted row counts |
| Anonymous export is rejected | the same test file | Pass |
| Type checks clean | the project type-check command | Pass |
| Upgrade path from the previous schema | not run | Skipped: no database fixture in this environment |

Because the upgrade path is listed as required acceptance and could not be run, the verdict is UNVERIFIABLE, not READY. The report says exactly what is missing — a database fixture — so it can be resolved rather than rediscovered.

The earlier local test run from before the review fixes is not reused; the tests were rerun at `a31f0c`.

## Failure signals

- The report says "tests pass" with no command, no output, and no commit.
- A required criterion is simply absent from the report and the verdict is still READY.
- Results predate the latest commit on the branch.
- A flaky check is reported as passing because it passed once.
- The verdict is an average impression rather than a consequence of the rows.
- Verification was performed in a different worktree or branch from the one being delivered.

## Evaluation scenario

Given a completed task with four acceptance criteria where one cannot be run in the available environment, the result should show a matrix mapping each criterion to a command and an observed result, mark the one as skipped with the specific reason, record the commit, and return UNVERIFIABLE. It fails the method if the verdict is READY while that criterion is outstanding, or if the evidence cited comes from an earlier commit than the one being verified.

## Output

- Commit, branch, and environment
- Acceptance matrix: criterion, command, observed result, status
- Skipped checks and flake, with reasons
- Anomalies
- Verdict

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
