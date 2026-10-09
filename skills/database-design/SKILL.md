---
name: database-design
description: Design data models, constraints, migrations, transactions, indexes, query patterns, retention, and rollback. Use for schema or persistence changes.
---

# Database Design

## Core principle

The data model is where invariants are enforced, because application code is bypassed by migrations, scripts, and bugs. A schema change on a live system must be safe to deploy one step at a time and recoverable when a step fails.

## Decision criteria

Index for measured access paths, not for tables. Match the index to the predicate: equality and range on scalar columns want a B-tree; containment queries want the structure built for them; a column referenced in only a fraction of rows wants a partial index limited to those rows; a query satisfied entirely from the index wants a covering index. Read the query plan before and after, and add no index you cannot point at a query and a measured cost for.

Migrate a live table with expand, then migrate, then contract, so each deployment is backward compatible with the code still running:

1. Expand: add the new structure as nullable or alongside the old one. Nothing reads it yet, so this step cannot break the running release.
2. Migrate: deploy code that writes both structures, backfill existing rows in batches, then deploy code that reads the new structure.
3. Contract: once no running code reads the old structure, drop it.

Choose a backfill batch size from observation, not a fixed number: large enough to finish, small enough that each batch's lock and write volume stays inside the latency the application tolerates. Pause between batches.

Treat rollback as a property of each step, not of the whole migration. An expand step rolls back by dropping what it added. A backfill rolls back by ignoring the new column. The contract step is the one that destroys information, so it happens last and only after the new path is proven.

### Reading a query plan

A plan tells you how the database will actually execute a statement. Check which index, if any, is used, how many rows it estimates versus how many come back, and where the cost concentrates. A sequential scan on a large table that is filtered to a few rows means a missing or unusable index. An index that exists but is not chosen is dead weight on every write. Estimates far from reality usually mean stale statistics. Confirm an index change by comparing the plan and the measured time before and after, on a realistic volume of data, not on an empty table where every plan looks fine.

### Transactions and concurrency

Pick the isolation level for the anomaly the operation is exposed to, and confirm what that level actually guarantees in the database you are running. The names are not portable. Under PostgreSQL's read committed, a transaction can see another transaction's committed changes between its own statements, so a value read and then relied on for a write can change underneath it. Its repeatable read gives a stable snapshot but does not by itself prevent two transactions from writing decisions based on the same stale read. Serializable prevents that class of anomaly but does not make transactions run one at a time; it detects the dangerous interleaving and aborts one transaction, so the application has to be ready to retry. Another engine draws these lines differently, so name the anomaly and verify the guarantee instead of trusting the level's name.

A transaction has to cover the read that an invariant depends on, not just the write. Checking a balance in one transaction and recording the debit in another lets a concurrent debit land between them, and no isolation level on the second transaction can see a read it did not make.

Keep transactions short. One that stays open across a network call or a user's think time holds its locks the whole time, so open the transaction around the statements that need it and nothing else. A deadlock is two transactions locking the same rows in opposite orders; give concurrent writers one consistent lock order.

For idempotency at the data layer, use a unique constraint as the guard rather than a check-then-insert. Two concurrent requests both pass a pre-check; only one can win a unique insert, so the constraint is what actually prevents the duplicate.

### Data lifecycle

State a retention rule for data that grows without bound: what is kept, for how long, and how removal happens. Deleting a large fraction of a table in one statement holds locks and bloats indexes; batch it, or partition by time so dropping an old partition is a metadata change rather than a row-by-row delete. Partition only when the access pattern aligns with the partition key — partitioning a table that is queried across all partitions makes every query slower.

### Constraints that carry integrity

Put each invariant at the strongest layer that can express it, and leave to application code only what the database cannot see.

- A column type and `NOT NULL` express that a value always exists and has a given shape.
- A unique constraint on the columns that define identity closes the race where two concurrent checks both pass and both insert.
- A foreign key with an explicit delete behavior — restrict, cascade, or set null — defines what happens to dependent rows when a parent goes away. Leaving it implicit produces orphans.
- A check constraint keeps a column inside its domain so invalid values never accumulate.

Name constraints yourself, so a violation names the rule that failed and the application can map it to a specific message, rather than a generated identifier that says nothing.

## Workflow

1. List entities, their ownership, cardinality, lifecycle, and the invariants that must always hold.
2. Define columns, types, nullability, defaults, and the constraints that carry those invariants.
3. Collect the real read and write patterns and derive indexes from them, confirming each with a query plan.
4. Write the migration as expand, migrate, and contract steps, each with its own verification and reversal.
5. Check transaction scope, isolation level, concurrent writers, and what happens when a step fails halfway.
6. State the data checks that prove each step landed.

## Worked example

Renaming `users.full_name` to `users.display_name` on a table that stays online:

- Expand: add `display_name` as nullable. Verify the column exists and is unpopulated. Reversal: drop it.
- Dual-write: deploy code that writes both columns. Verify new rows fill both.
- Backfill: copy `full_name` into `display_name` in batches sized so each batch holds its write lock briefly enough that request latency stays flat. Verify a count of rows where the two columns differ returns zero.
- Switch reads to `display_name`, deploy, and verify the application no longer references `full_name`.
- Contract: enforce `NOT NULL` on `display_name`, then drop `full_name`. This is the first irreversible step, taken only after the previous verification passed.

A single `ALTER TABLE ... RENAME COLUMN` instead would be faster and would break the code still running against the old name during deployment.

## Failure signals

- An invariant such as uniqueness or a required value is enforced only in application code.
- A migration rewrites a whole table in one transaction, holding a lock for its duration.
- An index exists that no query plan uses, costing writes on every insert.
- The rollback story is "restore the backup" rather than a reversal per step.
- A query plan shows a sequential scan on a column the workload filters by constantly.
- Two deployments must ship simultaneously for the change to work.

## Evaluation scenario

Given a requirement to split a `name` column into `given_name` and `family_name` on a table under continuous writes, the result should present each step as independently deployable and reversible, name the verification query that proves the step, and justify the backfill batch size from an observed lock or latency limit. It fails the method if any step needs the old and new code to deploy together, or if the destructive step comes before the new path is verified.

## Output

- Logical and physical model
- Constraints and the invariants they carry
- Migration plan with per-step verification and reversal
- Index plan tied to query evidence
- Concurrency and failure behavior
- Data checks

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
