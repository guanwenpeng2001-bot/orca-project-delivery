---
name: product-design
description: Design user flows, information architecture, interaction states, accessibility behavior, and testable UX acceptance. Use for UI, workflow, or interaction-heavy tasks.
---

# Product Design

## Core principle

Design the behavior, not the decoration. A screen design is finished when every state the user can actually encounter is specified and each one is written so a test can tell whether it happened.

## Decision criteria

Enumerate states before layout. For every view that loads or mutates data, specify all of: loading, empty, success, error, permission denied, and the recovery from each failure. Add interrupted (the user navigates away mid-action) and destructive (the action cannot be undone) where they apply. A design that specifies only the success state is a sketch.

Write acceptance as observable behavior. "The screen feels fast" cannot be tested; "while the save request is in flight the button is disabled and shows a progress indicator, and on failure the entered text is preserved and an error is announced" can. Each criterion should name something a person or an automated check could observe.

For accessibility, target the WCAG 2.2 AA level unless the project states another, and check the four principles against the specific component: it must be perceivable (text alternatives, contrast at least 4.5:1 for body text, content not conveyed by color alone), operable (full keyboard access, visible focus, no keyboard trap), understandable (labels, predictable behavior, identified errors), and robust (semantics a screen reader can read). Name the criterion at risk rather than claiming general compliance.

Reuse the project's existing design system and interaction patterns. Introduce a new component only when no existing one can carry the behavior, and say why.

Respect motion and input preferences: honor a request for reduced motion, and keep every action reachable without a pointer.

### Interaction specifics that get left implicit

Specify the behaviors implementers otherwise invent inconsistently:

- Validation timing: validate on submission by default; validate per field only where early feedback prevents wasted effort. State which.
- Focus management: after a dialog closes, return focus to the element that opened it. After a destructive action removes an element, move focus somewhere sensible rather than losing it.
- Disabled versus explained: a control the user cannot use should say why, not silently do nothing. Prefer a visible explanation over a control with no affordance.
- Destructive actions: require an explicit confirmation that names the consequence, and provide an undo where the operation allows one.
- Text expansion and localization: labels and buttons must still work when text is substantially longer than the source language, and layout must not assume a left-to-right reading order where the product is localized.
- Reduced motion: anything animated must have a non-animated alternative that honors the user's motion preference.

### Content as part of the design

Write the actual words for labels, empty states, errors, and confirmations. Error text should state what happened and what the user can do, not a code or a generic failure. Empty states should tell the user how to get started, not merely that nothing is there. Placeholder text is not a label, because it disappears once the user types.

## Workflow

1. Map the user's entry point, the steps they take, and what "done" looks like for them.
2. Define the information hierarchy: what is primary, what is secondary, what action is available.
3. Fill the state matrix for every view, including failure and recovery.
4. Match each element to an existing design-system component, and justify any new one.
5. Check keyboard access, focus order, screen-reader semantics, contrast, motion, and text expansion.
6. Rewrite the design as acceptance criteria that name observable outcomes.

## Worked example

A settings screen lets a user change their display name.

The state matrix:

| State | What the user sees | What they can do |
| --- | --- | --- |
| Loading | The field shows a placeholder, not stale data | Wait |
| Empty | The field is blank with a hint | Type |
| Success | The saved name with a confirmation | Edit again |
| Error | The typed value kept, with the reason | Correct and retry |
| Denied | An explanation, no editable field | Nothing, because they lack permission |
| Destructive | Not applicable, since renaming is reversible | — |

The acceptance criteria: submitting an empty name shows the validation message and does not send a request; while saving, the button is disabled; on network failure the typed name remains and the error is announced through an aria live region; the field is reachable by tab and its focus indicator is visible.

The contrast of the hint text is specified against the AA ratio rather than assumed, and the confirmation uses text rather than color alone.

## Failure signals

- Only the happy path is drawn; empty, error, and permission states are left to the implementer to invent.
- Acceptance criteria use subjective words such as clean, modern, or intuitive.
- A new component duplicates one the design system already provides.
- Interaction depends on hover or on color alone.
- Focus order or screen-reader labeling is never mentioned for a form.
- An error state discards the user's input.

## Evaluation scenario

Given a request to design a "delete account" flow, the result should fill every applicable state including the destructive confirmation, state what is irreversible and how the user is warned, name the WCAG criteria the confirmation dialog must meet (keyboard operation, focus trapped inside and restored on close, the warning not conveyed by color alone), and write acceptance criteria an automated check could assert. It fails the method if the design is a single success screen, or if its acceptance criteria cannot be verified by observation.

## Output

- User-flow map
- Screen and component responsibilities
- State matrix
- Accessibility requirements with specific criteria
- Content requirements
- Observable acceptance criteria

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
