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

## Final Verification

- Verifier Task and report: <release-verifier Task key and report path>
- Delivery branch / commit verified: <must match Delivery Branch above and the current delivery HEAD>
- Independent verification worktree and clean status:
- Commands run and results: <full suite and any additional checks, with exit codes>
- Verdict: <READY / NOT_READY / UNVERIFIABLE>

Final verification is the global barrier after all intended integrations; it never moves earlier and is never skipped. Unverifiable acceptance must not be described as READY.

## Runtime and Fallback Events

- <Agent/model changes, quota events, handoffs>

## Residual Risks

- <risk or none>

## Excluded / Deferred Work

- <item or none>

## Completion Status

`READY | NOT_READY | UNVERIFIABLE`
