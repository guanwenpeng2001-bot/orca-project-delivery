---
name: subtitle-production
description: Convert SRT and WebVTT subtitles with validated timing and connect cues to a transcript. Use for local caption files.
---

# Subtitle Production

## Core principle

A subtitle file is accepted only when every cue has checked timing, order, and text. A conversion that drops something it cannot represent is a wrong file, not a simpler one.

## Decision criteria

`skills/subtitle-production/scripts/subtitle-convert.mjs` converts between SRT and WebVTT in either direction. It is plain Node with no dependencies, reads one file, and writes one file.

```
node skills/subtitle-production/scripts/subtitle-convert.mjs --input IN --output OUT --to srt|vtt
```

The report on stdout is `{input, output, format, cues, warnings}`. `format` is the requested target, `cues` counts the cues written, and `warnings` lists what was kept but has no equivalent in the target.

What the conversion keeps:

| Input | Result |
| --- | --- |
| Timecode | SRT uses a comma for milliseconds, WebVTT a dot. SRT hours run from 00 to 99. WebVTT hours are optional, so `mm:ss.mmm` is read as zero hours, and WebVTT hours have no two-digit ceiling |
| Cue text | One cue per block, lines preserved, cue numbers rebuilt from 1 |
| Byte order mark, CR, LF | Stripped or normalized; output is UTF-8 with LF |
| WebVTT cue identifier | Dropped, and named in `warnings`, because SRT has no identifier |
| WebVTT `NOTE` block | Skipped, and named in `warnings` |

What the conversion refuses, naming the construct on stderr and writing nothing:

| Input | Why it is refused |
| --- | --- |
| `STYLE` or `REGION` block | Styling and positioning have no SRT equivalent |
| Cue settings such as `align:start` | Placement would be lost |
| Voice span `<v Name>` | The speaker label would be lost |
| Cue ending at or before it starts | No duration |
| Cue starting before the previous cue ends | The cues overlap |
| Cue starting before the previous cue starts | The cues are out of order |
| Hours above 99 written to SRT | SRT cannot express them. The same timing written to WebVTT is kept |
| Empty cue text | Nothing would be shown |
| Bytes that are not UTF-8 | The text would be guessed |

A source with no cues is valid and converts to an empty file: the report has `cues` 0 and the warning `source has no cues`. Exit 0 means the output was written and validated. Any other exit means nothing was written, and an output that already existed is left untouched. The write is atomic: the previous output is replaced only after the new file is complete.

### Connecting cues to a transcript

A transcript with word timings, such as the `{text, words}` saved by `skills/audio-transcription`, is the source of cue boundaries. Build each cue from a run of words, starting it at the first word's start and ending it at the last word's end, then convert. The conversion checks the shape of that timing; it does not check that the words were really said then. Sample the audio before accepting the cues.

### Bilingual cues

A second language is a second cue track, not a second line in the same cue. Put each language in its own file, keep identical cue boundaries in both, and label the language in the file name. The converter handles one language per run and never merges tracks.

### Reference

The method is original and follows the public SRT layout and the WebVTT cue structure documented at https://www.w3.org/TR/webvtt1/. No third-party skill text is copied.

## Workflow

1. Decide the target format and confirm the source is UTF-8.
2. Convert and read the report. Resolve every warning or keep it deliberately.
3. Reject any run that exits non-zero; fix the named construct instead of editing the output by hand.
4. Read the result back through the reverse conversion and compare cue count and timing.
5. For cues derived from a transcript, sample them against the audio.

## Worked example

`tests/fixtures/capability/subtitle-media-sample.srt` holds two cues:

```
node skills/subtitle-production/scripts/subtitle-convert.mjs --input tests/fixtures/capability/subtitle-media-sample.srt --output sample.vtt --to vtt
node skills/subtitle-production/scripts/subtitle-convert.mjs --input sample.vtt --output sample-back.srt --to srt
```

The first report has `format` `vtt`, `cues` 2, and no warnings. `sample.vtt` begins with `WEBVTT` and uses dot timestamps. `sample-back.srt` matches the fixture cue for cue. A `STYLE` block, a cue setting, or an overlapping cue each exit non-zero, name the reason, and leave no output.

## Failure signals

- A conversion exits 0 while a `STYLE` block, cue setting, or voice span has disappeared from the output.
- Cue numbers from the source are preserved instead of rebuilt.
- An overlapping or out-of-order cue is written without comment.
- A non-zero exit still replaces the previous output file.
- Two languages are folded into one cue and described as bilingual.

## Evaluation scenario

Run `node --test tests/subtitle-media.test.mjs`. The SRT fixture converts to WebVTT and back with the same cue count and timing. Overlap, ordering, empty text, bad timestamps, a timing line with an extra arrow, hours past 99 written to SRT, non-UTF-8 bytes, `STYLE` blocks, cue settings, and voice spans each exit non-zero and write nothing. A short-form WebVTT timestamp and hours past 99 written to WebVTT both convert. It fails if any of those inputs exits 0.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
