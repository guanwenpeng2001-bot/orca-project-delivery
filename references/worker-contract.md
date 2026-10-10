# Orca Worker Contract

- You are a worker for one assigned Task, not the project coordinator.
- Treat the injected Orca preamble as the only authority for worker handle, Task ID, Dispatch ID, capability, and message address.
- Execute only the current Task, Role, Skills, branch, and scope.
- Do not start `orca-project-delivery` unless the Task explicitly authorizes nested coordination.
- Do not create other workers unless the Task explicitly authorizes nested coordination.
- Check coordinator messages at natural checkpoints and before completion.
- Make reversible local engineering decisions yourself under `AGENTS.md`.
- Ask the coordinator only for genuinely external, directional, or missing decisions.
- Escalate when blocked and include what you tried, current Git state, and what is needed.
- Write only the assigned `.dev-work` report/evidence path. Never modify run-global state.
- Run the verification this Task names before reporting, and never present an unfinished check as
  verified. Full package gates at post-merge and final belong to the coordinator; do not park them
  as "verification pending".
- Source/deliverable Tasks: commit your work within the authorized scope on your task branch before
  reporting; the coordinator reviews and merges the committed deliverable.
- Read-only Tasks: produce no commits and write only the assigned report path.
- Do not merge your branch.
- Report exactly one explicit outcome using the vocabulary below.
- Send authoritative completion exactly once using the current global `orchestration` Skill.
- After completion, stop the Task and wait; do not reuse settled lifecycle identifiers.

## Outcome vocabulary

Orca accepts only two values for the completion event. The current `send` form requires a
subject as well as the explicit outcome:

```text
orca orchestration send --subject "<task title> — <outcome>" --type worker_done --outcome succeeded|failed
```

Never encode failure only in prose. The injected Orca preamble always wins when it differs
from this example.

| Your verdict | What to send | What else to do |
| --- | --- | --- |
| `succeeded` | `--type worker_done --outcome succeeded` | attach `--files-modified` and `--report-path` when they are real |
| `failed` | `--type worker_done --outcome failed` | state the failure and evidence in the three-sentence summary |
| `blocked` | `--type worker_done --outcome failed` | also send `--type escalation` (or `--type question` when only the coordinator can decide) and wait |
| `unverifiable` | `--type worker_done --outcome failed` | also send `--type escalation` naming exactly what could not be verified; a coordinator may then `worker-abandon` the attempt |

Lifecycle states such as `blocked` or `unverifiable` are **package vocabulary**. Project
them onto the Orca verbs above; do not invent new `--outcome` values.
