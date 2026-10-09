---
name: svg-logo-design
description: Design and review scalable SVG marks for legibility, color, and export sizes. Use for a logo delivered as vector artwork.
---

# SVG Logo Design

## Core principle

A logo succeeds when the smallest required size remains identifiable and the SVG source contains only intentional geometry. Visual complexity is not a brand system.

## Decision criteria

Design the mark in vector shapes rather than traced pixels. Use a viewBox with whole-number coordinates and remove hidden, empty, or imported editor metadata. Curves that exist only because an automatic trace followed compression noise should be simplified.

Test the mark at 16px, the normal interface size, and a large display size. At 16px, counters in letters and gaps between shapes must survive. If they do not, use a simplified small-size version rather than shrinking the detailed mark.

Specify color as values the caller can reproduce and provide a one-color version. A gradient or hairline stroke that disappears in small or monochrome reproduction is not part of the required mark. Leave clear space equal to a named portion of the mark, such as the height of its primary stroke.

Confirm the file is valid SVG, uses scalable coordinates rather than a fixed bitmap, and contains no remote font, script, or image reference. Text in a logo is outlined when the recipient cannot be assumed to have the font.

### Reference

The method is original. SVG coordinate and shape behavior is defined by W3C SVG 2: https://www.w3.org/TR/SVG2/

## Workflow

1. State the smallest and largest sizes and the required color versions.
2. Draw the fewest shapes that preserve identification.
3. Check gaps and counters at 16px in color and one color.
4. Clean the SVG of metadata and external references.
5. Record the clear-space rule with the exported files.

## Worked example

A harbor mark combines a buoy and the letter H. At 16px the detailed rope disappears, so the exported small version keeps the buoy silhouette and H counter only. The source viewBox is `0 0 64 64`, the color is `#0B3A5B`, and the one-color version uses currentColor. The SVG contains two paths and no remote font or script. Clear space is one eighth of the mark height.

## Failure signals

- The small logo is only a scaled screenshot.
- SVG contains editor metadata, scripts, or external references.
- The monochrome version loses the feature that identifies the mark.
- Clear space and minimum size are absent from the delivery.

## Evaluation scenario

Given a mark, the result includes a 16px check, one-color version, cleaned SVG structure, and clear-space rule. It fails if only a large color rendering is reviewed.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
