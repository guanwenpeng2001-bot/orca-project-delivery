---
name: image-generation
description: Generate and save an OpenAI image with offline fixtures and explicit online opt-in. Use only for an authorized image task.
---

# Image Generation

## Core principle

A prompt and request are not an image. Accept saved output only after checking the requested subject, text, format, and visual constraints.

## Decision criteria

State subject, exact labels, aspect, and forbidden changes first. OpenAI Images is one optional example, not a choice of production provider. Use Node 22.15+ for native fetch, Request, and FormData across these connectors.

`scripts/openai-image-request.mjs` sends `POST https://api.openai.com/v1/images/generations` with Bearer authentication and JSON. `OPENAI_IMAGE_MODEL` overrides the request's `model`, then the default is `gpt-image-1.5`. `output_format` defaults to `png` and supports `png`, `jpeg`, and `webp`; this single-output connector accepts `n=1` only. Other generation options such as `size` and `quality` are passed through. Legacy `response_format` is removed for GPT image models. Base64 must be canonical and match the requested image signature before saving.

Offline `--fixture JSON` uses an internal synthetic key without reading `OPENAI_API_KEY` or opening a socket. Real execution requires both `--online` and `CAPABILITY_ONLINE_PROVIDERS_ENABLED=true`, plus `OPENAI_API_KEY`; the modes are mutually exclusive. `--request JSON --output PATH` are required. `--timeout-ms` bounds request and body consumption (default 60000). Outputs are atomically replaced only after validation. Reports redact auth and identify `networkCalled`.

Exit 0 means bytes were saved; 1 means invalid input or filesystem failure; 2 means online disabled or missing key; 3 means HTTP, transport, or malformed-result failure; 4 means timeout. HTTP failures preserve status and provider error code. Config presence establishes neither quota nor authorization to spend. Selecting this Skill declares its non-secret gate/model settings and key through the existing requirements mechanism; use `templates/project-config.example.json` for the non-secret defaults.

### Reference

The request contract follows the OpenAI OpenAPI reference retrieved 2026-10-09: https://raw.githubusercontent.com/openai/openai-openapi/master/openapi.yaml. This is original implementation and method text.

## Workflow

1. Write the brief and confirm provider, budget, and content authorization.
2. Run the local fixture and negative cases first.
3. For an authorized live run, configure the chosen model and both runtime gates.
4. Save the result and check its header with `scripts/image-info.mjs --input FILE`, which reports format, width, height, alpha, and color type for PNG, JPEG, and WebP. Then visually inspect exact labels, subject, and format. Header data is not a decoded image: `image-info.mjs` never inflates pixels, and a file that passes it can still be corrupt.
5. Record actual status and output, without keys or claims of unverified quality.

## Worked example

From the package root, the following saves synthetic PNG fixture bytes with `networkCalled: false` and needs no provider credential:

```sh
node skills/image-generation/scripts/openai-image-request.mjs --request tests/fixtures/capability/openai-image-request.json --output otter.png --fixture tests/fixtures/capability/openai-image-success.json
```

The failure fixture `openai-image-failure.json` exits 3 with HTTP 429 and writes no file. For a separately authorized generation, replace `--fixture PATH` with `--online` after configuring the gate and key; no transport replacement is needed. A custom `OPENAI_IMAGE_MODEL` is sent as the actual request model.

## Failure signals

- A constructed request is delivered as an image.
- An HTTP error or invalid base64 leaves a new output file.
- Configured model differs from the model actually submitted.
- A synthetic fixture is described as live generation or visual-quality evidence.

## Evaluation scenario

Run `node --test tests/provider-transport.test.mjs tests/capability-repair.test.mjs`. Injected transport exercises the real executor, including exact auth/body, model override, saved bytes, disabled/missing auth, HTTP errors, malformed results, and body timeouts. No test uses a provider or real secret. `node skills/image-generation/scripts/image-info.mjs --input result.png` reports `{format, width, height, alpha, colorType}` from the header. Truncated PNG data, a JPEG without a start-of-frame marker, and a WebP whose chunk length runs past the file each exit 1. Signature validation and this header report are not a full image decoder; inspect a real authorized result before acceptance.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
