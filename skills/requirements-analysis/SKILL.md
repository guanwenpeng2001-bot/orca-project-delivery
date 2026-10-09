---
name: requirements-analysis
description: Convert objectives and evidence into traceable, unambiguous, testable functional and non-functional requirements. Use before planning or when acceptance is unclear.
---

# Requirements Analysis

## Core principle

A requirement is a statement of observable behavior or a verifiable constraint, specific enough that two people would agree on whether it was met. If reasonable readers could disagree, it is not finished.

## Decision criteria

Give every requirement a stable identifier such as `REQ-1`, so tests, designs, and later changes can point at it. Never refer to requirements by position in a list, which changes as the list grows.

Apply the testability test to each one: name the command, assertion, or observation that would decide whether it is satisfied. A statement that fails this test is an aspiration. Rewrite it until the deciding observation is explicit.

Replace unmeasurable words. "Fast" becomes a latency bound on a stated operation. "Intuitive" becomes a task a new user completes unaided. "Secure" becomes the specific control: who is authorized, what is rejected, what is encrypted. "Robust" and "user-friendly" get the same treatment. If no number or observation can be supplied, the item is an open question, not a requirement.

Separate functional behavior from non-functional constraint, and only include a non-functional constraint when the objective or a project policy supports it. An invented performance target is a hidden decision.

Write the failure behavior beside the success behavior. For every requirement, ask what the system does with bad input, a denied permission, a mid-operation failure, and concurrent use. Unstated failure behavior becomes whatever the implementer improvises.

Keep a conflict register. When two requirements contradict, or a requirement contradicts an existing behavior, record both sides and whose decision it is. Do not silently pick one.

Trace each acceptance criterion back to the requirement it proves, and check that every requirement has at least one criterion. A requirement with none cannot be verified; a criterion with no requirement is scope that arrived unnoticed.

### States, concurrency, and compatibility

For behavior that moves through states, write the allowed transitions explicitly: which states lead to which, what triggers each, and what is rejected from the wrong state. Most defects in stateful features live in the transitions nobody wrote down.

For anything that more than one actor can do at once, state the concurrency behavior. What happens when two people edit the same record, when a request is retried, or when an action arrives for an object that has since changed? "Last write wins" is an acceptable answer when it is chosen deliberately; it is a defect when it happens by omission.

For changes to existing behavior, state the compatibility requirement. Does existing data still load, do existing integrations keep working, and is there a period where old and new behavior coexist? A requirement that describes only the end state leaves the migration unspecified.

### Keeping requirements stable

Write one behavior per requirement so a change touches one identifier. Keep requirement identifiers stable across revisions; when a requirement is dropped, retire its identifier rather than reusing it, so old references do not silently point at new behavior. Record assumptions next to the requirement that depends on them, so if an assumption proves false the affected requirements are obvious.

### The questions each requirement must answer

Walk every requirement through the same questions so its failure behavior is chosen, not accidental. What are the smallest and largest valid inputs, and what happens just outside them? What if the referenced object does not exist or was already deleted? What if the caller lacks permission? What if the operation is repeated, or overlaps another in progress? If a dependency fails halfway, what state is left behind and can the operation be retried safely? What must remain true for data and callers that already exist?

Record the answer beside the requirement. A question you cannot answer is an open item to raise, not a blank for the implementer to fill in privately.

## Workflow

1. Identify the actors, what triggers the behavior, the inputs, the outputs, and the state changes.
2. Draft functional requirements with identifiers, one behavior each.
3. Add non-functional constraints only where the objective or policy demands them, in measurable terms.
4. For each requirement, write the error, permission, concurrency, and recovery behavior.
5. Write acceptance criteria and map each to its requirement in both directions.
6. Record assumptions, contradictions, and anything declared out of scope.

## Worked example

Objective: let a user export their data.

`REQ-1`: When an authenticated user requests an export, the system produces a file containing only that user's data. Deciding observation: a test asserts the file holds exactly the requesting user's records and no other user's.

`REQ-2`: If the user has no data, the export still succeeds and the file is empty with a header row. This is the edge case that `REQ-1` leaves open.

`REQ-3`: An unauthenticated request is rejected and produces no file. Deciding observation: the response is an authorization failure and the storage location has no new object.

The phrase "exports should be fast" is not accepted as `REQ-4`. Recorded instead as an open question: what latency bound, measured on what data volume, would count as acceptable.

Conflict register: `REQ-1` says the user can export at will, while the retention policy says deleted data is unrecoverable. Resolution needed from the user — does export include soft-deleted records. The requirement does not guess.

Traceability: acceptance test `export_contains_only_own_records` maps to `REQ-1`; `export_empty_account` maps to `REQ-2`; `export_rejects_anonymous` maps to `REQ-3`.

## Failure signals

- Requirements describe implementation ("use a queue," "store as JSON") rather than behavior.
- Words such as fast, robust, intuitive, secure, or flexible survive without a measurement.
- Failure and permission behavior is absent, so only the happy path is specified.
- Two requirements contradict and the document picks a winner without saying so.
- A requirement has no acceptance criterion, or a criterion traces to no requirement.
- Optional behavior is written as mandatory without a user decision behind it.

## Evaluation scenario

Given a brief saying "add a secure, fast search," the result should decompose it into numbered requirements each paired with the observation that decides it, convert "secure" and "fast" into either measurable constraints or explicit open questions, include the empty-result and no-permission cases, and show a traceability mapping. It fails the method if the unmeasurable words pass through unchanged, or if any requirement lacks both an identifier and a deciding observation.

## Output

- Numbered requirements
- The deciding observation for each
- Non-functional constraints, measurably stated
- Edge and failure cases
- Traceability between requirements and acceptance criteria
- Assumptions, open questions, and conflict register

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
