# Agent Failure Taxonomy

Each classification is a **package-local** label. The right-hand column names the Orca
surface that carries the evidence or the action — current global `orchestration` Skill and
`--help` remain authoritative for exact syntax.

## Installation and platform

| Classification | Orca evidence / action |
| --- | --- |
| `binary_missing` | `worker-start` receipt `failedStage` (`agent_unconfigured`), `resolves to no binary` style errors, or the capability probe's `detected: false` |
| `platform_unsupported` | `agents/registry.json` `unsupportedRuntimes`; probe notes "Unsupported on runtime win32" |
| `required_command_missing` | probe `missingRequiredCommands` (for example the `dsh` requirement behind `dsh-tui`) |

## Access and configuration

| Classification | Orca evidence / action |
| --- | --- |
| `auth_missing` | Agent CLI auth error in `worker-read`; no Orca primitive — fix credentials or pick another profile |
| `model_unavailable` | `worker-start` receipt: `launch.requested` vs `launch.effective` mismatch |
| `effort_unsupported` | same receipt fields; `--effort` requires `--model` and is refused for agents outside Claude/Codex/Cursor/Antigravity/Muse |
| `permission_blocked` | agent prompt/refusal in `worker-read`; adjust the Orca permission mode or the Task scope |
| `trust_blocked` | agent trust preflight text; repair trust before changing agent |
| `skill_unavailable` | worker reports the Skill path was unreadable; fall back to `explicit-path` or `inline-extract` (see `agents/skill-loading.json`) |

## Startup and delivery

| Classification | Orca evidence / action |
| --- | --- |
| `prompt_delivery_failed` | `worker-read --source transcript` shows no injected spec; repair topology or re-dispatch |
| `readiness_failed` | `worker-show.observation.status`; `terminal wait --for tui-idle` timed out before injection |
| `turn_start_unobserved` | `worker-start` receipt `state: outcome_unknown` / `stage: turn_start_unobserved`; `worker-show` reports `worker.state: start_unknown` and `projection.liveness.verdict: unverifiable`; the terminal preview still holds `[Pasted Content N chars]` with no turn output. Inspect first; when the task was accepted but never submitted, submit it in the **same** terminal (send a bare Enter). This is unobserved, not failed: never re-dispatch, stop, or abandon from it |
| `process_exited` | `worker-show`/`worker-list` liveness `exited`, or the worker observed its own exit |

## Capacity

| Classification | Orca evidence / action |
| --- | --- |
| `rate_limited` | explicit rate-limit text captured from the worker transcript; bounded backoff, then the next profile |
| `quota_exhausted` | explicit quota text with a reset window; disable the profile **for the run** and fall back |

## Task execution

| Classification | Orca evidence / action |
| --- | --- |
| `worker_failed` | `worker_done --outcome failed` from the active Dispatch |
| `worker_blocked` | `escalation` or `question` message from the worker |
| `consumer_fenced` | Orca lifecycle verb: a fenced consumer generation; the attempt is authoritative no longer |
| `unverifiable` | liveness `unverifiable` / `missing_status`, or a null `agentWait` — absence, not proof |

## Evidence requirements

Do not classify quota or rate limit from silence. Capture the exact terminal/runtime evidence.

Do not classify a Worker as stopped from a timeout alone. Use the authoritative Orca
projection (`worker-show`, `worker-list` with `projection.liveness` / `projection.attention`),
an observed process exit, fencing, or an explicit handoff.

Only positive proof of exit authorizes `worker-stop`, `worker-abandon`, retry, or release.
`unverifiable` authorizes none of them.

## Action

Use `agents/fallback-policy.json`. Every degradation event records:

- time;
- Task/Dispatch;
- classification (package label) plus the Orca evidence above;
- evidence;
- prior profile;
- selected action/profile;
- whether the user had pinned the choice;
- handoff path for writing Tasks.
