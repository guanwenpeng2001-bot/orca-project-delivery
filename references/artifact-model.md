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
- branch/task maps;
- accepted plan and decisions;
- final report.

Worker-exclusive path:

- the report/evidence path assigned to that Task.

## Promotion

A process artifact does not become tracked project documentation automatically. If a conclusion should enter project docs, create a separate reviewed source/documentation Task that removes run-specific details and follows project policy.
