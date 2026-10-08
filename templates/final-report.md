# Delivery Report: <run>

## Objective

<Original objective.>

## Delivery Branch

`<branch>` at `<commit>`

## Delivered Changes

- <change>

## Workflow Summary

- Reconnaissance:
- Decisions:
- Implementation:
- Review/fix rounds:
- Integration:
- Final verification:

## Verification Evidence

| Criterion | Result | Evidence |
| --- | --- | --- |
|  |  |  |

## Run-final Evidence

- Canonical record: `evidence/git/run-final-verification.json` (relative to this run; coordinator-owned, unique)
- `target.branch` / `target.commitSha`: <must match Delivery Branch above and latest delivery at final validation>
- Independent verification `worktree` and clean HEAD/status observations:
- `status`: <planned / in_progress / verified / blocked>
- `coverage.integratedTaskKeys`: <all integrated Task keys exactly once; nonempty for acceptance>
- `coverage.uncoveredTaskKeys`: <must be empty for acceptance>
- `inputs.integratedEvidencePaths`: <all integrated evidence paths exactly once, relative to this run; nonempty>
- `checks[]`: <actual commands, exit codes, observed summaries, UTC times and commitSha; verification at target.commitSha>
- `recordedAt` / `verdict`: <from canonical record>
- Validator command: `pwsh -NoProfile -File <package>/scripts/validate-git-evidence.ps1 -ProjectRoot <control-worktree> -Run <run> -Phase final`
- Validator exit code / JSON status / errors / reason:

Write observations and evidence before validation. READY requires verified + READY in the record, complete intended coverage and final-scope PASS; exit 0 with NOT_APPLICABLE is not acceptance. A single Task's final-phase result is insufficient. Historical integration headAfter values need only be ancestors of the final target, not equal to it. Link existing Task evidence; do not create per-task final records. If no integration lifecycle applies, explain NOT_APPLICABLE and the actual verification scope without manufacturing empty READY evidence.

## Runtime and Fallback Events

- <Agent/model changes, quota events, handoffs>

## Residual Risks

- <risk or none>

## Excluded / Deferred Work

- <item or none>

## Completion Status

`READY | NOT_READY | UNVERIFIABLE`
