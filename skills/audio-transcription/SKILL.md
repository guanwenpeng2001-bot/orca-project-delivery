---
name: audio-transcription
description: Build and validate an offline ElevenLabs transcription request, including validation failure handling. Use only for an explicitly authorized transcript task.
---

# Audio Transcription

## Core principle

A transcript is evidence only after its text and timestamps are checked against the audio. A provider response can be fluent and still wrong.

## Decision criteria

Identify the audio, language expectation, and whether speaker separation is required before transcription. Do not upload audio to a provider without authorization covering that content. The example connector is ElevenLabs; it is not a decision that the user has chosen it for production.

The script posts to `https://api.elevenlabs.io/v1/speech-to-text` with `xi-api-key` and a multipart-equivalent body containing `model_id` and `filename`. The fixture model is `scribe_v2`. A 200 response must contain `text` and word entries with timing. A 422 validation fixture exits 3 and writes no transcript. The implementation reads fixtures only.

Word timestamps are sampled, not assumed correct because the field exists. Compare at least the beginning, one middle phrase, and the end with the audio. Speaker labels are accepted only if the task asked for separation and a sample was checked. Low-confidence or inaudible spans remain marked rather than being repaired from imagination.

The shared `ELEVENLABS_API_KEY` requirement does not authorize speech synthesis or a live request.

### Reference

The contract was checked against ElevenLabs documentation on 2026-10-09: https://elevenlabs.io/docs/api-reference/speech-to-text/convert. The implementation is original.

## Workflow

1. Confirm the audio may be sent and which transcript fields are required.
2. Validate the offline request and a 422 fixture.
3. For an authorized live run, submit the audio and retain the response status.
4. Sample text and timestamps against the source audio.
5. Mark uncertain spans instead of correcting them silently.

## Worked example

The fixture names `harbor.mp3` and model `scribe_v2`. The constructed request uses the speech-to-text URL and `xi-api-key`. A 422 body with `detail[0].type = value_error` exits 3 and does not create `transcript.json`. This proves failure handling only; it does not prove a real recording was transcribed.

## Failure signals

- A transcript is delivered without listening to any corresponding audio.
- Validation failure still writes a transcript file.
- Missing words are filled in because the sentence should contain them.
- Speaker labels are treated as verified without a sample check.

## Evaluation scenario

Given a 422 fixture, the result checks the endpoint, model, nonzero exit, and absent output file. It fails if it reports a live transcript from fixture input.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
