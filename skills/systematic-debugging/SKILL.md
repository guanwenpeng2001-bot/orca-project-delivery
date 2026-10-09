---
name: systematic-debugging
description: Reproduce, isolate, explain, fix, and verify defects through evidence-driven hypothesis testing. Use for bugs, flaky behavior, regressions, and unexplained failures.
---

# Systematic Debugging

## Core principle

Do not patch a symptom until the failure mechanism is understood well enough to predict the fix.

## Workflow

1. Capture the exact symptom, environment, expected result, and reproduction reliability.
2. Reduce the problem to the smallest failing case.
3. Trace inputs, state, control flow, side effects, and recent relevant changes.
4. List competing hypotheses and design discriminating tests.
5. Use evidence to eliminate hypotheses and identify the failure mechanism.
6. Implement the smallest root-cause fix.
7. Verify the original symptom, regression test, and nearby impact surface.

## Required output

- Reproduction
- Hypothesis table
- Root-cause explanation
- Fix
- Regression evidence
- Remaining uncertainty

## Rules

- Do not fix by increasing arbitrary timeouts without evidence.
- Do not treat correlation as cause.
- Do not change multiple independent variables at once.
- Do not claim root cause if the explanation cannot predict the observed behavior.

## Completion

The worker must write the requested report, include concrete evidence, state unresolved uncertainty, and return the Task's required completion status. This Skill never authorizes broader scope, branch integration, or orchestration control.
