---
name: code-review
description: Perform independent, evidence-based review for spec compliance, correctness, lifecycle, concurrency, error handling, maintainability, and test quality. Use before integration.
---

# Code Review

## Core principle

Review the change against what it was asked to do and what it actually does. A review comment must point at a concrete behavior, a violated invariant, or a missing test — not at how the reviewer would have written it.

## Decision criteria

Severity describes impact on the delivered behavior, not how strongly the reviewer feels about it:

| Severity | Meaning | Effect |
| --- | --- | --- |
| Blocker | Incorrect behavior, data loss, security exposure, or a broken contract on a path users or callers reach | Must be fixed before integration |
| Major | A real defect on a less-travelled path, a missing test for risky behavior, or a failure mode left unhandled | Must be fixed or explicitly accepted |
| Minor | A localized maintainability problem that will mislead the next reader | Fix if cheap, otherwise note it |
| Nit | Naming, formatting, or arrangement that tooling does not already enforce | Optional, never blocking |

Judge maintainability against a small closed set of smells, and treat them as judgment calls rather than rules: a name that hides what the thing does, duplicated logic that diverges, a function that reaches into another module's data instead of asking it, a primitive value standing in for a concept, the same conditional shape repeated across the code, one change that forces edits in many places, and abstraction built for a need that does not exist yet. The project's own stated conventions override this baseline. Do not flag what a linter, formatter, or type checker already enforces.

A finding needs all of: a location, the behavior or rule at issue, why it matters, and the severity. A comment missing any of these is an opinion and should not be filed.

Tests are part of the change. Ask whether the tests fail if the behavior regresses, whether they exercise the failure path, and whether they would pass for the wrong reason.

### What to trace, specifically

For each changed path, answer concrete questions rather than generally "reviewing":

- Correctness: does the change do what the requirement says for the normal input, the boundary input, and the empty input?
- State: can the operation run twice, overlap with itself, or run on an object already in the end state? What happens in each case?
- Failure: if a dependency fails midway, is the resulting state consistent, or half-applied with nothing recorded?
- Resources: is everything opened also closed on both the success and the error path?
- Concurrency: if two callers execute this at once, can they corrupt shared state, or does one wait on the other indefinitely?
- Contract: does the observable behavior — returned values, status codes, persisted data, emitted events — stay compatible with existing callers?

### Judging the tests

A test guards a behavior only if deleting that behavior would fail it. Read the assertion and ask what it actually pins down. Assertions on a mock's call arguments verify the collaboration; assertions on the resulting state verify the outcome. A change needs the second kind for its core behavior. A test that constructs the situation it claims to test by stubbing out the very function under test verifies nothing, however thorough it looks.

### Reviewing against the requirement first

List what the change was supposed to do before reading how it does it. Behavior the requirement asks for that is absent from the diff is a finding even though no line is wrong. Behavior the diff adds that no requirement asked for is scope creep worth flagging, because it carries risk nobody reviewed.

Then look for damage in the code the diff passes through: an early return that skips cleanup added elsewhere, a renamed symbol missed at one call site, an error branch returning a shape the caller does not handle. These are the defects a line-by-line reading misses and a path tracing catches.

## Workflow

1. Read the objective, the requirements, the project rules, and the implementation report before the code.
2. Read the whole diff, then the surrounding code the diff depends on.
3. Trace the success path, the failure paths, state transitions, resource cleanup, concurrent access, and data integrity.
4. Assess the tests for what they actually assert and what regression they would miss.
5. Check scope, compatibility, security, and performance only where the change makes them material.
6. Write each finding with location, evidence, impact, and severity.
7. Return APPROVED, CHANGES_REQUIRED, or UNVERIFIABLE.

## Evidence economy

Settle behavior questions with one decisive command, not derivation. If a question about what the code does can be answered by running it, run it once and accept the output; do not reason the answer out from first principles. Keep every single check on a budget: unresolved after roughly ten minutes, record it UNVERIFIABLE with the reason and move to the next item. Scale tracing depth to the risk of the delta — a scaffold, config, or docs change does not earn the same concurrency and failure-path tracing as a state machine. When the coordinator has attached mechanical-check evidence (scans, comparisons, status observations), audit that evidence instead of re-running it.

## Worked example

When calibrating severity or distinguishing behavior defects from preferences, load [Order cancellation review](examples/order-cancellation.md) for concrete findings.

## Failure signals

- Findings cite style preference and carry no behavioral consequence.
- A blocker is justified only by "I would have written this differently."
- The review approves changes whose tests would still pass if the feature were deleted.
- Comments restate what a linter already reports.
- The verdict is APPROVED while a requirement from the objective has no corresponding code or test.
- The reviewer rewrites the code instead of describing the problem.
- The review spends an order of magnitude more effort than the change warranted, or derives by pure reasoning what one command could have shown.

## Evaluation scenario

When maintaining or evaluating this Skill, load [Code review evaluation](references/evaluation.md) for the misleading mock-test scenario and failure criteria.

## Output

- Review scope
- Findings with location, evidence, impact, and severity
- Test assessment
- Checks performed
- Verdict
- Residual risks

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
