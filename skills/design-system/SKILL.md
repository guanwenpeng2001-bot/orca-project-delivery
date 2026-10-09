---
name: design-system
description: Define the shared tokens and component contracts a product reuses across screens. Use when more than one screen must share the same type, color, spacing, or component behavior.
---

# Design System

## Core principle

A design system is the set of decisions every screen inherits, written so a change to a token changes every screen that uses it. A value copied into one screen is not a token until something else references it.

## Decision criteria

Keep three layers and do not skip one. A primitive token is a raw value: a color, a size, a spacing step. A semantic token names the role that value plays, such as the color of body text or the space between grouped items. A component token applies a semantic token to one part of one component, such as the label of a button. Referencing a primitive directly from a component hides the role, so a theme cannot be swapped without editing the component.

Name tokens by role, not by appearance. `color.text.muted` survives a theme change; `color.gray.600` does not, because the muted text may stop being gray. Record the primitive a semantic token points at, so the chain can be checked.

A component contract states the parts, the states, and the tokens each part uses. The states a contract must cover are the ones a caller can reach: default, hover, focus, disabled, and invalid where the component accepts input. A contract that shows only the default state leaves the rest to each screen.

Themes swap semantic tokens, not components. A dark theme reassigns `color.surface` and `color.text` to different primitives; the button still reads `color.surface`. Verify contrast again after the swap, because a primitive that passed on white can fail on a dark surface.

### Reference

The method is original. Contrast thresholds used when a token carries text or a boundary come from W3C WCAG 2.2 success criteria 1.4.3 and 1.4.11: https://www.w3.org/TR/WCAG22/

## Workflow

1. List the roles the screens already share: text, surface, accent, spacing, type.
2. Give each role a primitive value and a semantic token that points at it.
3. Write a component contract that consumes semantic tokens only.
4. Add a second theme by reassigning semantic tokens, and remeasure contrast.
5. Record which screen decisions stay local because they are not shared.

## Worked example

A tide product shares one accent and one neutral range across its list and its entry form.

```css
:root {
  --color-blue-900: #0b3a5b;
  --color-neutral-700: #777777;
  --color-neutral-0: #ffffff;
  --space-2: 8px;
  --space-4: 16px;
  --font-size-body: 16px;
  --color-text: var(--color-blue-900);
  --color-text-muted: var(--color-neutral-700);
  --color-surface: var(--color-neutral-0);
  --color-accent: var(--color-blue-900);
}
.button {
  color: var(--color-surface);
  background: var(--color-accent);
  padding: var(--space-2) var(--space-4);
  font-size: var(--font-size-body);
}
```

The button contract says its label uses `--color-surface` on `--color-accent`, its focus state adds a 2px outline in `--color-text`, and its disabled state keeps the label readable rather than lowering the type size. `--color-text-muted` on `--color-surface` measures 4.48:1, so the contract allows it for large text and boundaries only, not for body text.

## Failure signals

- A component names a primitive such as a hex value instead of a semantic token.
- Two screens style the same button with different padding and both call it the button.
- A theme edits component code instead of reassigning tokens.
- The contract documents the default state and leaves focus and disabled unstated.

## Evaluation scenario

Given a list screen and a form screen that both use a button and a muted hint, the result defines primitive, semantic, and component tokens, shows one theme swap that touches only semantic tokens, and records the contrast of the hint. It fails if each screen carries its own copy of the values.

## Boundary

This Skill covers the tokens and component contracts shared across screens. The visual specification of a single screen, including its type roles, spacing, and states, belongs to frontend visual design. This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
