---
name: speech-production
description: Synthesize and save ElevenLabs audio with offline fixtures and explicit online opt-in. Use only for an authorized narration task.
---

# Speech Production

## Core principle

Speech is accepted after checking requested words, voice, pronunciation, format, and duration. Transport success alone is not audible proof.

## Decision criteria

Prepare text for listening: clarify ambiguous abbreviations and unusual names, and break long sentences. Choose voice and language deliberately. ElevenLabs is an optional example connector, not the user's production-provider selection.

The Node 22.15+ script `scripts/elevenlabs-speech-request.mjs` accepts `--request JSON --output PATH`. JSON needs `voice_id`, `text`, and `model_id`; `output_format` defaults to `mp3_44100_128`. It posts JSON text/model to `https://api.elevenlabs.io/v1/text-to-speech/{voice_id}?output_format=...` with `xi-api-key`. The response is raw binary audio, not JSON or base64. It checks nonempty audio/octet-stream content and the MP3 signature for MP3 requests before atomically saving.

`--fixture JSON` is fully offline, uses an internal synthetic key, and never reads `ELEVENLABS_API_KEY`. Actual fetch requires `--online`, `CAPABILITY_ONLINE_PROVIDERS_ENABLED=true`, and `ELEVENLABS_API_KEY`; fixture and online modes cannot be combined. `--timeout-ms` covers request and response body (default 60000). Reports redact auth and state `networkCalled`. Exit 0 means saved output, 1 input/filesystem failure, 2 disabled or missing auth, 3 HTTP/transport/response failure, 4 timeout. No failed operation writes a new output.

The shared key also supports transcription but grants no authorization for either task. Check quota and costs before a separately authorized run. Audio signature checks do not establish decodability or pronunciation; listen to the result and use a media probe.

### Reference

Original implementation based on the ElevenLabs public contract checked 2026-10-09: https://elevenlabs.io/docs/api-reference/text-to-speech/convert.

## Workflow

1. Prepare text and name voice, model, and format.
2. Exercise fixture output and the executor's negative paths offline.
3. Configure both gates only for an authorized live synthesis.
4. Decode and listen to the complete clip against the source wording.
5. Retain output and format evidence without logging credentials.

## Worked example

From the package root:

```sh
node skills/speech-production/scripts/elevenlabs-speech-request.mjs --request tests/fixtures/capability/elevenlabs-speech-request.json --output speech.mp3 --fixture tests/fixtures/capability/elevenlabs-speech-success.json
```

The example requests `voice_example`, `eleven_multilingual_v2`, and “Harbor closed at dusk.” Fixture bytes have a synthetic ID3 prefix for transport testing; they are not a playable narration. In an authorized task use a real chosen voice and replace `--fixture PATH` with `--online` after setting gate/key. The same execution path writes the provider's actual binary response.

## Failure signals

- Test bytes are described as listened-to narration.
- A provider error creates an audio file or overwrites an existing one.
- Voice, language, or pronunciation changes go unreviewed.
- Credentials appear in a stdout report.

## Evaluation scenario

`node --test tests/provider-transport.test.mjs` checks exact request auth/body, raw audio saving, both gates, missing auth, HTTP failure, timeout, malformed response, and sanitized transport errors. Tests use injected transports only. Live voice entitlement, pronunciation, and codec quality remain unverified until an authorized listening check.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
