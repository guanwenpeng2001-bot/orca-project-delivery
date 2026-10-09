---
name: database-design
description: Design data models, constraints, migrations, transactions, indexes, query patterns, retention, and rollback. Use for schema or persistence changes.
---

# Database Design

## Core principle

Protect invariants in the data model and make migration failure recoverable.

## Workflow

1. Identify entities, ownership, cardinality, lifecycle, and invariants.
2. Define columns/fields, types, nullability, defaults, uniqueness, and referential constraints.
3. Map read/write/query patterns and derive indexes from evidence.
4. Design forward migration, backfill, compatibility window, verification, and rollback.
5. Analyze transactions, concurrency, isolation, idempotency, and failure recovery.
6. Define data tests and operational checks.

## Required output

- Logical and physical model
- Constraints
- Migration and backfill plan
- Index/query plan
- Rollback
- Verification

## Rules

- Do not execute production migration without authorization.
- Do not add speculative indexes or tables.
- Do not rely solely on application validation for critical invariants.
- Do not ignore existing data and downgrade paths.

## Completion

The worker must write the requested report, include concrete evidence, state unresolved uncertainty, and return the Task's required completion status. This Skill never authorizes broader scope, branch integration, or orchestration control.
