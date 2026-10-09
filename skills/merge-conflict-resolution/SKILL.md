---
name: merge-conflict-resolution
description: Resolve Git merge conflicts using branch intent, common base, commit history, interfaces, and tests. Use when integrating reviewed work into the delivery branch.
---

# Merge Conflict Resolution

## Core principle

Resolve semantics, not conflict markers.

## Workflow

1. Identify the common base, delivery-side changes, task-side changes, and each branch's intent.
2. Read relevant commits, blame, Task Contracts, reviews, and interface agreements.
3. Classify each conflict: independent additions, same-concept edits, rename/move, generated artifact, or genuine product/architecture disagreement.
4. Combine compatible intent; escalate direction conflicts rather than guessing.
5. Compile, test, and inspect the merged behavior.
6. Document the resolution and any residual risk.

## Required output

- Conflict inventory
- Intent analysis
- Resolution
- Tests
- Escalated decisions
- Final status

## Rules

- Do not choose ours/theirs globally without semantic review.
- Do not drop changes you do not understand.
- Do not include process artifacts.
- Do not resolve a business decision as a technical merge choice.

## Completion

The worker must write the requested report, include concrete evidence, state unresolved uncertainty, and return the Task's required completion status. This Skill never authorizes broader scope, branch integration, or orchestration control.
