---
name: test-driven-development
description: Use RED-GREEN-REFACTOR to implement behavior with evidence. Use for source changes where a focused automated test can express the intended contract.
---

# Test-Driven Development

## Core principle

Observe the test fail for the intended reason before making it pass.

## Workflow

1. Identify the smallest observable behavior and choose the correct test level.
2. Write or adjust a focused test that fails for the missing or incorrect behavior.
3. Run it and preserve the relevant RED evidence.
4. Implement the smallest change that satisfies the behavior.
5. Run the focused test and preserve GREEN evidence.
6. Refactor only within scope while keeping tests green.
7. Run relevant broader tests once the focused behavior is stable.

## Required output

- RED command/output
- Implementation summary
- GREEN command/output
- Broader verification
- Residual concerns

## Rules

- Do not write production code first and invent a passing test afterward when TDD is required.
- Do not weaken assertions to match a bug.
- Do not over-mock the behavior under test.
- Do not run the full suite after every edit when a focused test is available.

## Completion

The worker must write the requested report, include concrete evidence, state unresolved uncertainty, and return the Task's required completion status. This Skill never authorizes broader scope, branch integration, or orchestration control.
