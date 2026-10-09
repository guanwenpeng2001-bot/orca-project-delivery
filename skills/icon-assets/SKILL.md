---
name: icon-assets
description: Select, size, and trace icon assets with source and license records. Use when an interface needs a consistent icon set.
---

# Icon Assets

## Core principle

An icon is usable only when its meaning, size, and license can be traced. A downloaded shape without those records is not an asset.

## Decision criteria

Use one grid, normally 24px with 2px strokes, for interface icons. A 16px icon needs fewer details, not a reduced copy of a complex drawing. Keep the visible weight consistent: if one symbol is filled and another is outlined, that difference must carry meaning.

Prefer a local reviewed set. A public icon API may be consulted only under the task’s network authorization; this Skill does not declare such a network dependency because the package requirement schema cannot represent a keyless API honestly. Record the set name, version or retrieval date, license, and icon name for every adopted item.

Do not edit a licensed icon in a way its license reserves. Modifications, attribution, and trademark restrictions stay with the source license. An icon that resembles a third-party logo is not generic artwork.

Provide a text alternative when the icon is the only carrier of meaning. A decorative icon adjacent to text is hidden from assistive names. The local manifest script requires Node.js but does not download icons.

### Reference

The method is original. Icon licensing must be read from the selected collection; W3C’s icon guidance is a useful accessibility reference: https://www.w3.org/WAI/tutorials/images/decision-tree/

## Workflow

1. Name the action or status the icon represents and its rendered size.
2. Select one existing visual family before adding a symbol.
3. Record source, version, license, and whether attribution is required.
4. Check legibility at the target size and the accessible name.
5. Reject any icon whose license or origin cannot be stated.

## Worked example

A warning icon is needed at 16px beside “Tide missing.” The project uses a locally reviewed outline set at 2px stroke. The record says set “Harbor marks,” version 1.3, MIT, no attribution, symbol `warning`. At 16px the triangle and mark remain distinct, and the adjacent text supplies the accessible name. No external query is performed.

## Failure signals

- Icons come from several visual families without a reason.
- The asset record lacks a license or retrieval source.
- A 16px icon has interior detail that disappears at that size.
- The icon is the only indication of an error and has no text alternative.

## Evaluation scenario

Given three status icons, the result names one grid, each source and license, and which icons need text alternatives. It fails if any adopted icon has an unknown license.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
