---
name: game-audio
description: Design game sound as a mixing graph and a responsive music system with measured gain, ducking, variation, and timing. Use when balancing game audio, adding adaptive music, or diagnosing masking and repetitive effects.
---

# Game Audio

## 1. When to use / When not to use

Use to decide where sounds are routed, what the player must hear first, how music reacts to gameplay, and how to test the resulting mix. The working model has two cooperating parts: a mixing graph controls simultaneous sound, while a music system controls musical state and transitions.

Do not use this skill for engine API syntax, audio-device drivers, recording consent, or generation-service operations. Route file preparation to the asset pipeline and implementation details to project-side engine instructions. Without playable material and a declared listening context, propose a mix but do not certify its quality.

## 2. Novice orientation

A sound effect is one clip; a mix is what the listener hears when many clips play together. A bus groups sounds so one adjustment can affect, for example, all music without changing dialogue.

First session:

1. Select one short playable scene containing a repeated effect and music; add a spoken line only if the game uses dialogue. Record the intended output device and a comfortable fixed listening volume.
2. Route the music and effect to separate groups, then to the final output, following the project's audio setup instructions. Play each alone and together.
3. Lower music until the important gameplay cue is clear. Record the group gains in dB and observe the final output peak meter during the loudest overlap.
4. If dialogue exists, lower music temporarily while it plays, then restore it smoothly. Listen for abrupt jumps and repeated rises and falls.
5. Repeat the effect from several takes, then make one gameplay state change select a musical layer or section. Record what was heard and what remains untested.

First-session checklist: a routing list, a priority order, gain settings, one overlap recording or listening observation, and one transition observation. A missing output device leaves listening unassessed even if the routing code runs.

| Term | Meaning |
| --- | --- |
| Bus | A group of audio signals with shared gain and processing |
| dB gain | A logarithmic ratio describing amplification or attenuation |
| dBFS | Signal level relative to digital full scale; it is not a loudness score |
| Headroom | Margin between the observed output peak and its allowed ceiling |
| Ducking / sidechain | Lowering one group in response to activity detected in another |
| Stem | A synchronized musical part, such as percussion or melody |
| Quantization | Scheduling a change on a chosen beat, bar, or phrase boundary |
| Voice | One simultaneously playing sound instance, not necessarily speech |

## 3. Core method

### Design the mixing graph

Start with final output receiving Music, Effects, Ambience, Interface, and Dialogue groups as applicable. Record every source's destination, group processing, and any sends. Keep intended routes explicit so accidental duplicate paths do not double a signal. Player controls operate on the relevant groups, with master mute affecting the entire output.

Choose priorities from player information needs. A warning or instruction may outrank ambience; not every impact should trigger the strongest attenuation. Preserve a declared base mix, then combine player volume, state adjustments, and ducking without overwriting one another.

Use dB for mix gain and convert at the audio interface when necessary: for positive amplitude ratio `a`, `gain_dB = 20 * log10(a)` and `a = 10^(gain_dB / 20)`. Thus approximately -6 dB halves amplitude, not perceived loudness. Zero amplitude needs an explicit mute path; it cannot be passed through a finite logarithm. A slider's response curve is a product choice, not a value to assign directly as dB.

Measure the sum during worst-case overlap. Set a project peak ceiling below full scale and a loudness target appropriate to the delivery context; do not adopt a streaming-service loudness number as a universal game rule. A limiter is protection, not evidence that the underlying balance is correct.

### Make ducking composable

Specify the triggering group, affected groups, maximum reduction in dB, attack time, hold time if needed, and release time. Tune against actual overlap recordings. Too short a release can produce audible pumping; too slow an attack can hide the start of a spoken instruction.

For overlapping dialogue, attenuation remains active until the last relevant voice ends. Releasing one speaker must not restore music over another. On release, return to the current base mix combined with current player settings, not an old absolute volume. Test interruption, cancellation, pause/resume, and changing the volume slider while ducking.

### Drive music from gameplay state and the audio timeline

Choose one or combine both approaches:

- Layering: export stems on a shared musical timeline and schedule them from a common audio-clock origin. Fade parts to reflect intensity. Equal lengths and simultaneous frame callbacks alone do not prove sample alignment.
- Section changes: define an allowed transition graph between musical sections. For each edge, name its boundary, fade or bridge, and maximum response delay. Decide whether a newer request replaces or queues behind a pending one.

Map gameplay signals to a small set of musical states. Use separate enter/leave thresholds or a minimum dwell time where noisy signals would repeatedly switch state. Preserve immediate critical sound effects even when music waits for the next bar. Optional musical accents need their own priority and concurrency rules.

For constant tempo, beat duration is `60 / BPM` seconds. Compute boundaries relative to the track's musical origin on the audio clock; define whether a request exactly on a boundary uses it or the next one. Use a tempo map when tempo changes. Schedule ahead using the engine's documented latency behavior; measure audible alignment instead of assuming frame time equals playback time.

### Vary effects within their role

Build a small pool of appropriate takes for repeated actions. Use controlled selection, optionally preventing immediate repetition when at least two takes exist. Bound pitch and gain variation so cues retain identity; do not alter informational or musical pitch indiscriminately. Define per-event and total voice limits, priorities, and stealing or dropping rules. A protected warning should not disappear because footsteps exhausted the pool.

Test repeated triggers, dense overlaps, scene exit, and returning to silence. Finished or cancelled sounds must release their resources. Record memory and active voices against project budgets. Validate on headphones and speakers where both are supported, including the project's relevant device class; editor meters cannot establish intelligibility.

## 4. Failure criteria and measurable invariants

Choose numeric limits before running the scene: peak ceiling, voice cap, memory budget, transition timing tolerance, and ducking envelope tolerance. Record the scene, build, output device, settings, and observation window with each result.

- Measured peak must not exceed the declared ceiling; no clipped samples are accepted. Record sample-peak versus true-peak measurement explicitly rather than conflating them.
- Active voices never exceed the declared cap and return to the expected idle count after a defined cleanup interval.
- Overlapping speech keeps the requested attenuation until all triggering voices end; afterward gain returns within the declared release-time tolerance while preserving the current player volume.
- Music changes occur only on allowed edges and within the declared timing tolerance and response-delay limit. Stem offsets remain within the project's synchronization budget.
- A repeat-selection rule requiring no adjacent duplicates is tested only with pools of at least two valid takes; a one-take pool needs an explicit fallback decision.
- Missing audio, targets, device observations, or timing measurements produce `NOT ASSESSED - NO DATA` for the corresponding quality claim. Never derive a listening pass from a successful load. A known measured failure blocks acceptance; otherwise any missing mandatory observation blocks an overall pass.

Evaluation scenario: play two overlapping lines, change player music volume during the first, and finish that line while the second remains active. Music must stay attenuated, then recover to the newly selected base level. Repeat a musical transition under slow rendering; it must retain its declared audio-clock timing or report the measured deviation.

## 5. Platform/engine boundary

Locate engine audio, middleware, import, and device-testing instructions through project `AGENTS.md`, `externalSkills`, or `roleBindings`. Those sources own bus APIs, sample scheduling, streaming setup, device latency queries, and profiling commands. This method supplies the graph, transition contract, and test cases; it does not install middleware, invoke a media service, or authorize publishing or orchestration.

## 6. Sources and verification status

Consulted on 2026-10-23:

- [Audio discipline](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/38a4c2500eeb5ff9ac084336b8f66108069d2f8d/skills/disciplines/audio-design/SKILL.md) and [adaptive music reference](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/38a4c2500eeb5ff9ac084336b8f66108069d2f8d/skills/disciplines/audio-design/references/adaptive-music.md), Apache-2.0. Their bus/gain, ducking, musical layering/sections, effect variation, and audio-clock concepts informed this original method. No code or text passages were copied.
- [Assessment criteria source](https://github.com/Donchitos/Claude-Code-Game-Studios/tree/05ad7c8a5b8aa2aa86bbd3439ae7cf7295cac418), MIT. Only the missing-data refusal criterion informed the verdict rules.

Verification status: source concepts were verified by reading. The overlap, cleanup, timing, and listening checks are proposed project validation procedures, not results of a tested audio implementation. No universal loudness, timing, or device-performance claim follows from the source inspection.

Verify-current-policy checklist: verify rights for recordings and music before distribution, current middleware terms before adoption, and installed-version audio timing and platform output requirements before implementation. The upstream repository license does not license unrelated sound recordings.
