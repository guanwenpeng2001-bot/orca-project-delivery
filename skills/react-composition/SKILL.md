---
name: react-composition
description: Compose React state and components explicitly instead of multiplying boolean modes. Use when component APIs or shared state become ambiguous.
---

# React Composition

## Core principle

A component API should make invalid combinations unrepresentable. Boolean props that silently change each other’s meaning are a state machine hidden in a parameter list.

## Decision criteria

Replace a cluster of modes with explicit composition when callers can no longer predict the result. A dialog can compose a title, body, and actions rather than accepting `isConfirm`, `isDanger`, and `showCancel`, whose combinations disagree. Keep a boolean when it controls one continuous property, such as `disabled`.

Share state through the closest owner that both consumers can name. Context is appropriate for data read by a subtree and changed infrequently. A context that changes on every keystroke forces unrelated consumers to render; local state or a narrower provider is the better boundary.

Custom hooks own behavior, not arbitrary markup. A hook that returns twenty unrelated handlers is a second component without a clear boundary. Split it by use case. Do not introduce a generic render-prop or registry abstraction for one caller.

For React 19, `use` and Actions change how promises and mutations can be expressed. Use them only after confirming the application version, and keep the resulting loading and error states explicit. Composition must not discard an error or pending state to make the tree look simpler.

### Reference

This is an original method based on public React composition guidance: https://react.dev/learn/passing-props-to-a-component

## Workflow

1. List the props or state whose combinations are ambiguous.
2. Choose composition or a smaller boolean change.
3. Move shared state to the nearest stable owner.
4. Preserve loading, empty, and error behavior in tests.
5. Stop when one caller’s convenience would create a framework inside the component.

## Worked example

A `ReadingDialog` has `isEdit`, `isDelete`, and `isReadonly`, but readonly delete is meaningless. It becomes a `ReadingDialog` that always handles dismissal, with caller-supplied body and actions. The edit caller passes a form and save action; the delete caller passes a warning and confirm action. Tests still show the validation error and the pending state. No new context is added because only the dialog owner needs the selection.

## Failure signals

- Adding one mode requires another boolean to suppress the previous mode.
- Context updates on each character and rerenders a large subtree.
- A hook returns markup plus unrelated data loading for several pages.
- Refactoring removes the error or pending representation.

## Evaluation scenario

Given a component with conflicting mode props, the result shows the composed API, the impossible combination it removes, and tests for the remaining states. It fails if it only renames the booleans.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
