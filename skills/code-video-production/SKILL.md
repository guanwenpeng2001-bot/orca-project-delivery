---
name: code-video-production
description: Plan a local HyperFrames code video with deterministic frame timing and no required network call. Use for HTML-authored code explainers.
---

# Code Video Production

## Core principle

A code video is a timed sequence of frames that can be rendered locally and checked exactly. Animation without a frame count, resolution, and readable code state is not reviewable.

## Decision criteria

Use HyperFrames as the local authoring path: HTML, CSS, and seekable animation rendered to MP4. The public repository states Apache-2.0 and documents local rendering with its engine and FFmpeg. This package does not vendor HyperFrames, install it, or claim a render was performed.

Plan in frames. At 30 fps, a 12-second explanation is 360 frames. Each segment names the code state visible at its first and last frame. A transition may not be the only place where a changed line is readable. Keep syntax at a size that remains legible at the output resolution.

Separate local assets from optional network services. Fonts, code, and images used by the render are local inputs. A hosted voice or stock-media call is a different authorized task and is not implied by this Skill.

The output contract records duration, resolution, frame rate, and audio offset. If FFmpeg is absent, the plan can still be reviewed but the rendered result is unverified. Do not substitute a screen recording and call it a deterministic render.

### Reference

The method is original. HyperFrames license and local HTML-to-video model were checked at commit `46f6cb356785bed79e1ce7b79d7e7accc697786a`: https://github.com/heygen-com/hyperframes

## Workflow

1. Divide the explanation into frame ranges and visible code states.
2. Author the composition with local assets only.
3. Render locally when HyperFrames and FFmpeg are installed.
4. Check duration, dimensions, frame rate, and synchronization against the plan.
5. Report an absent renderer as unverified rather than passing the output.

## Worked example

A 10-second, 1280×720, 30 fps video has 300 frames. Frames 0–90 show the failing assertion, 91–210 show the one-line fix, and 211–299 show the passing result. Each range holds its code still for at least two seconds. The plan uses local font files and no network media. Without a local HyperFrames render, the report says “plan checked, render unverified.”

## Failure signals

- The timing is described only as “slow” or “fast.”
- Code is readable in the editor but too small in the specified output.
- A hosted asset is required although the task authorized local production only.
- A screen recording is reported as a frame-exact render.

## Evaluation scenario

Given a three-step code change, the result names frame ranges, resolution, frame rate, and local asset boundaries. It fails if it claims a render without inspecting the output.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
