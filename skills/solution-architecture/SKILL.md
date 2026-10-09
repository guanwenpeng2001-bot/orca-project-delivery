---
name: solution-architecture
description: Design minimal software boundaries, responsibilities, interfaces, data flow, migration, rollback, and operational behavior for a scoped objective. Use for cross-module or high-risk changes.
---

# Solution Architecture

## Core principle

Choose the smallest architecture that solves the current problem and fits the existing system.

## Workflow

1. Map the current architecture and constraints relevant to the objective.
2. Define components, responsibilities, dependency direction, and data ownership.
3. Specify interfaces, state transitions, failure behavior, observability, and security boundaries.
4. Evaluate alternatives and explain why the chosen design is preferable now.
5. Define migration, compatibility, rollback, and deployment implications.
6. Produce a taskable design with verification points.

## Required output

- Context and constraints
- Component responsibilities
- Interfaces and data flow
- Alternatives and decision
- Migration/rollback
- Risks and verification

## Rules

- Do not design a platform for a one-off need.
- Do not ignore existing project patterns.
- Do not hide cross-cutting costs.
- Keep architecture decisions reversible where practical.

## Completion

The worker must write the requested report, include concrete evidence, state unresolved uncertainty, and return the Task's required completion status. This Skill never authorizes broader scope, branch integration, or orchestration control.
