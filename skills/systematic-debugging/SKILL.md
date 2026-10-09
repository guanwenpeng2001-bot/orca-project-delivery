---
name: systematic-debugging
description: Reproduce, isolate, explain, fix, and verify defects through evidence-driven hypothesis testing. Use for bugs, flaky behavior, regressions, and unexplained failures.
---

# Systematic Debugging

## Core principle

Understand the mechanism before changing anything. A fix you cannot predict from your explanation is a guess, and guesses that happen to pass the test hide the real defect.

## Decision criteria

Work in phases and do not skip ahead. First make the failure reproducible on demand, or establish precisely how often it occurs. Then shrink it to the smallest case that still fails. Only then form hypotheses. A hypothesis is admissible only if you can name an observation that would rule it out; "something is wrong with the cache" is not one, because no result could contradict it.

When several components are involved, instrument each boundary rather than staring at the final symptom: log what enters and leaves each stage, including the values and the timing. The stage whose output first diverges from expectation is where the defect lives.

Test hypotheses by elimination. Change one variable per experiment, and prefer an experiment that kills a hypothesis outright over one that merely supports it. Record what each experiment ruled out, so the same idea is not retested in disguise.

Stop after three attempted fixes that did not work. Three failures mean the model of the system is wrong, not that a fourth guess is due. Go back to reproduction and question the premise.

Order hypotheses by how cheaply they can be killed and how much of the symptom they explain. A hypothesis that explains only half the observations is incomplete even if an experiment supports it.

### Making an intermittent failure tractable

An intermittent failure is debuggable only once you can influence its rate. Find the condition it correlates with — load, ordering, timing, specific data — and amplify that condition so the failure happens on demand. Raise the concurrency, repeat the run, or pin the input that precedes it. A failure that occurs one time in five becomes investigable; one that occurs one time in a thousand does not, and no amount of code reading substitutes for seeing it.

Bisect to localize. If the failure appeared between two points in history, split the range and test the middle until the single change that introduced it falls out. If it appears only with a particular input, halve the input until the smallest triggering case remains. Both turn a vague symptom into a precise cause.

### Instrumentation that localizes

Log at boundaries rather than everywhere: what entered a stage, what left it, and how long it took. The first boundary where the output stops matching expectation is where to look next, and it tells you which hypothesis to test instead of adding print statements randomly. Remove or gate the instrumentation once the mechanism is found so it does not become permanent noise.

When you have a mechanism, confirm it predicts something you have not yet looked at. An explanation that only restates the one observation you started from is weak; one that correctly predicts a second, different observation is probably right.

### Proving the fix hit the cause

A green test after a change shows the symptom disappeared, not why. Check the mechanism directly, before and after: the number of queries, the lock that was held, the value at the boundary you instrumented. It should change exactly the way your explanation predicted. If the symptom is gone but the mechanism is unchanged, the fix worked by coincidence and the failure will return in another form.

Then check the surroundings. The smallest correct fix can still change a neighboring behavior, so run the tests that share the changed code and look for state it now treats differently.

## Workflow

1. Record the exact symptom, the environment, what should have happened, and whether the failure is reliable or intermittent.
2. Reduce to the smallest case that still fails.
3. Trace inputs, state, and side effects across the relevant boundaries, adding instrumentation where the path is opaque.
4. Write competing hypotheses, each with the observation that would falsify it.
5. Run the discriminating experiments and eliminate until one mechanism remains.
6. Apply the smallest change that removes that mechanism.
7. Confirm the original symptom is gone, add a regression test, and check the area the change touches.

## Worked example

A test fails only in CI: an order total is occasionally off by a cent.

Reproduction shows it fails roughly one run in five, and only when the whole file runs, never alone. That points away from the arithmetic itself.

Hypotheses:

| Hypothesis | Would be killed by |
| --- | --- |
| Floating-point rounding in the pricing function | Running the single test in a loop; if it never fails, rounding is not intermittent |
| Shared state leaking from an earlier test | Running the file with the preceding tests removed; if the failure disappears, leakage is the cause |
| Clock-dependent logic | Freezing the clock; if failures still occur, time is irrelevant |

The single test never fails in a loop, eliminating rounding. Removing the preceding test, which inserts a row the failing test also reads, eliminates the failure entirely. The mechanism: the earlier test commits a promotion row that the database does not roll back between tests, and the failing test reads it. The fix scopes that row to the test's own transaction. The explanation predicts the observed behavior — the failure depends on test order — and the regression test runs the file repeatedly with a fixed seed and asserts isolation.

## Failure signals

- A fix ships without anyone being able to state why it works.
- Timeouts, retries, or sleep calls are increased to mask an intermittent failure.
- Several things are changed at once, so the run that passes cannot be attributed.
- The same hypothesis is tested repeatedly under different wording.
- The explanation accounts for the failure in one environment but not in the other where it also occurs.
- A fourth fix is attempted without revisiting the model.

## Evaluation scenario

Given a test that passes locally and fails intermittently in CI, the result should include a hypothesis table where every row names the observation that would kill it, the experiment outcomes that eliminated rows, and a root-cause statement written before the fix that correctly predicts when the failure appears. It fails the method if the fix is a longer timeout or an added retry, or if the explanation was written after seeing that the fix worked.

## Output

- Reproduction steps and reliability
- Hypothesis table with falsifying observations
- Experiments and what each eliminated
- Root-cause explanation
- Fix and regression evidence
- Remaining uncertainty

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
