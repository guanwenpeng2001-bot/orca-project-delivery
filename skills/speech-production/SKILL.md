---
name: speech-production
description: Build and validate an offline ElevenLabs speech request and audio output handling. Use only for an explicitly authorized narration task.
---

# Speech Production

## Core principle

Speech output is accepted only when the requested words, voice, format, and pronunciation have been checked. A successful request construction is not audible proof.

## Decision criteria

Prepare text for listening. Expand abbreviations whose pronunciation is ambiguous, mark unusual names, and break long sentences. Decide the voice and language before requesting synthesis. Do not silently substitute a voice because it is the provider default.

The example script posts to `https://api.elevenlabs.io/v1/text-to-speech/{voice_id}?output_format=mp3_44100_128` with `xi-api-key` and JSON `text` and `model_id`. The default model in the fixture is `eleven_multilingual_v2`. This is the public ElevenLabs conversion contract. The script writes fixture audio locally and cannot contact the service.

Missing `ELEVENLABS_API_KEY` exits 2. A non-200 fixture exits 3 and writes nothing. The same key name is shared with transcription, but selecting speech does not authorize transcription and does not authorize a paid call.

For an authorized live run, listen to the complete clip, compare it with the source wording, and check format and duration. Reject clipped audio, wrong pronunciation of required names, or a format other than requested.

### Reference

The contract was checked against ElevenLabs documentation on 2026-10-09: https://elevenlabs.io/docs/api-reference/text-to-speech/convert. The implementation is original.

## Workflow

1. Prepare the spoken text and name the voice, model, and format.
2. Validate key absence and fixture decoding offline.
3. Obtain separate authorization before any live synthesis.
4. Listen to the result and compare required words.
5. Retain status and output format evidence without recording the key.

## Worked example

The fixture requests voice `voice_example`, model `eleven_multilingual_v2`, and `mp3_44100_128` for “Harbor closed at dusk.” The constructed URL contains both the voice and format, and the header is `xi-api-key`. The success fixture decodes to the bytes for `synthetic-audio`. A missing key stops before request construction. No audio is sent to ElevenLabs.

## Failure signals

- The script output is called a listened-to narration.
- A provider error still creates an audio file.
- The voice or language changes without being recorded.
- Required names are mispronounced and accepted because the request succeeded.

## Evaluation scenario

Given a success fixture and an empty key, the result checks the exact URL and header and proves the empty key writes no file. It fails on any network attempt.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
