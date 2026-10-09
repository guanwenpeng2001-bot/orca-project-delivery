---
name: code-review
description: Perform independent, evidence-based review for spec compliance, correctness, lifecycle, concurrency, error handling, maintainability, and test quality. Use before integration.
---

# Code Review

## Core principle

Review against the objective and actual behavior, not personal style.

## Workflow

1. Read the objective, requirements, Task Contract, project rules, baseline, target branch, and implementation report.
2. Inspect the full diff and relevant surrounding code.
3. Trace important success, failure, state, resource, concurrency, and data-integrity paths.
4. Evaluate tests: behavior verified, failure sensitivity, isolation, determinism, and missing edges.
5. Check scope discipline, compatibility, security, performance, and operational impact as material.
6. Write findings with severity, location, evidence, impact, and suggested direction.
7. Return APPROVED, CHANGES_REQUIRED, or UNVERIFIABLE.

## Required output

- Review scope
- Findings
- Checks performed
- Test assessment
- Verdict
- Residual risks

## Rules

- Do not edit the reviewed source.
- Do not report unrelated pre-existing debt as a blocker.
- Do not accept implementation claims without evidence.
- Do not inflate severity for style preference.

## Completion

The worker must write the requested report, include concrete evidence, state unresolved uncertainty, and return the Task's required completion status. This Skill never authorizes broader scope, branch integration, or orchestration control.
