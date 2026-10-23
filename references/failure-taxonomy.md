# Failure Taxonomy

Each classification is a **package-local** label. The right-hand column names the Orca
surface that carries the evidence or the action — current global `orchestration` Skill and
`--help` remain authoritative for exact syntax.

## Installation

| Classification | Orca evidence / action |
| --- | --- |
| `binary_missing` | `worker-start` receipt `failedStage` (`agent_unconfigured`), explicit binary-resolution errors, or evidence that the selected Agent CLI is missing; repair installation |

## Access and configuration

| Classification | Orca evidence / action |
| --- | --- |
| `auth_missing` | Agent CLI auth error in `worker-read`; repair credentials, not a capacity-based downgrade |
| `model_unavailable` | Explicit model-unavailable text or receipt; respect user pins; diagnose the Agent configuration without selecting a package-defined replacement model |
| `effort_unsupported` | Explicit Orca parameter rejection for the requested model/effort; check the explicit user request and installed Orca contract; never add effort to a default launch |
| `launch_mismatch` | First `worker-start` receipt `launch.effective` differs from the requested Agent or explicit user model/effort pin; record `mismatch` and resolve the pin with the user. Unknown unrequested model/effort is not a mismatch |
| `permission_blocked` | Agent permission prompt/refusal in `worker-read`; inspect Agent configuration, user Orca settings, and Task scope; do not invent a `worker-start` permission flag |
| `trust_blocked` | Agent trust preflight text; repair trust before retrying |
| `skill_unavailable` | Worker reports the explicit Skill path was unreadable; repair the path or use a recorded `inline-extract` (see `references/installation.md`) |

## Startup and delivery

| Classification | Orca evidence / action |
| --- | --- |
| `prompt_delivery_failed` | Worker transcript shows no injected spec; inspect and repair delivery in the same terminal first; any retry must satisfy the evidence and handoff requirements below |
| `readiness_failed` | Worker observation or terminal wait timed out before injection; inspect readiness, do not infer process exit |
| `turn_start_unobserved` | `worker-start` receipt `state: outcome_unknown` / `stage: turn_start_unobserved`; `worker-show` reports `worker.state: start_unknown` and `projection.liveness.verdict: unverifiable`; the terminal preview still holds `[Pasted Content N chars]` with no turn output. Inspect first; when the task was accepted but never submitted, submit it in the **same** terminal (send a bare Enter). This is unobserved, not failed: never re-dispatch, stop, or abandon from it |
| `process_exited` | `worker-show`/`worker-list` liveness `exited`, or the worker observed its own exit |
| `wait_channel_lost` | `check --wait` returned `runtime_unavailable` ("the Orca runtime closed the connection before responding") before its timeout, often mid-wait with a 0-byte receipt file and `disposition: outcome_unknown`. This classifies the **wait**, never the worker: run the receipt's `request-show` → `--retry-request` recovery block in the same terminal, reconcile on-disk reports, and do not downgrade, re-dispatch or abandon from it |

## Capacity

| Classification | Orca evidence / action |
| --- | --- |
| `rate_limited` | Explicit rate-limit text captured from the worker transcript; follow the Agent/runtime recovery guidance within the Task budget; do not choose a model ladder |
| `quota_exhausted` | Explicit quota text or receipt; record the evidence and recover within scope; unavailable user-pinned choices require a user decision |

## Task execution

| Classification | Orca evidence / action |
| --- | --- |
| `worker_failed` | `worker_done` with outcome `failed` from the active Dispatch |
| `worker_blocked` | `escalation` or `question` message from the worker |
| `consumer_fenced` | Orca lifecycle verb: a fenced consumer generation; the attempt is authoritative no longer |
| `unverifiable` | Liveness `unverifiable` / `missing_status`, or a null `agentWait` — absence, not proof |

## Evidence requirements

Do not classify quota or rate limit from silence. Capture the exact terminal/runtime evidence.

Inspect authoritative Orca projections (`worker-show`, `worker-list` with `projection.liveness` / `projection.attention`). Route unknown mutations, duplicate/late completions, invisible workers, proven failures, cancellation and unknown locks to [Scenario principles](recovery-and-idempotency.md#scenario-principles). Stop, abandon, retry and release require the installed Orca contract and positive evidence; `unverifiable` alone authorizes none.

Writer replacement or retry must pass the [writer-replacement gate](recovery-and-idempotency.md#writer-replacement-hardened-gate), then use [Writing Task handoff](worker-handoff.md#writing-task-handoff) for capture and takeover.

## Action

Use the recovery procedure in `SKILL.md` and the installed Orca contract. The package does not choose model/effort replacements. A user-pinned Agent/model/effort permits no automatic substitution; rejection, mismatch or missing proof that the pin was honored requires a question. Keep independent Tasks running, and never create a second concurrent writer.

Every recovery event in `degradation-events.json` records:

- time;
- Task/Dispatch;
- classification (package label) plus the Orca evidence above;
- evidence;
- prior Agent and any available launch values;
- selected recovery action;
- whether the user had pinned the choice;
- handoff path for writing Tasks.

Each dispatch also records literal requested values and first-receipt effective values in
`assignments/<task>.json`; unverified effective values remain null.
