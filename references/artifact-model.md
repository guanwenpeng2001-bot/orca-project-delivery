# `.dev-work` Artifact Model

## Location

Only the coordinator control worktree contains `.dev-work/`.

## Standard layout

```text
.dev-work/
├── manifest.json
├── active-run.json
├── coordinator-lock.json
├── config/
├── runtime/
└── runs/<run>/
    ├── run-state.json
    ├── branch-map.json
    ├── task-map.json
    ├── assignments/
    ├── attempts/
    ├── handoffs/
    ├── reconnaissance/
    ├── audits/
    ├── designs/
    ├── plans/
    ├── task-briefs/
    ├── worker-reports/
    ├── reviews/
    ├── verification/
    ├── evidence/
    ├── decisions.md
    └── final-report.md
```

## Ownership

Coordinator-only:

- lock, active run, run state;
- branch/task maps and assignments;
- accepted plan and decisions;
- final report.

Worker-exclusive path:

- the report/evidence path assigned to that Task.

## Record resolution

Relative assignment paths and review `reportPath` values resolve from `.dev-work`. Worker logs and reports stay under the run directory they were assigned; the coordinator links them from the final report rather than duplicating them.

## Promotion

A process artifact does not become tracked project documentation automatically. If a conclusion should enter project docs, create a separate reviewed source/documentation Task that removes run-specific details and follows project policy.
