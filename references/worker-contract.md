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
- Follow `templates/worker-report.md`'s quotation-fidelity rule: quote archived errors verbatim with their log path, preserving language and encoding; note omitted ANSI styling, and label any restatement as paraphrase without quotation marks.
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

## Lifecycle payloads and outcome vocabulary

The injected Orca preamble always wins when it differs from these examples. Copy its exact
executable, worker handle, Task ID, Dispatch ID, and any additional capability flag. The
installed `orchestration` Skill and command `--help` remain authoritative for exact syntax.

Send completion exactly once, with a three-sentence body: what changed, what was found,
and what remains. Orca accepts only `succeeded` or `failed`; never encode failure only in prose.
Append `--files-modified` and `--report-path` only when applicable, using actual paths.

```text
orca orchestration send --from <worker_handle> --type worker_done --subject "<short status>" --body "<three sentences: work, findings, remaining>" --task-id <task_id> --dispatch-id <dispatch_id> --outcome succeeded|failed
```

Send heartbeats at the live preamble's cadence; skip them while blocked in `ask` or
`check --wait`, which are liveness signals. Use typed lifecycle flags, not handwritten JSON.

```text
orca orchestration send --from <worker_handle> --type heartbeat --subject "alive" --task-id <task_id> --dispatch-id <dispatch_id> --phase "<investigating|implementing|reviewing|waiting>"
```

Escalate only before completion, when the coordinator must intervene.

```text
orca orchestration send --from <worker_handle> --type escalation --subject "Blocked: <reason>" --body "<details>" --task-id <task_id> --dispatch-id <dispatch_id>
```

Ask the coordinator through `ask`, never a local question TUI. `--options` and `--timeout-ms`
are optional. After a timeout or disconnect, resume the original message ID instead of
creating a duplicate question.

```text
orca orchestration ask --from <worker_handle> --question "<question>" --options "<choice-a>,<choice-b>" --timeout-ms 600000
orca orchestration ask --from <worker_handle> --resume <message_id> --timeout-ms 600000
```

The changed-file list of record is the task branch's committed diff (`git show --stat` / `git diff --stat <base>..<work>`); `--files-modified` is a hint that must agree with it. The coordinator reconciles both at source-evidence registration and records disagreements in `decisions.md`.

| Your verdict | What to send | What else to do |
| --- | --- | --- |
| `succeeded` | `--type worker_done --outcome succeeded` | attach `--files-modified` and `--report-path` when they are real |
| `failed` | `--type worker_done --outcome failed` | state the failure and evidence in the three-sentence summary |
| `blocked` | `--type worker_done --outcome failed` | before completion, send `--type escalation` or use `orca orchestration ask` when only the coordinator can decide; wait for its answer before settling |
| `unverifiable` | `--type worker_done --outcome failed` | before completion, send `--type escalation` naming exactly what could not be verified; a coordinator may then `worker-abandon` the attempt |

Lifecycle states such as `blocked` or `unverifiable` are **package vocabulary**. Project
them onto the Orca verbs above; do not invent new `--outcome` values.
