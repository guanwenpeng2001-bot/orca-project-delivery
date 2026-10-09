---
name: postgres-practices
description: Choose PostgreSQL indexes, query plans, constraints, and row-level access from measured behavior. Use for PostgreSQL schema or query work.
---

# PostgreSQL Practices

## Core principle

PostgreSQL evidence is a query plan and a constraint exercising the real data shape. A proposed index or policy without that evidence is a hypothesis.

## Decision criteria

Match an index to a predicate. Equality plus a recent-range sort points to a B-tree with the equality columns first. A predicate used by only one tenant or status points to a partial index. A query satisfied from the index alone can use a covering index. Add none of these until `EXPLAIN (ANALYZE, BUFFERS)` shows the cost before and after on representative volume.

Use `NOT NULL`, foreign keys, checks, and unique constraints for invariants the application also believes. A unique index is the concurrency guard: two transactions can pass a read-before-write check, but only one unique insert succeeds.

For tenant isolation, row-level security belongs in the table policy, not only in application filters. Test it with two database roles or set tenant values and prove that one tenant’s predicate cannot read the other tenant’s row. `FORCE ROW LEVEL SECURITY` matters when the table owner runs maintenance; record whether it is intended.

Keep transactions around the statements that establish the invariant. PostgreSQL read committed can observe another commit between statements, so a balance read and debit that need one consistent result belong in one transaction. Serializable transactions can abort; the caller needs a bounded retry.

### Reference

The method is original. Planner and row-level security behavior are documented by PostgreSQL: https://www.postgresql.org/docs/current/using-explain.html and https://www.postgresql.org/docs/current/ddl-rowsecurity.html

## Workflow

1. Capture the exact statement, data volume, and current plan.
2. Identify the predicate, sort, and returned columns.
3. Apply one structural change and compare the new plan and time.
4. Add the constraint or policy test that fails when isolation or uniqueness is absent.
5. State what was not run if no local PostgreSQL instance was available.

## Worked example

A reading list filters `tenant_id = $1` and orders by `observed_at desc`, scanning 2 million rows. A B-tree on `(tenant_id, observed_at desc)` changes the plan from a sequential scan to an index scan, and the analyzed time drops from 480ms to 6ms on the fixture. A second session inserts the same `(tenant_id, source_id)` and fails on the unique constraint. With row-level security enabled, tenant A’s role receives zero rows for tenant B.

## Failure signals

- An index is recommended from a table name without a plan.
- The plan was read on an empty table and generalized to production volume.
- Tenant isolation is asserted only through an application `WHERE` clause.
- A long transaction stays open while application code waits for a user or remote call.

## Evaluation scenario

Given a slow tenant-filtered query, the result contains before-and-after plans, the chosen index order, and one cross-tenant refusal. It fails if it predicts improvement without executing or inspecting a plan.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
