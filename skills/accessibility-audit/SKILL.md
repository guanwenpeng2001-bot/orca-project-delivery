---
name: accessibility-audit
description: Audit keyboard access, names, errors, contrast, and reflow, separating tool output from human checks. Use before claiming accessibility conformance.
---

# Accessibility Audit

## Core principle

An automated scan reports a subset of detectable failures. Conformance claims require the scan plus the manual checks the scan cannot perform, each labeled with its evidence.

## Decision criteria

Check keyboard order before visual polish. Every actionable control must be reachable, show focus, and activate with Enter or Space as appropriate. Tab order follows the visual reading order unless an explicit alternative is documented.

Every input needs a programmatic name and, when invalid, an error related to that input in text. Placeholder text is not a name. A dialog must move focus inside, keep it there, and restore it on close.

Measure contrast for the actual rendered colors: 4.5:1 for ordinary text and 3:1 for large text and meaningful boundaries. At 320px and 200% zoom, content reflows without requiring two-dimensional scrolling for normal reading. Do not treat a single tool’s score as WCAG conformance.

Record each item as automatic or manual. An automatic pass on contrast does not decide keyboard behavior, reading order, or whether the error text is understandable.

### Reference

The method is original. Criteria referenced are WCAG 2.2: 1.4.3 Contrast, 1.4.10 Reflow, 1.4.11 Non-text Contrast, 2.1.1 Keyboard, 2.4.7 Focus Visible, and 3.3.1 Error Identification. https://www.w3.org/TR/WCAG22/

## Workflow

1. Run the available scanner and preserve its raw output.
2. Complete the keyboard, name, error, dialog, and reflow checks manually.
3. Measure the representative text and boundary colors.
4. Separate confirmed failures from items the tools could not judge.
5. Report no overall conformance claim when a required manual check was skipped.

## Worked example

A scanner reports no image-alt errors on a tide form. Manual checks find that the time field has no label, its red border has no text error, and the dialog does not return focus to the button that opened it. Contrast is measured with the shared calculator rather than taken from the scanner:

```
node skills/frontend-visual-design/scripts/contrast-ratio.mjs --foreground "#000000" --background "#FFFFFF"
```

That pair reports 21 and meets both thresholds. The audit still fails on names, errors, and focus, which the table records separately:

| Check | Source | Result |
| --- | --- | --- |
| Image alternatives | Automatic | No failures |
| Text contrast of body copy | Automatic | 21:1, passes |
| Field has a programmatic name | Manual | Fails, no label |
| Error stated in text | Manual | Fails, color only |
| Focus returns to the opener | Manual | Fails, not restored |

## Failure signals

- A conformance claim cites only an automated score.
- Focus is visible by browser default but disappears under the application’s CSS.
- Errors are announced by color or icon alone.
- An automatic contrast pass is allowed to stand in for the keyboard and name checks.
- Zoom causes overlapping text that the report calls responsive because no horizontal page scrollbar appeared.

## Evaluation scenario

Given a form and dialog, the result has separate automatic and manual rows for labels, keyboard order, error text, contrast, and focus return. It fails if a clean scan is reported as complete WCAG conformance.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
