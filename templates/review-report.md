# Independent Review: <target>

## Verdict

`APPROVED | CHANGES_REQUIRED | UNVERIFIABLE`

## Scope

- Baseline:
- Target:
- Task:
- Requirements:
- Skills used:

## Commit Binding

Replace placeholders with observations from the actual review target. Set dirty from Git status; APPROVED requires false. This JSON mirrors one `reviews[]` entry; the coordinator writes accepted evidence and validates it. The validator checks report existence, not this block's contents, so reconcile both explicitly.

```json
{
  "reviewTaskKey": "<review-task-key>",
  "reviewer": { "taskId": "<reviewer-task-id>", "dispatchId": "<reviewer-dispatch-id>" },
  "verdict": "<APPROVED-or-CHANGES_REQUIRED-or-UNVERIFIABLE>",
  "reportPath": "runs/<run>/reviews/<review-task-key>.md",
  "target": { "branch": "<reviewed-branch>", "commitSha": "<40-lowercase-hex-target-sha>", "dirty": false },
  "baseline": { "branch": "<baseline-branch>", "commitSha": "<40-lowercase-hex-baseline-sha>" },
  "recordedAt": "<ISO-8601-UTC>"
}
```

- Target HEAD/status observation commands and results:
- Baseline SHA and ancestry evidence:
- Reviewer Task/Dispatch differs from the source worker's:
- Source Task evidence path:

## Findings

### <severity>: <title>

- Location:
- Requirement or invariant:
- Evidence:
- Impact:
- Reproduction/reasoning:
- Suggested direction:
- Confidence:

## Checks Performed

- <check>

## Test Assessment

- Behavior covered:
- Missing or weak tests:
- Commands/results:

## Re-review

For repair rounds, resume the original reviewer session after the original implementer completes the fix, following [Session reuse](../references/worker-handoff.md#fix-returns-to-original-implementer-session). Keep both terminals retained until the final verdict. Bind the verdict above to the current target SHA; prior context and approval do not replace fresh evidence.

- Previous review report and target SHA:
- Fix Task/Dispatch and implementation report:
- Original implementer session resumed (terminal/worktree):
- Original reviewer session resumed (terminal/worktree):
- Cold-session fallback reason and recovery evidence, if applicable:
- Exact reviewed diff (`base..branch`, both SHAs) and fix delta:
- Finding-by-finding closure and regression evidence:
- Task-relevant verification commands, results and skipped checks:

## Residual Risks

- <item>
