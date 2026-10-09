---
name: image-generation
description: Build and validate an offline OpenAI image-generation request, including missing credentials and provider failures. Use only for an explicitly authorized image task.
---

# Image Generation

## Core principle

A generation brief and a constructed request are not a generated image. Only a decoded provider response from an explicitly authorized call is output, and this package does not make that call.

## Decision criteria

State the subject, required text, aspect, and forbidden changes before choosing a model. A prompt is not ready while a required label or brand color remains implicit. Keep one provider per task. This package ships one example connector, OpenAI Images; it does not claim that OpenAI is the user’s production provider.

The script `skills/image-generation/scripts/openai-image-request.mjs` builds `POST https://api.openai.com/v1/images/generations` with bearer authentication. The pinned contract uses an explicit GPT image model, `size`, `quality`, and `output_format`. It removes legacy `response_format` because current GPT image models return base64 image data directly. The default model in the example config is `gpt-image-1.5`; a newer model must be named deliberately.

Missing `OPENAI_API_KEY` exits 2 and emits no request. A fixture status other than 200 exits 3 and writes no file. Timeout or transport failure must follow the same rule: no partial output presented as success. The script reads a local fixture and always reports `networkCalled: false`; it contains no transport call.

Configuration presence proves only that a value exists. It does not prove quota, model entitlement, or permission to spend money. A real call requires separate task authorization.

### Reference

Request construction was checked against the OpenAI OpenAPI document retrieved 2026-10-09 from https://raw.githubusercontent.com/openai/openai-openapi/master/openapi.yaml. This is an original connector, not a copied skill.

## Workflow

1. Write the brief and confirm the task permits generation and spending.
2. Build the request from the example script and a fixture.
3. Test missing key, success decoding, and provider failure.
4. For an authorized live run, replace the fixture with a reviewed transport and retain status and cost evidence.
5. Visually inspect subject, text, colors, and format; reject undeclared alterations.

## Worked example

The fixture requests a harbor otter at `1024x1024` with model `gpt-image-1.5` and PNG output. With a synthetic key, the script emits the bearer request and decodes `b64_json` to the expected PNG bytes. Removing the key exits 2 with `missing-key`. A 429 fixture exits 3 with `rate_limit_exceeded` and creates no file. No request leaves the machine.

## Failure signals

- The prompt or request JSON is delivered as the image.
- The connector claims a live provider call while `networkCalled` is false.
- A failure fixture still writes an image.
- Model entitlement or price is inferred from a populated environment variable.

## Evaluation scenario

Given the success, missing-key, and 429 fixtures, the result matches the URL and body, decodes one PNG, and writes nothing for either failure. It fails if any path contacts the network.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
