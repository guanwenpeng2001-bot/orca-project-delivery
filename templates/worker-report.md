# Worker Report: <task>

## Status

`SUCCEEDED | FAILED | UNVERIFIABLE | BLOCKED`

## Summary

<What was done or investigated.>

## Inputs Used

- <branch/commit/report>

## Changes or Findings

- <item with evidence>

## Files Changed

Derive this list from the task branch's committed diff, not memory; record the exact Git command and base/work revisions. For read-only Tasks, state that no source files changed and name the assigned report separately.

The changed-file list of record is the task branch's committed diff (`git show --stat` / `git diff --stat <base>..<work>`); `--files-modified` is a hint that must agree with it. The coordinator reconciles both at source-evidence registration and records disagreements in `decisions.md`.

- <path or none>

## Verification

Error text quoted in a report must be verbatim from the archived log, preserving the original language and encoding; ANSI styling may be omitted only with a note. Label a restatement as paraphrase and never place it in quotation marks. Every quoted error names its log path.

| Check | Command / method | Result | Evidence |
| --- | --- | --- | --- |
|  |  |  |  |

## Requested and Effective Runtime

- Requested Agent/model/effort:
- Effective Agent/model/effort:
- Verification evidence:
- Permission mode:
- Skill delivery mode:

## Deviations

<Any deviation from Task, Role, Skills, or project rules.>

## Residual Risks / Unknowns

- <item>

## Handoff

<What the coordinator or next worker must know.>
