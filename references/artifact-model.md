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
    ├── dispatch-receipts/
    ├── dispatch-waves/
    │   └── <wave>.json
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
    │   └── git/
    │       ├── <task-key>.json
    │       └── run-final-verification.json
    ├── decisions.md
    └── final-report.md
```

## Ownership

Coordinator-only:

- lock, active run, run state;
- branch/task maps;
- `dispatch-receipts/`: capture `worker-start` receipts on the same command line that launches each worker;
- `dispatch-waves/<wave>.json`: write one record at dispatch time, never reconstruct it afterwards;
- accepted plan and decisions;
- final report;
- accepted `evidence/git/<task-key>.json` and the unique `evidence/git/run-final-verification.json`, written from observations before read-only validation.

Worker-exclusive path:

- the report/evidence path assigned to that Task.

## Dispatch wave records

A wave file records the coordinator's launch order and first-receipt routes: `waveId`, `runSlug`, `orcaRunId`, `waveStartedAt`, `waveRecordedAt`, `taskCount`, and ordered `tasks` entries keyed by `taskKey`. Entries may include requested model/effort, Orca Task/Dispatch IDs, start exit/state, `launchRequested`, `launchEffective`, and `recordedInLedger`; `parallelWindowSeconds` and `note` supply context. Unknown launch values remain null. The wave record is not lifecycle authority: Orca Runtime and its receipts remain authoritative for lifecycle and observed launch facts.

`schemas/dispatch-wave.schema.json` requires core identity, timestamps, count and task keys while allowing extension fields. `validate-run.ps1` validates every JSON file in the active run's `dispatch-waves/` directory when it exists. No wave file is mandatory; absent or empty directories remain valid for older runs and runs that dispatch no wave.

## Evidence references

Assignment `evidence.gitEvidencePath` points to Task evidence, normally `runs/<run>/evidence/git/<task-key>.json`; this optional field does not waive new Task evidence duties. Relative assignment paths and review `reportPath` resolve from `.dev-work`, while run-final `inputs.integratedEvidencePaths` resolve from `runs/<run>/`. Evidence JSON must stay within that run's `evidence/git/` subtree. Worker logs and reports are inputs, not accepted evidence records by themselves.

Task evidence states are source-registered, reviewed and integrated; pre-merge is a reviewed checkpoint. Final verification has one run-level record, and `final-report.md` references its target SHA, coverage, checks and verdict rather than duplicating final evidence per Task. Preserve historical observations and referenced reports/commits for audit. See `references/evidence-binding.md` for fields, selectors, stages and exit semantics.

## Promotion

A process artifact does not become tracked project documentation automatically. If a conclusion should enter project docs, create a separate reviewed source/documentation Task that removes run-specific details and follows project policy.
