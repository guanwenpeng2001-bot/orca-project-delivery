---
name: generated-video
description: Submit, inspect, and download Pexo video work with offline fixtures and explicit online opt-in. Use for an authorized generated-video task.
---

# Generated Video

## Core principle

An asynchronous acknowledgement is not a video. Completion requires a final asset, successful download, and inspection of duration and content.

## Decision criteria

Confirm the brief, aspect, duration, provider, budget, and material allowed to leave the machine. Pexo is an optional example provider, not a production-vendor decision. This small connector operates on an existing project; project creation, uploads, and billing approval remain outside its interface.

The Node 22.15+ script `scripts/pexo-video-request.mjs` supports `--action submit|status|download` (default `submit`) and `--request JSON`. The request contains `project_id`; submit also needs `native_inputs.text`, and download needs `asset_id` and `--output PATH`. Optional `choices.preview_id` selects a preview; `with_watermark: true` requests a watermarked download. Authenticated calls are locked to `https://pexo.ai`; any different `PEXO_BASE_URL` is rejected.

Offline `--fixture JSON` uses a synthetic credential and never fetches or reads `PEXO_API_KEY`. Real execution requires both `--online` and `CAPABILITY_ONLINE_PROVIDERS_ENABLED=true`, plus `PEXO_API_KEY`. Fixture and online flags are mutually exclusive. `--timeout-ms` bounds the whole action (default 60000). JSON stdout redacts credentials and reports `networkCalled`; output is exposed only after atomic saving. Exit codes: 0 success or submission acknowledgement, 1 input/filesystem error, 2 disabled/config missing, 3 HTTP/response/provider failure, 4 timeout, 5 pending or user action required.

Submit checks project state, then sends `POST /api/chat` with Bearer auth, `timestamp` as epoch-millisecond text, `user_visible: true`, `native_inputs.text`, and `billing_confirmation_policy: {mode: "always"}`. It requires the `text/event-stream` response and `: stream opened` marker, then cancels that stream. It never auto-approves billing or retries submission. An already running project or pending confirmation is returned for explicit handling.

Status reads `GET /api/biz/projects/{id}` and, when action is needed, paginated `/history?page=1&page_size=50&sort_order=DESC`. Raw `executionStatus` and `serviceStatus` determine WAIT, RESPOND, CONFIRM, FAILED, RECONNECT, or DELIVER. Only the newest user round is considered; an INTERRUPTED project becomes DELIVER when that round contains `content.event=final_video` with `content.data.final_video_id`. Acknowledgements and older videos never qualify as this request's output. Poll WAIT at intervals of at least 60 seconds with an explicit overall deadline; do not resubmit automatically.

Download reads `/assets/{asset_id}`, then `/assets/{asset_id}/download-url?remove_watermark=true` under the project route. It downloads the returned HTTPS URL without forwarding the API credential, checks media content type and MP4/WebM signature, and saves to the exact caller path. Redirects fail explicitly. Media signatures do not prove playback or content quality. CONFIRM/RESPOND/RECONNECT require a user decision; billing approval is deliberately not automated by this connector.

### Reference

Independently implemented from the public `_common.sh`, `pexo-chat.sh`, `pexo-project-get.sh`, and `pexo-asset-get.sh` contracts at [Pexo commit f724267](https://github.com/pexoai/pexo-skills/tree/f724267e45a065b6be445ea6f07312e62d3207cd/skills/pexo-agent/scripts). No upstream scripts or Skill prose are copied.

## Workflow

1. Confirm authorized scope and an existing project ID.
2. Exercise fixture submission, failure, status, and download locally.
3. Only for an authorized provider run, enable both runtime gates and submit once.
4. Poll status until delivery, failure, deadline, or a user decision is required.
5. Download the final asset and inspect its media properties and content.

## Worked example

From the package root, this command remains offline and reports `submitted`, not a video:

```sh
node skills/generated-video/scripts/pexo-video-request.mjs --request tests/fixtures/capability/pexo-video-request.json --fixture tests/fixtures/capability/pexo-video-submitted.json
```

For a separately authorized run with environment configuration injected, replace `--fixture PATH` with `--online`. Status uses `--action status --request project.json --online`; `project.json` contains `{"project_id":"the-approved-project"}`. After a DELIVER result, use `--action download --request asset.json --output final.mp4 --online`, with `asset.json` containing that project ID and the returned `asset_id`. Exit 5 never means a saved video.

## Failure signals

- An acknowledgement or pending state is delivered as finished video.
- Polling resubmits the prompt or approves credits without a decision.
- A stale final-video event from a previous user round is accepted.
- A timeout, invalid SSE response, or failed download replaces an existing file.

## Evaluation scenario

Run `node --test tests/provider-transport.test.mjs` from the package root. Synthetic injected transports exercise the actual execution functions: auth, split SSE chunks and cancellation, state/history pagination, current-round final asset, download without auth forwarding, timeout, and malformed results. Fixtures prove protocol handling only; no provider entitlement, billing, live media quality, or real project has been verified.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
