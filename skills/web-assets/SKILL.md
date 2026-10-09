---
name: web-assets
description: Generate a deterministic web icon and manifest size plan from explicit brand inputs. Use for favicon and PWA asset contracts.
---

# Web Assets

## Core principle

Web icons are a size contract. Every declared size must identify the mark, and the manifest must name exactly the files produced.

## Decision criteria

Produce the sizes the target platform actually consumes: 16 and 32 for browser tabs, 180 for Apple touch icons, and 192 and 512 for the web manifest. Adding sizes without a consumer increases maintenance without improving recognition.

Use the simplified small logo at 16 and 32 rather than shrinking a detailed mark. Larger icons may use the full mark and must keep the same silhouette. Background color is explicit; transparency is intentional and checked against both light and dark browser chrome.

The package script `skills/web-assets/scripts/web-asset-manifest.mjs` creates the deterministic manifest from a name and six-digit color. It still writes no image bytes. The bytes come from reviewed masters: the simplified small logo supplies 16 and 32, and the large logo supplies 180, 192, and the 512 entry itself. `skills/image-compression/scripts/png-resize.mjs` only shrinks a master, so it cannot produce the 512 entry from a 512px master. A manifest whose declared sizes have no file is not evidence that icons exist.

Check the document head or manifest for matching paths, sizes, MIME type, and background. A declaration for a missing file is a failed asset, not a placeholder.

### Reference

The method is original. Web manifest icon members are defined by W3C: https://www.w3.org/TR/appmanifest/#icons-member

## Workflow

1. Confirm the available small and large logo versions.
2. Run the manifest script with the application name and background color.
3. Resize each smaller declared size from its matching reviewed master with `png-resize.mjs`; copy the large master as the 512 entry.
4. Compare each output's dimensions and alpha with the manifest entry.
5. Inspect the icons on light and dark browser chrome.

## Worked example

`node skills/web-assets/scripts/web-asset-manifest.mjs --name Harbor --color '#123456' --output manifest.json` declares 16, 32, 180, 192, and 512. The reviewed 512px RGBA master is the 512 entry. `node skills/image-compression/scripts/png-resize.mjs --input master.png --output icon-192x192.png --width 192 --height 192` produces the 192px file, and the same command with 180 produces that file. The 16 and 32 files come from the simplified small logo, since resampling cannot simplify a detailed mark. Each PNG measures its declared size and keeps the master's alpha. SVG rasterization is not performed: it needs an external tool such as rsvg-convert, and a missing tool is reported as unavailable rather than replaced with a guessed PNG.

## Failure signals

- The manifest lists a size with no file, or a file has different dimensions.
- The 16px icon is an illegible reduction.
- A transparent edge changes the silhouette on dark chrome.
- The script output is presented as if it generated the images.

## Evaluation scenario

Given a name and color, the result is a manifest with the five required sizes and a file-to-declaration check. It fails if any declared file is absent or mistyped.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
