# Bug Fix Workflow

## Goal

Reproduce a reported symptom, establish the most likely root cause with evidence, implement the smallest correct fix, and verify the original behavior and regression surface.

## Stages

### Intake

Capture:

- observed symptom;
- expected behavior;
- environment;
- reproduction information;
- severity;
- delivery branch;
- known recent changes.

### Reproduction

Create an isolated reproduction Task. Prefer a deterministic failing test or script. Do not modify production code yet.

Output:

- exact reproduction steps;
- actual result;
- expected result;
- evidence;
- whether reproduction is stable, intermittent, or unavailable.

### Investigation

Split independent hypotheses only when useful. Investigators must attempt to disprove their initial theory.

Output:

- narrowed execution path;
- state transitions;
- recent relevant history;
- competing hypotheses;
- evidence for and against;
- root-cause confidence;
- unknowns.

### Fix planning

Define:

- intended invariant;
- smallest fix;
- files and interfaces;
- regression test;
- risks;
- rollback.

### Implementation

Use the Software Implementer Role (`software-implementer`) in an isolated branch. Preserve the failing evidence before the fix and passing evidence after it.

### Review

Independent review focuses on:

- whether the assessed cause is actually fixed;
- whether the symptom is merely hidden;
- boundary and concurrency behavior;
- regression-test quality;
- unintended scope expansion.

### Integration and verification

Merge the approved fix directly into `delivery_branch`, then verify from a clean worktree:

- original symptom;
- regression test;
- nearby affected behavior;
- relevant full suite or integration checks.

## Stop conditions

Do not claim success when:

- the symptom was never reproduced and no equivalent proof exists;
- the root cause remains speculative;
- tests pass only after weakening assertions;
- the fix introduces an unexplained behavior change.
