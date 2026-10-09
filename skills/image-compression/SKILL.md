---
name: image-compression
description: Compress images only when bytes shrink and the decoded image remains valid. Use for deterministic local image optimization.
---

# Image Compression

## Core principle

Compression is successful only when the output is smaller and the image still decodes to the intended pixels. A smaller corrupt file is a loss, not an optimization.

## Decision criteria

Choose lossless compression when boundaries, text, or transparency must remain exact. Use lossy compression only when the task permits visual approximation, and compare the result visually at the displayed size. Never assume a target reduction such as half the bytes; report the measured sizes.

The included `skills/image-compression/scripts/png-compressor.mjs` performs lossless PNG recompression with Node 22.15+ zlib. It validates the signature, every chunk CRC, chunk bounds, header/end markers, consecutive IDATs, palette placement, scanline length and filters before writing. Non-IDAT chunks retain their exact relative position; adjacent IDAT chunks are recompressed into one at the original position. Non-interlaced PNGs up to 256 MiB of inflated scanlines are supported; interlaced PNG, APNG, and unknown critical chunks fail explicitly. This is not a full PNG decoder or a replacement for a visual check. WebP/JPEG conversion is not implemented.

`skills/image-compression/scripts/png-resize.mjs` exports a smaller PNG from an 8-bit non-interlaced RGB or RGBA master. It checks every chunk CRC, reconstructs filtered scanlines, and resamples with an area-weighted box average, so an integer scale factor averages whole blocks exactly and a non-dividing target such as 512 to 180 weights the partial edge pixels. Alpha is averaged as its own channel and the output keeps the source color type. An RGB `tRNS` color key is expanded to a real alpha channel before averaging, so a keyed pixel stays transparent and the report says `alpha: true`. Any other ancillary chunk, including `gAMA`, `sRGB`, `iCCP`, `pHYs`, and `bKGD`, is rejected by name before writing rather than dropped. Text chunks are ignored. The source is bounded to 16 megapixels. Requests that do not shrink both axes, interlaced PNGs, and palette, gray, or 16-bit PNGs fail before writing, and an existing destination is left untouched. This is a resampler, not a JPEG or WebP encoder and not an SVG rasterizer.

External codecs such as `cwebp`, ImageMagick, or FFmpeg may be used by a task when installed, but they are not package requirements. A missing optional codec is recorded as unavailable. It is not replaced silently by an unrelated format.

Preserve dimensions, alpha, and orientation. Strip metadata only when the task says it is unnecessary; metadata can contain copyright or color information the asset needs.

### Reference

The method is original. PNG chunk structure follows the W3C PNG specification: https://www.w3.org/TR/png/

## Workflow

1. Record input format, dimensions, alpha, and byte size.
2. Run the selected lossless or approved lossy compressor.
3. Decode the output and compare dimensions and required visual features.
4. Accept it only if the byte size decreases and checks pass.
5. Report both sizes and any codec that was unavailable.

## Worked example

A 512px master is exported with `node skills/image-compression/scripts/png-resize.mjs --input master.png --output icon-32.png --width 32 --height 32`. The output reports `status: "resized"` with the requested dimensions and `alpha: true` when the master has alpha, and its decoded corner pixels equal the box average of the source block. A 64px PNG is recompressed with `node skills/image-compression/scripts/png-compressor.mjs --input sample.png --output small.png`. The output keeps the PNG signature, dimensions, and alpha, and its byte length is lower. JSON stdout reports `status: "compressed"`, `inputBytes`, `outputBytes`, and `output`. If the candidate is not smaller, exit 0 instead reports `status: "no-gain"`, `inputBytes`, and `candidateBytes`, creates no new output and preserves any existing destination. Invalid or unsupported input exits 1 before writing. Use `--sample sample.png` to generate the deterministic 64px test input. No WebP conversion is claimed because `cwebp` is not present.

## Failure signals

- The output does not decode or has changed dimensions unintentionally.
- A target reduction is invented instead of measured.
- A missing optional codec causes the script to skip and report success.
- Lossy compression destroys required text or transparency without approval.

## Evaluation scenario

Given a valid PNG and a corrupt file, the valid file produces a smaller valid PNG and the corrupt file exits nonzero. It fails if either outcome is swapped or sizes are not reported.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
