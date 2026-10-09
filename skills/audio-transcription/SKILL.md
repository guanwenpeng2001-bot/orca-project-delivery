---
name: audio-transcription
description: Upload an audio file as multipart data and save an ElevenLabs transcript with offline fixtures and explicit online opt-in.
---

# Audio Transcription

## Core principle

A transcript is evidence only after its wording and timestamps are checked against audio. A fluent provider response can still be wrong.

## Decision criteria

Identify source audio, language expectations, and any speaker-separation requirement. Authorization must cover that audio leaving the machine. ElevenLabs is an optional connector, not a production-provider decision. This small example requests the provider's default transcription options with an explicit model; specialized diarization settings require an explicit extension.

The Node 22.15+ script `scripts/elevenlabs-transcription-request.mjs` accepts `--request JSON --audio PATH --output PATH`. Request JSON contains `model_id`, for example `scribe_v2`. It sends `POST https://api.elevenlabs.io/v1/speech-to-text` with `xi-api-key` and actual FormData parts `model_id` and `file`. The file part includes the local bytes and basename; there is no standalone `filename` form field. Native Request serialization supplies the multipart boundary. Do not set the Content-Type boundary yourself.

`--fixture JSON` needs no credential and never reads `ELEVENLABS_API_KEY` or contacts the service. Actual execution requires both `--online` and `CAPABILITY_ONLINE_PROVIDERS_ENABLED=true`, plus `ELEVENLABS_API_KEY`. The modes are mutually exclusive. `--timeout-ms` bounds the whole operation (default 60000). Reports redact auth and expose only multipart field names, model and basename, not audio bytes. The saved JSON is `{text, words}`; text must be a string and every word must contain text and finite nonnegative start/end times with end >= start. Empty text/words is valid for silence.

Exit 0 means a validated transcript was saved atomically; 1 means input/filesystem failure; 2 means disabled or missing key; 3 means HTTP/transport/malformed result; 4 means timeout. All failure paths leave existing output intact. Configuration proves neither permission to upload nor quota.

Sample the beginning, a middle phrase, and the end against the audio. Do not invent inaudible words. A valid timestamp shape is not proof of alignment; accept speaker labels only when requested and checked.

### Reference

Original implementation based on the ElevenLabs contract checked 2026-10-09: https://elevenlabs.io/docs/api-reference/speech-to-text/convert.

## Workflow

1. Confirm permitted audio and required transcript fields.
2. Exercise success and failure fixtures offline using a selected local audio input.
3. For an authorized call, set both runtime gates and upload once.
4. Compare sampled words and timestamps against the source.
5. Mark uncertain spans and retain output/status evidence.

## Worked example

From the package root, with an existing local `sample.wav`:

```sh
node skills/audio-transcription/scripts/elevenlabs-transcription-request.mjs --request tests/fixtures/capability/elevenlabs-transcription-request.json --audio sample.wav --output transcript.json --fixture tests/fixtures/capability/elevenlabs-transcription-success.json
```

The fixture yields “Harbor” and a word spanning 0 to 0.5 seconds; it does not transcribe the chosen file. The failure fixture `elevenlabs-transcription-failure.json` returns HTTP 422 and writes nothing. For an authorized live task, replace `--fixture PATH` with `--online` after configuring gate/key. The multipart upload and response-save functions are the same ones used by offline injected-transport tests.

## Failure signals

- A JSON filename is sent instead of audio bytes.
- A malformed or failed response creates a transcript.
- Fixture text is reported as transcription of the chosen local file.
- Unchecked timestamps or speaker labels are described as verified.

## Evaluation scenario

Run `node --test tests/provider-transport.test.mjs tests/capability-repair.test.mjs`. Tests deserialize the real Request multipart body, compare uploaded bytes/model, and inspect the saved successful transcript. Disabled mode, missing auth, HTTP failure, timeout, malformed word timing, and no-output failures remain offline and use synthetic credentials.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
