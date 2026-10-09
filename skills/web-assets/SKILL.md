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

The package script `skills/web-assets/scripts/web-asset-manifest.mjs` creates the deterministic manifest from a name and six-digit color. It does not create image binaries. Image generation remains a separate reviewed step, so a manifest alone is not evidence that icons exist.

Check the document head or manifest for matching paths, sizes, MIME type, and background. A declaration for a missing file is a failed asset, not a placeholder.

### Reference

The method is original. Web manifest icon members are defined by W3C: https://www.w3.org/TR/appmanifest/#icons-member

## Workflow

1. Confirm the available small and large logo versions.
2. Run the manifest script with the application name and background color.
3. Create or select image files for every declared size.
4. Compare file names and dimensions with the manifest.
5. Inspect the icons on light and dark browser chrome.

## Worked example

`node skills/web-assets/scripts/web-asset-manifest.mjs --name Harbor --color #123456 --output manifest.json` declares 16, 32, 180, 192, and 512. The 16 and 32 files use the simplified buoy, while 192 and 512 use the full mark. Each PNG measures the declared pixel size, the background is `#123456`, and no declared path is missing.

## Failure signals

- The manifest lists a size with no file, or a file has different dimensions.
- The 16px icon is an illegible reduction.
- A transparent edge changes the silhouette on dark chrome.
- The script output is presented as if it generated the images.

## Evaluation scenario

Given a name and color, the result is a manifest with the five required sizes and a file-to-declaration check. It fails if any declared file is absent or mistyped.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
