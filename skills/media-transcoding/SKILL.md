---
name: media-transcoding
description: Plan and execute local FFmpeg transcoding with explicit dimensions, frame rate, codecs, and FFprobe acceptance checks.
---

# Media Transcoding

## Core principle

A transcode is defined by its input, output dimensions, frame rate, codecs, and measured result. A command plan is useful, but it is not a transcoded file.

## Decision criteria

Use FFmpeg and FFprobe when the task installs them. Scale explicitly, choose a frame rate, and name video and audio codecs. For H.264 delivery, `-crf 20` is the package baseline for visually transparent review copies; a smaller file may justify a higher CRF only after viewing the result. Add `+faststart` for MP4s that must begin playing before the file is fully downloaded.

`skills/media-transcoding/scripts/ffmpeg-plan.mjs` prints the argument array and sets `executed` false. It accepts only positive integer width, height, and frame rate. It never invokes FFmpeg, so it can be tested on a machine without the codec installed.

Before accepting a real transcode, probe both files and compare them with `skills/media-transcoding/scripts/probe-compare.mjs`. It reads two ffprobe JSON documents and checks duration, dimensions, frame rate, and audio presence. It never runs ffprobe, so the comparison can be tested from saved probes.

```
node skills/media-transcoding/scripts/probe-compare.mjs --source source.json --output output.json --width 640 --height 360
```

`--width` and `--height` declare the expected output dimensions; without them the source dimensions are expected. `--tolerance SECONDS` overrides the default duration tolerance of one output frame. Frame rates are read as rationals, so `30000/1001` and `29.97` compare equal. A missing video or audio stream, a non-finite duration, a non-finite frame rate, and a probe without a `streams` array are each reported and exit non-zero. Exit 0 prints `{matched, video, audio, durationDelta, tolerance}`.

A stream copy is preferable when no decoding change is required; re-encoding loses quality on every generation and should not be repeated casually.

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

`node skills/media-transcoding/scripts/ffmpeg-plan.mjs --input input.mov --output output.mp4 --width 1280 --height 720 --fps 30` returns the plan with `executed: false`. With FFmpeg and FFprobe installed, run this complete local sample from a writable output directory (no provider calls):

```sh
ffmpeg -hide_banner -encoders
ffmpeg -n -f lavfi -i testsrc2=size=1280x720:rate=30 -f lavfi -i sine=frequency=440:sample_rate=48000 -t 3 -c:v libx264 -pix_fmt yuv420p -c:a aac input.mp4
ffmpeg -n -i input.mp4 -vf scale=640:360 -r 30 -c:v libx264 -crf 20 -pix_fmt yuv420p -c:a aac -movflags +faststart output.mp4
ffprobe -v error -show_entries stream=codec_type,codec_name,width,height,avg_frame_rate:format=duration -of json input.mp4 > source.json
ffprobe -v error -show_entries stream=codec_type,codec_name,width,height,avg_frame_rate:format=duration -of json output.mp4 > output.json
node skills/media-transcoding/scripts/probe-compare.mjs --source source.json --output output.json --width 640 --height 360
ffmpeg -v error -i output.mp4 -f null -
```

Require libx264 and AAC in the encoder list; both media commands must exit 0. The comparison must exit 0, showing H.264 640x360 at 30 fps plus AAC audio, with the duration delta inside one frame (1/30 second), allowing codec audio padding when examining individual stream durations. `tests/fixtures/capability/subtitle-media-source-probe.json` and `subtitle-media-output-probe.json` are that pair and compare the same way. The decode command must exit 0 without errors. Watch the test pattern and listen for the continuous tone; production quality needs representative real content too. `-n` refuses overwriting existing files. Obtain a suitable FFmpeg build from the official [download page](https://ffmpeg.org/download.html) and retain its version/build license. If the binaries or encoders are absent, these commands are instructions only and the render remains unverified.

## Failure signals

- The planned command is described as completed media.
- An unavailable encoder is replaced without recording the substitution.
- Output duration differs and no one compares the probes.
- A probe with a missing stream or a non-finite duration is averaged past instead of rejected.
- Repeated lossy transcodes are accepted without a quality check.

## Evaluation scenario

Given width, height, and frame rate, the result is the exact argument array and `executed` false. It fails if the test invokes FFmpeg or omits a requested parameter. Run `node --test tests/subtitle-media.test.mjs`: the saved probe pair matches at 640x360, and a drifted duration, a missing audio stream, and a non-finite frame rate each exit non-zero.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
