---
name: media-transcoding
description: Construct a deterministic FFmpeg transcoding plan without executing it. Use when output dimensions, frame rate, and codecs must be explicit.
---

# Media Transcoding

## Core principle

A transcode is defined by its input, output dimensions, frame rate, codecs, and measured result. A command plan is useful, but it is not a transcoded file.

## Decision criteria

Use FFmpeg and FFprobe when the task installs them. Scale explicitly, choose a frame rate, and name video and audio codecs. For H.264 delivery, `-crf 20` is the package baseline for visually transparent review copies; a smaller file may justify a higher CRF only after viewing the result. Add `+faststart` for MP4s that must begin playing before the file is fully downloaded.

`skills/media-transcoding/scripts/ffmpeg-plan.mjs` prints the argument array and sets `executed` false. It accepts only positive integer width, height, and frame rate. It never invokes FFmpeg, so it can be tested on a machine without the codec installed.

Before accepting a real transcode, probe both files. Compare duration, dimensions, frame rate, and audio presence. A stream copy is preferable when no decoding change is required; re-encoding loses quality on every generation and should not be repeated casually.

Codec availability and patent obligations depend on the FFmpeg build. The command’s presence does not prove that `libx264` or `aac` is enabled. Record an unavailable encoder instead of silently choosing another.

### Reference

The method is original and uses public FFmpeg option names: https://ffmpeg.org/ffmpeg.html and https://ffmpeg.org/ffmpeg-codecs.html. No third-party skill text is copied.

## Workflow

1. State the required dimensions, frame rate, container, and compatibility need.
2. Generate the argument plan and review every flag.
3. Execute FFmpeg only when the binary and encoders are installed.
4. Probe input and output and compare their reported properties.
5. Watch or listen to representative sections when quality is a requirement.

## Worked example

`node skills/media-transcoding/scripts/ffmpeg-plan.mjs --input input.mov --output output.mp4 --width 1280 --height 720 --fps 30` returns the scale, 30 fps, `libx264`, CRF 20, AAC, and faststart arguments with `executed` false. On a machine without FFmpeg, no output media is claimed. A later authorized run must show FFprobe duration and dimensions before acceptance.

## Failure signals

- The planned command is described as completed media.
- An unavailable encoder is replaced without recording the substitution.
- Output duration differs and no one compares the probes.
- Repeated lossy transcodes are accepted without a quality check.

## Evaluation scenario

Given width, height, and frame rate, the result is the exact argument array and `executed` false. It fails if the test invokes FFmpeg or omits a requested parameter.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
