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

In a separate writable project directory, save this original composition as `index.html`. The three states occupy frames 0–89, 90–209, and 210–299 at 30 fps. Static clips avoid wall-clock animation nondeterminism.

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Code Change</title>
<style>
html, body { margin: 0; width: 1280px; height: 720px; background: #101820; color: #f5f5f5; }
#explanation { position: relative; width: 1280px; height: 720px; }
.clip { position: absolute; inset: 0; padding: 80px; box-sizing: border-box; background: #101820; }
h1 { font: 48px sans-serif; }
pre { font: 36px monospace; white-space: pre-wrap; }
</style>
</head>
<body>
<main id="explanation" data-composition-id="code-change" data-start="0" data-duration="10" data-width="1280" data-height="720" data-fps="30">
<section class="clip" data-start="0" data-duration="3" data-track-index="0"><h1>Failing check</h1><pre>assert.equal(total, 90);
Actual: 81</pre></section>
<section class="clip" data-start="3" data-duration="4" data-track-index="0"><h1>Apply once</h1><pre>if (applied.has(code)) return total;</pre></section>
<section class="clip" data-start="7" data-duration="3" data-track-index="0"><h1>Passing check</h1><pre>assert.equal(total, 90);
Passed</pre></section>
</main>
</body>
</html>
```

Check it before installing anything:

```sh
node skills/code-video-production/scripts/composition-check.mjs --input index.html --fps 30
```

The report has `frames` 300 and clips spanning `[0, 90)`, `[90, 210)`, and `[210, 300)`, with no warnings. `tests/fixtures/capability/subtitle-media-sample.html` is the same timing without styling and checks the same way.

After installing an appropriate FFmpeg build and local Chrome, install the pinned CLI in that separate project and run:

```sh
npm install --save-dev hyperframes@0.8.143
npx --no-install hyperframes --version
ffmpeg -version
ffprobe -version
npx --no-install hyperframes render . --output code-change.mp4 --fps 30 --strict --no-best-effort
ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=width,height,avg_frame_rate,nb_read_frames:format=duration -of json code-change.mp4
ffmpeg -v error -i code-change.mp4 -f null -
ffmpeg -n -ss 1 -i code-change.mp4 -frames:v 1 first.png
ffmpeg -n -ss 5 -i code-change.mp4 -frames:v 1 fix.png
ffmpeg -n -ss 8 -i code-change.mp4 -frames:v 1 last.png
```

Installation may download packages and browser components; perform it only when local dependency installation is allowed. Rendering itself uses the selected local composition and assets. Require renderer/decode exit 0, 1280x720, 30/1 fps, 300 decoded video frames, and duration 10 seconds within one frame. Open the three PNGs and verify the expected code state is legible with no clipping. Check boundary frames when using transitions. No audio is expected in this sample. A missing CLI/browser/codec leaves render acceptance unverified even when the HTML looks correct.

## Failure signals

- Timing lacks frame counts or assets depend on an unapproved network service.
- Code overflows or becomes unreadable at output size.
- A screen recording is presented as a deterministic render.
- Planned commands or previews are reported as produced media.
- A composition check that rejects a deliberate cross-track overlap, such as a caption over code.

## Evaluation scenario

Execute the sample only in a configured local environment; retain renderer and FFprobe results and inspect first/fix/last frames. If HyperFrames or FFmpeg is absent, record the missing command and mark rendering unverified. Run `node --test tests/subtitle-media.test.mjs`: the sample composition maps to 300 frames, a cross-track overlap passes with a warning, and a frame-aligned decimal such as `4.1` at 30 fps is accepted, a same-track overlap, a non-frame duration, and a relative time expression each exit non-zero, and a clip that overruns the composition exits zero with a warning. This package supplies an executable method, not pre-rendered video evidence.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
