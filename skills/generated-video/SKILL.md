---
name: generated-video
description: Build and validate an offline Pexo asynchronous video submission, including timeout handling. Use only for an explicitly authorized video task.
---

# Generated Video

## Core principle

An asynchronous submission acknowledgement is not a video. The result is complete only when the authorized provider returns a retrievable output and its duration and content have been checked.

## Decision criteria

Write the shot as subject, action, duration, and aspect before submission. Ambiguous prompts produce confident but unusable footage. Keep one example provider in this package: Pexo. Its presence does not select Pexo as the user’s production vendor.

`skills/generated-video/scripts/pexo-video-request.mjs` builds `POST {PEXO_BASE_URL}/api/chat`, defaulting the base to `https://pexo.ai`, with `X-API-Key: $PEXO_API_KEY`. The body contains `project_id`, `user_visible`, and `native_inputs.text`. This matches the public Pexo agent script’s asynchronous submission shape. The fixture acknowledgement is `submitted`; polling remains a separate reviewed step.

Missing key exits 2. A timeout fixture exits 4 with `timeout` and no output. A non-200 fixture exits 3 and supplies no video URL. The script always sets `networkCalled` false and does not open a socket. A configured key proves neither quota nor permission to incur charges.

Once an authorized live implementation exists, poll until a terminal success or failure, retain the provider status, and inspect the downloaded video’s duration, resolution, and content. Never turn a polling timeout into a successful empty file.

### Reference

The request shape was compared with the public Pexo script on 2026-10-09: https://github.com/pexoai/pexo-skills/blob/main/skills/pexo-agent/scripts/pexo-chat.sh. This package reimplements only the request contract and does not copy that script.

## Workflow

1. Confirm authorization for provider, budget, and uploaded material.
2. Validate missing-key, submitted, and timeout fixtures offline.
3. Add a live transport only in a separately authorized task.
4. Poll to a terminal state and retain provider evidence.
5. Inspect the media before accepting it.

## Worked example

The fixture submits project `project_example` with the text “A five second harbor wide shot.” Using a synthetic key and `https://pexo.example`, the request targets `/api/chat` and reports the submitted acknowledgement. The timeout fixture exits 4 and contains no output field. No live polling or download occurs.

## Failure signals

- The acknowledgement is described as rendered video.
- Timeout produces a zero-byte file treated as success.
- The report claims a network call the script cannot make.
- Provider, price, or upload permission is inferred from configuration.

## Evaluation scenario

Given submitted and timeout fixtures, the result checks the URL, header, async status, and absence of output after timeout. It fails if either fixture uses the network.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
