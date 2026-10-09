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

### Reference

Original method based on the HTML composition contract and CLI source at [HyperFrames commit 46f6cb3](https://github.com/heygen-com/hyperframes/tree/46f6cb356785bed79e1ce7b79d7e7accc697786a), package version 0.8.143, Apache-2.0. Public `render.ts` defines the directory, output, fps, strict, and no-best-effort options used below; no upstream Skill text is copied.

## Workflow

1. Define code states, duration, frame ranges, and resolution.
2. Author a local composition and keep network assets out of it.
3. Check tools and render with explicit fps and strict validation.
4. Probe/decode the video and inspect representative frames.
5. Report unavailable dependencies or render failures as unverified, never as completed media.

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

## Evaluation scenario

Execute the sample only in a configured local environment; retain renderer and FFprobe results and inspect first/fix/last frames. If HyperFrames or FFmpeg is absent, record the missing command and mark rendering unverified. This package supplies an executable method, not pre-rendered video evidence.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
