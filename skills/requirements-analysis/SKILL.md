---
name: requirements-analysis
description: Convert objectives and evidence into traceable, unambiguous, testable functional and non-functional requirements. Use before planning or when acceptance is unclear.
---

# Requirements Analysis

## Core principle

Every requirement must describe observable behavior or a verifiable constraint.

## Workflow

1. Identify actors, triggers, preconditions, inputs, outputs, and state transitions.
2. Write functional requirements with stable identifiers.
3. Write non-functional constraints only when supported by the goal or project policy.
4. Define validation, error, authorization, concurrency, compatibility, and recovery behavior.
5. Create acceptance criteria and trace each criterion to a requirement.
6. Flag contradictions, missing information, hidden dependencies, and out-of-scope requests.

## Required output

- Requirement IDs
- Functional requirements
- Non-functional constraints
- Edge and failure cases
- Acceptance traceability
- Assumptions and conflicts

## Rules

- Do not prescribe code structure as a business requirement.
- Do not use vague words such as fast, robust, intuitive, or secure without a testable meaning.
- Do not hide unresolved conflicts.
- Do not make optional behavior mandatory without user direction.

## Completion

The worker must write the requested report, include concrete evidence, state unresolved uncertainty, and return the Task's required completion status. This Skill never authorizes broader scope, branch integration, or orchestration control.
