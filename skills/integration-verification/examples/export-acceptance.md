# Export acceptance example

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
