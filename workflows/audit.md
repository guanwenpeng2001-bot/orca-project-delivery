# Audit Workflow

## Goal

Produce evidence-backed findings for a defined scope without silently turning the audit into an implementation project.

## Intake

Define:

- audit objective;
- target branch or artifact;
- dimensions that matter;
- exclusions;
- severity scale;
- required evidence;
- whether fixes are in or out of scope.

## Dynamic audit fan-out

Create independent Tasks by meaningful risk domain, not a fixed checklist.

Possible domains:

- correctness;
- security;
- architecture;
- data integrity;
- concurrency and lifecycle;
- performance;
- API compatibility;
- product or accessibility;
- tests and observability;
- deployment and operations.

## Finding contract

Every finding must include:

- title;
- severity;
- affected location;
- violated requirement or invariant;
- evidence;
- impact;
- reproduction or reasoning;
- recommended direction;
- confidence;
- whether it blocks delivery.

## Validation and deduplication

A separate reviewer or coordinator:

- removes duplicates;
- rejects unsupported claims;
- resolves conflicting severity;
- distinguishes current-scope findings from unrelated debt;
- records residual uncertainty.

## Optional remediation

When fixes are requested, convert accepted findings into separate implementation Tasks. Reviewers do not modify source directly. Review each implementation with the Task objective, acceptance criteria, exact `base..branch` diff bound to SHAs and relevant contract clauses, without requiring a whole-package re-read.

If that review requires changes, retain both original terminals until the final verdict and route repairs to the original implementer session and re-review to the original reviewer session under [Session reuse](../references/worker-handoff.md#fix-returns-to-original-implementer-session). Workers run Task-relevant verify suites and affected tests plus explicit Task-required checks; remediation integration runs the full suite post-merge and final verification runs it again on latest `delivery_branch` in a clean independent worktree.

## Completion

Deliver:

- scope and method;
- validated findings;
- non-findings or areas checked;
- unverifiable areas;
- prioritized remediation options;
- separate user decisions.
