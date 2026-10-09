---
name: api-design
description: Design stable HTTP, RPC, event, CLI, or module contracts with validation, errors, idempotency, auth, compatibility, and contract tests. Use when interfaces change.
---

# API Design

## Core principle

An interface is a contract with every current and future consumer. Valid use should be easy, invalid use should fail with a named reason, and every change should state whether existing consumers keep working.

## Decision criteria

Classify each change before designing it:

- Additive and safe: a new optional field, a new operation, a new error code appended to a documented set. Ship it; consumers that ignore unknown fields are unaffected.
- Behavior-changing: a field changes meaning, a default changes, an error shape changes, a previously accepted input is rejected. This breaks anyone who depended on the old behavior, including behavior you never promised (Hyrum's Law: with enough consumers, every observable behavior becomes a dependency). Deprecate, don't switch.
- Removing: an operation or field goes away. Only after a deprecation window where the old form still works and emits a signal consumers can detect.

Choose the error discipline up front and keep it uniform. One error envelope for the whole interface, for example `{ "error": { "code", "message", "details" } }`, where `code` is a stable machine-readable identifier and `message` is for humans and may change wording. Never signal failure with a success status and an error flag in the body, and never return a bare string.

Decide idempotency by operation effect:

| Effect | Rule |
| --- | --- |
| Read, or pure computation | Naturally retry-safe |
| Create | Require an idempotency key; a retry returns the original result instead of creating a second resource |
| Update to an absolute state (set status = X) | Retry-safe |
| Update by delta (increment, append, charge) | Not retry-safe; require an idempotency key or a compare-and-swap version |
| Delete | Retry-safe only if deleting an absent resource returns the same outcome as the first delete |

Paginate with keyset pagination on a stable, unique, ordered column: the client passes the last item it saw and the server returns items strictly after it. Offset pagination shifts or skips rows when data changes between pages, so use it only for static datasets. State the sort and the tie-breaker explicitly.

Version only when a real consumer must keep using the old contract. Prefer evolving one contract with strict compatibility rules over running parallel versions, and never add a version prefix speculatively.

### Contracts beyond request/response

The same discipline applies to other interface shapes, with different failure mechanics.

Events and messages: a consumer must tolerate redelivery, late arrival, and arrival out of order, because most brokers promise at-least-once delivery and almost none promise exactly-once, so design for redelivery rather than relying on the broker. Carry an idempotency identifier in the payload so reprocessing is harmless, and version the payload schema so a consumer can distinguish a shape it understands from one it must skip. Never change the meaning of an existing field; add a new one.

Module and library interfaces: a public function signature is a contract even without a network. A new required parameter, a changed return shape, or a raised exception where none was raised before are behavior changes and need the same deprecation treatment. An internal function with no external caller is not a contract and can change freely — confirm which it is before treating it as one.

Command-line interfaces: a flag's name and default are the contract. Changing a default changes behavior for every existing invocation, so treat it as a behavior change. Exit codes are the error envelope; keep them stable and documented.

### Compatibility rules worth writing down

- Additive: new optional fields, new operations, new error codes are safe only if consumers already ignore fields and codes they do not recognize. If a consumer rejects unknown fields, even an addition breaks it — verify the parser behavior.
- Defaults are behavior. Changing a default is invisible in the schema and breaks callers who relied on it.
- Ordering, collation, and pagination stability are observable behavior. Consumers will depend on them whether or not you documented them.
- Removing or renaming a field is the most expensive change; do it last, after the window, never in place.

### Partial failure and long-running work

When one request triggers several operations, define partial success explicitly. Either the whole request succeeds, or the response names which parts succeeded and which failed, using the same error envelope for each part, so the client retries only the failed parts. Never report success because most of the parts worked.

For work that outlasts the request, return a resource the client can query for status, with the status values documented as a closed set such as accepted, running, succeeded, and failed. The request that starts the work stays idempotent, so repeating it returns the existing job instead of starting a second one.

## Workflow

1. Name the consumers, who owns the contract, and how long they are entitled to the current behavior.
2. Define each operation's inputs, outputs, validation rules, and the single error envelope.
3. Specify authentication, authorization, rate limits, idempotency, retry behavior, timeouts, pagination, and partial failure only where the operation actually needs them.
4. Classify every change as additive, behavior-changing, or removing, and write the deprecation plan for the latter two.
5. Check that names and error shapes match the interfaces the project already ships.
6. Write one example of valid use, one of each rejected input, and the contract tests that lock both.

## Worked example

A payment endpoint creates a charge. The first draft accepts `{ "amount": 5000 }` and returns `200` with `{ "success": false, "error": "card declined" }` when the card is declined, and a retry of a timed-out request creates a second charge.

The revised contract:

- `POST /charges` with an `Idempotency-Key` header and `{ "amount": 5000, "currency": "usd" }`. `amount` is a positive integer in minor units and `currency` is an explicit code, so the unit and currency cannot be guessed.
- Success is `201` with `{ "id": "ch_123", "status": "succeeded" }`.
- A declined card is `402` with `{ "error": { "code": "card_declined", "message": "The card was declined." } }`. A missing amount is `400` with `code: "amount_required"`.
- Replaying the same idempotency key returns the original `201` and the original charge id, verified by asserting one row exists.

Deprecating the `amount`-only form means accepting it through the published window while including a `Deprecation` signal, then rejecting it with `code: "currency_required"` afterward.

## Failure signals

- Two operations return errors in different shapes, so clients write special cases per endpoint.
- A retry of a timed-out create produces a duplicate resource.
- A response uses a success status to carry a failure, so generic client tooling treats it as success.
- A field is renamed or retyped in place with no deprecation window.
- Pagination uses a bare offset on data that changes between requests.
- The contract leaks internal table or column names that consumers will couple to.

## Evaluation scenario

Given an endpoint that changes from returning a single object to returning a paginated list, the result should: name every observable behavior a consumer could depend on (field names, ordering, the old single-object shape, status codes); keep the error envelope identical; state the deprecation window for the old shape and the contract test that proves a replay is idempotent. It fails the method if the new shape ships with no migration path, or if error handling differs between the old and new form.

## Output

- Contract specification
- Validation and error model
- Idempotency and pagination behavior
- Compatibility and deprecation plan
- Examples
- Contract tests

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
