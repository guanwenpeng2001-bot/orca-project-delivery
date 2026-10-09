---
name: api-design
description: Design stable HTTP, RPC, event, CLI, or module contracts with validation, errors, idempotency, auth, compatibility, and contract tests. Use when interfaces change.
---

# API Design

## Core principle

Make valid use easy, invalid use explicit, and compatibility intentional.

## Workflow

1. Identify consumers, ownership, lifecycle, and compatibility expectations.
2. Define operations, inputs, outputs, schemas, validation, and error taxonomy.
3. Specify authentication, authorization, rate limits, idempotency, retries, timeouts, pagination, and partial failure where relevant.
4. Define versioning, deprecation, migration, and backward-compatibility behavior.
5. Check consistency with existing project APIs and terminology.
6. Create examples and contract-test scenarios.

## Required output

- Contract specification
- Validation and error model
- Security and lifecycle rules
- Compatibility plan
- Examples
- Contract tests

## Rules

- Do not expose internal representations accidentally.
- Do not return ambiguous success or error shapes.
- Do not add versioning or abstraction without a real compatibility need.
- Do not omit failure semantics.

## Completion

The worker must write the requested report, include concrete evidence, state unresolved uncertainty, and return the Task's required completion status. This Skill never authorizes broader scope, branch integration, or orchestration control.
