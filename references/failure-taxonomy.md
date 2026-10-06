# Failure Taxonomy

Each classification is a **package-local** label. The right-hand column names the Orca
surface that carries the evidence or the action — current global `orchestration` Skill and
`--help` remain authoritative for exact syntax.

## Installation

| Classification | Orca evidence / action |
| --- | --- |
| `binary_missing` | `worker-start` receipt `failedStage` (`agent_unconfigured`), explicit binary-resolution errors, or capability probe evidence that the Claude CLI is missing; repair installation |

## Access and configuration

| Classification | Orca evidence / action |
| --- | --- |
| `auth_missing` | Claude CLI auth error in `worker-read`; repair credentials, not a capacity-based downgrade |
| `model_unavailable` | Explicit model-unavailable text or receipt; apply `routing/model-routing.json` policies, excluding that tier's chain entries while respecting the Role floor and user pins |
| `effort_unsupported` | Explicit Orca parameter rejection for the requested model/effort; consult `routing/model-routing.json` model-tier rules and the installed Orca contract |
| `launch_mismatch` | First `worker-start` receipt `launch.effective` differs from requested model/effort; record `mismatch`, do not infer quota or model unavailability; use the configured model-tier rule, or suspend and ask for a user-pinned choice |
| `permission_blocked` | Claude permission prompt/refusal in `worker-read`; inspect Claude configuration, user Orca settings, and Task scope; do not invent a `worker-start` permission flag |
| `trust_blocked` | Claude trust preflight text; repair trust before retrying |
| `skill_unavailable` | Worker reports the explicit Skill path was unreadable; repair the path or use a recorded `inline-extract` (see `references/installation.md`) |

## Startup and delivery

| Classification | Orca evidence / action |
| --- | --- |
| `prompt_delivery_failed` | Worker transcript shows no injected spec; inspect and repair delivery in the same terminal first; any retry must satisfy the evidence and handoff requirements below |
| `readiness_failed` | Worker observation or terminal wait timed out before injection; inspect readiness, do not infer process exit |
| `turn_start_unobserved` | `worker-start` receipt `state: outcome_unknown` / `stage: turn_start_unobserved`; `worker-show` reports `worker.state: start_unknown` and `projection.liveness.verdict: unverifiable`; the terminal preview still holds `[Pasted Content N chars]` with no turn output. Inspect first; when the task was accepted but never submitted, submit it in the **same** terminal (send a bare Enter). This is unobserved, not failed: never re-dispatch, stop, or abandon from it |
| `process_exited` | `worker-show`/`worker-list` liveness `exited`, or the worker observed its own exit |

## Capacity

| Classification | Orca evidence / action |
| --- | --- |
| `rate_limited` | Explicit rate-limit text captured from the worker transcript; apply the bounded same-tier backoff in `routing/model-routing.json` policies |
| `quota_exhausted` | Explicit quota text or receipt; apply `routing/model-routing.json` policies to exclude that tier's chain entries and select only an eligible entry at or above the Role floor |

## Task execution

| Classification | Orca evidence / action |
| --- | --- |
| `worker_failed` | `worker_done` with outcome `failed` from the active Dispatch |
| `worker_blocked` | `escalation` or `question` message from the worker |
| `consumer_fenced` | Orca lifecycle verb: a fenced consumer generation; the attempt is authoritative no longer |
| `unverifiable` | Liveness `unverifiable` / `missing_status`, or a null `agentWait` — absence, not proof |

## Evidence requirements

Do not classify quota or rate limit from silence. Capture the exact terminal/runtime evidence.

Do not classify a Worker as stopped from a timeout alone. Use the authoritative Orca
projection (`worker-show`, `worker-list` with `projection.liveness` / `projection.attention`),
an observed process exit, fencing, or an explicit handoff. Stop, abandon, retry, and release
must follow the installed Orca contract and authoritative state; `unverifiable` alone
authorizes none of them. Before replacing a writer, follow `references/worker-handoff.md`.

## Action

Use the degradation procedure in `SKILL.md` and the policies in `routing/model-routing.json`.
User-pinned model/effort choices permit no automatic upgrade or downgrade; rejection or
mismatch requires suspension and a question. If no eligible chain entry remains at or above
the floor, or the same Task reaches its same-class failure circuit breaker, suspend that Task,
record the event, and keep independent Tasks running. Never create a second concurrent writer.

Every degradation event in `degradation-events.json` records:

- time;
- Task/Dispatch;
- classification (package label) plus the Orca evidence above;
- evidence;
- prior model/effort;
- selected action/model/effort;
- whether the user had pinned the choice;
- handoff path for writing Tasks.

Each dispatch also records literal requested values and first-receipt effective values in
`assignments/<task>.json`; unverified effective values remain null.
