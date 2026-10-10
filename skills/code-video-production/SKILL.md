---
name: code-video-production
description: Author and render a local HyperFrames code video with explicit timing and media acceptance commands. Use for HTML-authored code explainers.
---

# Code Video Production

## Core principle

A code video is a timed sequence with measured duration, dimensions, and readable code states. A plan or browser preview is not a rendered video.

## Decision criteria

Use HyperFrames for HTML/CSS compositions rendered through a local browser and FFmpeg. The renderer is Apache-2.0 and not vendored here. Node 22+, the `hyperframes` executable, Chrome/headless browser, FFmpeg and FFprobe are required for rendering. Dependency presence is not proof a render succeeded.

Plan exact frame ranges. At 30 fps, ten seconds is 300 frames. Hold code still long enough to read; transitions must not be the only view of a changed line. Keep code large at the target dimensions. Use local fonts and media. No hosted voice, stock asset, cloud renderer, or publishing command is implied.

Before rendering, check the composition's timing with `skills/code-video-production/scripts/composition-check.mjs`. It reads the HTML and prints a frame map. It never renders anything, so it runs without HyperFrames or a browser.

```
node skills/code-video-production/scripts/composition-check.mjs --input index.html --fps 30
```

`--fps` is an integer or a rational such as `24000/1001`. When it is omitted, the root `data-fps` is used. With neither, the check exits non-zero.

The grammar it accepts is deliberately smaller than HyperFrames:

| Accepted | Rejected, named on stderr |
| --- | --- |
| Exactly one element carrying `data-composition-id` | A second composition root |
| Root `data-start="0"`, numeric `data-duration`, `data-width`, `data-height` | A missing or non-numeric value |
| Clips with numeric `data-start`, `data-duration`, and integer `data-track-index` | A clip-time reference such as `intro + 2` |
| Durations that land on whole frames at the declared rate, including a decimal such as `4.1` at 30 fps | A duration between two frames, such as `10.016` at 30 fps |

Frame mapping is exact: a clip's frames are `[start x fps, (start + duration) x fps)`, so a clip ending at second 3 and the next starting at second 3 share no frame. Two clips on the same track whose ranges overlap are rejected, because one hides the other. The same overlap across two tracks is intentional — a caption over a code state — and is reported in `warnings` rather than rejected. A gap inside a track is a warning; a gap that leaves the composition's end uncovered is an error. A clip that runs past the composition's end is a warning, not an error: the report names the overrun and the frame map still counts the clip's own frames, because a renderer may clip the tail.

The report is `{compositionId, fps, frames, width, height, clips, warnings}`. Each clip carries `startFrame` and `endFrame`. `fps` is a number for an integer rate and the rational text otherwise.

### Audio, subtitles, and transitions

Audio and subtitles are separate timed clips, not features of the code clips. Give each its own `data-track-index`: narration on one track, the subtitle cue track on another. Their overlap with the code states is the cross-track case above and is allowed. A transition is a clip that overlaps the two states it joins; it needs its own track, and the states it joins must each remain readable on their own for part of their range. This check counts frames. It does not play audio or render the transition.

### Reference

Original method based on the HTML composition contract and CLI source at [HyperFrames commit 46f6cb3](https://github.com/heygen-com/hyperframes/tree/46f6cb356785bed79e1ce7b79d7e7accc697786a), package version 0.8.143, Apache-2.0. Public `render.ts` defines the directory, output, fps, strict, and no-best-effort options used below; no upstream Skill text is copied. The attribute rules follow the published composition reference: `data-track-index` selects a display lane and does not decide paint order, and a clip is visible over the half-open interval `[start, start + duration)`.

## Workflow

1. Define code states, duration, frame ranges, and resolution.
2. Author a local composition and keep network assets out of it.
3. Run the composition check and resolve every warning before rendering.
4. Check tools and render with explicit fps and strict validation.
5. Probe/decode the video and inspect representative frames.
6. Report unavailable dependencies or render failures as unverified, never as completed media.

## Worked example

When authoring or running a local render, load [Local code video render](examples/local-render.md) for the full composition, pinned CLI and render/probe/decode commands.

Require renderer/decode exit 0 and measured dimensions, fps, frame count and duration within one frame of the plan. Inspect representative PNGs for legibility/clipping and transition boundaries; check expected audio. Install dependencies only when allowed. A missing CLI/browser/codec leaves render acceptance unverified even if HTML looks correct.

## Failure signals

- Timing lacks frame counts or assets depend on an unapproved network service.
- Code overflows or becomes unreadable at output size.
- A screen recording is presented as a deterministic render.
- Planned commands or previews are reported as produced media.
- A composition check that rejects a deliberate cross-track overlap, such as a caption over code.

## Evaluation scenario

When maintaining this Skill or its checker, load [Code video evaluation](references/evaluation.md) for package regression commands and expected cases.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
