---
name: frontend-visual-design
description: Choose typography, color, spacing, and visual hierarchy for an interface. Use when a screen needs a visual specification rather than only a user flow.
---

# Frontend Visual Design

## Core principle

A visual specification names the decision a reader can verify on the rendered screen. Taste is not a specification until it becomes type size, contrast, spacing, state, or alignment.

## Decision criteria

Start from the smallest text that must remain readable and derive the hierarchy upward. Body text below 16px needs a recorded reason because browser zoom and mobile scaling expose it first. Limit the scale to four roles: caption, body, section, and page title. If a fifth size appears, it is usually labeling a component rather than a level of information.

Choose one accent and a neutral range. The accent marks action or the current item, not decoration on every container. Text on a filled accent must meet 4.5:1, and interface boundaries that communicate state must meet 3:1. Do not use color as the only status signal; pair it with text or a symbol.

Space by relationship. Group items that are read together at 8px, separate groups at 16px or 24px, and separate regions at 32px or more. Arbitrary values between those steps make alignment accidental. Keep one content width, normally 65–75 characters for prose, and let wide screens gain margin rather than longer lines.

Specify loading, empty, error, permission, and recovery states with the same hierarchy as the ready state. An error color that shrinks text or removes its label has solved the color problem by creating a reading problem.

### Reference

The method is original. Contrast thresholds come from W3C WCAG 2.2 success criteria 1.4.3 and 1.4.11: https://www.w3.org/TR/WCAG22/

## Workflow

1. Name the primary action and the text a user must read to use it.
2. Set the four type roles and the spacing steps on one representative screen.
3. Check accent contrast, line length, and both desktop and 320px layouts.
4. Define every non-ready state without lowering text size or removing names.
5. Record the values as a checklist another person can inspect.

## Worked example

A harbor-status form uses 16px body text, a 20px section heading, and a 28px page title. The submit button uses `#FFFFFF` on `#0B3A5B`, and the muted hint uses `#777777` on `#FFFFFF`. Measure both instead of estimating:

```
node skills/frontend-visual-design/scripts/contrast-ratio.mjs --foreground "#FFFFFF" --background "#0B3A5B"
node skills/frontend-visual-design/scripts/contrast-ratio.mjs --foreground "#777777" --background "#FFFFFF" --threshold 4.5
```

The first reports 11.86 and exits 0. The second reports 4.48 and exits 2, because the requested 4.5 text threshold is missed, so that hint is limited to large text and boundaries. The error puts "Tide time is required." beside the field instead of only turning the border red. At 320px the line length stays under 40 characters and the button remains full width. The empty state says "No readings today." rather than leaving a blank table.

## Failure signals

- The review says the screen “looks polished” but lists no size, color, or spacing value.
- Status is communicated only by red or green.
- Mobile layout is a shrunk desktop layout with text below the specified body size.
- A state removes the label, focus outline, or recovery instruction.
- A contrast figure is copied from a palette card instead of measured for the pair actually rendered.

## Evaluation scenario

Given one form at desktop and 320px, the result states four type roles, one measured accent contrast, spacing steps, and copy for empty and error states. It fails if the conclusion rests only on preference or checks one viewport. The accent measurement names the command above and the ratio it printed.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
