---
name: migration-upgrade
description: Order a dependency, framework, library, or API upgrade so every step ships independently and reverses. Use when a version change must roll out while old and new code both run. Not for designing a new schema.
---

# Migration Upgrade

## Core principle

Ship the change as a sequence of states where every running version can talk to every deployed neighbor. A step that only works once everything else has moved is a lockstep deploy, and lockstep is how upgrades fail in production.

## Decision criteria

Detect the version before changing behavior. Read the dependency's declared version, a response field, or a feature flag the old and new forms both expose. Branch on that observation. Guessing from "what we deployed last week" is not detection.

Order the work in four kinds of step:

| Step | What ships | Reversible by |
| --- | --- | --- |
| Expand | Add the new form beside the old. Nothing reads it yet | Removing the added form |
| Dual-run | Producers write both, or callers send both, while consumers still read the old | Stopping the new writes |
| Switch | Move readers to the new form, one consumer at a time | Pointing that reader back |
| Contract | Remove the old form | Not reversible; do it last |

The contract step destroys information or a supported contract. It waits until every consumer that needed the old form has been observed on the new one. "We deployed the switch last Tuesday" is not an observation.

Rollback and roll-forward solve different problems. Rollback returns a consumer to the previous step, which is only possible while the old form still exists. Roll-forward fixes a bad new version by deploying a newer one; it assumes the data and the contract survived. Name which one a given failure uses. Do not call a redeploy a rollback when the contract step has already dropped the old form.

### Where schema work goes

A database schema migration, including backfill and table rewrites, belongs to `database-design`. This method cites that plan and sequences the application upgrade around it. It does not restate how to batch a backfill or choose an index.

Keep a compatibility window explicit: the versions that must run at the same time, how long the window stays open, and the signal that closes it. Closing it is the contract step.

## Workflow

1. Name the old version, the new version, and who calls whom during the window.
2. List the observable differences: request shape, response shape, config, and runtime behavior.
3. Choose the detection signal and confirm both versions expose it.
4. Write expand, dual-run, switch, and contract as separate deploys, each with a check and a reversal.
5. Mark the first irreversible step and what evidence must exist before it.
6. For each failure, say whether the response is rollback or roll-forward.

## Worked example

An HTTP client speaks API v1 and the server is moving to v2, whose body nests the current fields under `data`. Old and new servers run together for the window.

| Step | Deploy | Check | Reversal |
| --- | --- | --- | --- |
| 1. Expand | Server accepts v1 and v2. Detection is the `Accept-Version` header; a missing header means v1 | A v1 request still returns the flat body | Drop the v2 parser |
| 2. Dual-run | Client sends `Accept-Version: 2` and still understands a flat body | Server logs show both header values, and the client renders either shape | Client sends no header |
| 3. Switch | Client reads only the nested body | No client release still in production sends a missing header | Ship the previous client |
| 4. Contract | Server rejects a missing header | Error rate for missing-header requests is explained by callers outside the fleet | None; needs a new expand to undo |

The first irreversible step is 4. It is blocked until step 3's observation holds for every client release still serving traffic. A server bug found at step 2 is a rollback to step 1. A server bug found at step 4 is a roll-forward, because the flat body is gone.

Shipping the client and the server in one change, so the client only understands v2 and the server only emits v2, fails the method: during the deploy one of them is live without the other.

## Failure signals

- Two components must deploy in the same change for either to work.
- Version is inferred from a deploy calendar instead of read from the peer.
- The old form is removed in the same step that introduces the new one.
- Rollback instructions for the contract step say "redeploy the old build" although the old form no longer exists.
- The plan rewrites tables or chooses indexes instead of pointing at `database-design`.
- A compatibility window has no stated end signal.

## Evaluation scenario

Given a client on API v1 and a server moving to a nested v2 body while both servers run, the result should split expand, dual-run, switch, and contract into separate deploys, name the header used for detection, and identify the contract step as the first irreversible one. It fails the method if client and server must ship together, or if the plan treats redeploying the old server as a rollback after the flat body is removed.

## Output

- Version detection signal
- Ordered steps, each with its check and reversal
- The compatibility window and the observation that closes it
- The first irreversible step
- Per-failure choice of rollback or roll-forward

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Schema migrations stay with `database-design`. Product direction, scope, and irreversible choices stay with the user.
