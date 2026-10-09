---
name: integration-verification
description: Verify Task and final-delivery acceptance with commands, runtime evidence, integration checks, and explicit skipped items. Use before completion claims and final delivery.
---

# Integration Verification

## Core principle

Completion is a claim that must be supported by fresh evidence from the correct branch and environment.

## Workflow

1. Confirm the exact branch, commit, environment, configuration, and acceptance criteria.
2. Run focused tests for changed behavior.
3. Run required project gates: type checks, lint, build, unit, integration, or end-to-end as applicable.
4. Exercise critical user or system flows and failure paths.
5. Inspect Git status and diff to ensure process artifacts are excluded.
6. Record commands, relevant outputs, skipped checks, and anomalies.
7. Return READY, NOT_READY, or UNVERIFIABLE.

## Required output

- Environment and commit
- Acceptance matrix
- Commands/results
- Runtime evidence
- Skipped items
- Verdict

## Rules

- Do not reuse stale test claims.
- Do not verify final integration from the coordinator control worktree.
- Do not hide skipped or flaky checks.
- Do not declare READY when a required criterion is unverifiable.

## Completion

The worker must write the requested report, include concrete evidence, state unresolved uncertainty, and return the Task's required completion status. This Skill never authorizes broader scope, branch integration, or orchestration control.
