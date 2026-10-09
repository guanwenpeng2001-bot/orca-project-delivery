---
name: test-driven-development
description: Use RED-GREEN-REFACTOR to implement behavior with evidence. Use for source changes where a focused automated test can express the intended contract.
---

# Test-Driven Development

## Core principle

Write the test first and watch it fail for the reason you expect. A test that was written after the code, or that fails because of a typo in the test itself, proves nothing about the behavior.

## Decision criteria

Pick the test level by what the behavior crosses:

| Level | Use when | Avoid when |
| --- | --- | --- |
| Unit | The behavior is a decision inside one module with no collaborators | The bug only appears through the interaction of several parts |
| Integration | The behavior depends on a real boundary: database, filesystem, queue, or protocol | The setup cost dwarfs the logic being tested |
| End to end | The requirement is about the path a user or caller actually travels | You are pinning down internal branching |

The valuable failure is a RED that names the missing behavior. An error raised while collecting the test, an import failure, or an assertion that fails because the expected value was mistyped are all RED in appearance and evidence of nothing. Read the failure and confirm it is the assertion you intended before writing any code.

Keep the GREEN change smaller than the test. If making the test pass requires touching several unrelated areas, the test is too broad; split it.

Mock at the boundary you do not own — an external service, the clock, randomness — and never mock the unit whose behavior the test claims to verify. A test that mocks the function under test asserts the mock, not the code.

During REFACTOR, change structure only. If a refactor changes what a test asserts, it was not a refactor and the new behavior needs its own RED first.

### Getting the RED right

The order matters more than the wording. Write the assertion before there is any implementation to satisfy it, run the test, and read the failure. The failure message should describe the behavior that is missing — an unexpected value, an absent effect — so that when it later turns green you know the test is what detected it. If the test errors before reaching its assertion, fix the test setup until the failure is the assertion itself. Only that failure is evidence.

Resist the two common drifts. Writing several tests before any implementation hides which test drove which code. Writing the implementation together with the test, then running it once and seeing green, skips the only step that proves the test can fail. If you realize you wrote code before its test, the honest recovery is to remove the code, watch the test fail, and reintroduce the code — not to keep the unearned green.

### What the test may depend on

A test should be deterministic: no dependence on wall-clock time, network, random ordering, or shared mutable state, unless the behavior under test is precisely about one of those, in which case control it explicitly. Assert on the outcome the requirement names, not on incidental structure such as log lines, private helpers, or call counts, because those couple the test to an implementation and break during legitimate refactoring.

One behavior per test. A test that checks three things fails ambiguously and gets skipped or weakened when one of them changes.

### The tests around the one that passed

When the focused behavior is green, test its neighbors before stopping. Consider the empty input, the boundary value, the repeated call, and a failure from a dependency. Add a test for each neighbor that could plausibly break, and check that it passes because the behavior is correct rather than because the assertion is loose.

Keep the test that reproduced a bug. Once the fix lands, that test is the regression guard, and its value is entirely in failing if the bug comes back. Deleting it after the fix throws away the only evidence that the bug stays fixed.

## Workflow

1. Name the smallest observable behavior and choose its test level.
2. Write one focused test that fails because that behavior is absent or wrong.
3. Run it and confirm the failure reason is the intended one. Keep that output.
4. Write the smallest production change that makes it pass.
5. Run the focused test again and keep the passing output.
6. Refactor within the change while the test stays green.
7. Run the broader relevant suite once, not after every edit.

## Worked example

The bug: applying a discount code twice stacks the discount. Intended behavior: a code applies at most once.

RED: a test that starts a basket with one item priced 100, applies `SAVE10` twice, and asserts the total equals 90. The run fails with the total reported as 81. That failure names the real behavior — the second application compounded — so it is the right RED. A failure saying the basket module could not be imported would not be.

GREEN: the smallest change is recording applied codes on the basket and returning early when the code is already present. The same test now passes showing 90.

A second test, applying two different codes, guards the neighboring behavior so the fix does not reject legitimate stacking. It passes without further changes, which is what you want from a regression guard.

The refactor extracts the "already applied" check into a named predicate. The tests stay green and their assertions are untouched.

## Failure signals

- The first test run is green. The test was written against the finished code and cannot be shown to detect the bug.
- The RED failure is a compilation or import error rather than an assertion about the behavior.
- The fix touches code paths the test does not exercise, so those paths are unverified.
- The test mocks the object it claims to test.
- Assertions are loosened, or expected values are edited, to match what the code happens to do.
- The full suite is run after every keystroke instead of one focused test.

## Evaluation scenario

Given a bug where a retried webhook is processed twice, the result should show: a RED run whose failure message states the webhook was processed twice rather than an error setting the test up; the minimal change that records processed message ids; and one additional test proving a genuinely distinct webhook is still processed. It fails the method if no failing run is shown, or if the shown failure is anything other than the duplicate-processing assertion.

## Output

- RED command and its output, with the failure reason identified
- The change made
- GREEN command and its output
- Broader verification
- Residual concerns

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
