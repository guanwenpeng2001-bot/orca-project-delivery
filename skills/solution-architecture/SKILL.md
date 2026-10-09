---
name: solution-architecture
description: Design minimal software boundaries, responsibilities, interfaces, data flow, migration, rollback, and operational behavior for a scoped objective. Use for cross-module or high-risk changes.
---

# Solution Architecture

## Core principle

Design the smallest structure that solves the actual problem and fits the system that already exists. An abstraction earns its place by removing complexity, not by anticipating a future that may never arrive.

## Decision criteria

Judge a module boundary by the ratio of what it hides to what it exposes. A deep module conceals substantial complexity behind a small interface; a shallow one exposes nearly as much complexity as it contains. Prefer deepening an existing module over adding a new one.

Apply the deletion test to every proposed abstraction: if removing it would make the code easier to understand and change, it does not earn its place. Passing the test means the abstraction hides enough real complexity to be worth the indirection.

Distinguish a real seam from a speculative one. An interface with a single implementation is a hypothesis about future variation; it costs indirection now for flexibility that may never be used. Introduce the interface when a second implementation actually exists, or when the seam is a genuine boundary you must test across, such as an external service.

Classify each decision by reversibility. A reversible choice (an internal module split, a library behind your own interface) can be made cheaply and corrected later. A one-way choice (a public API, a stored data format, something external consumers bind to) deserves more analysis and an explicit record, because correcting it means migrating everyone else.

Record one-way decisions as a short decision record: the context, the choice, the alternatives considered, and the consequences. This is what lets a later reader understand why, instead of relitigating it.

Put the test surface at the interface. If a module can only be verified by exercising its internals, its boundary is drawn in the wrong place.

### When not to add structure

If the change fits an existing module's responsibility, put it there. A new service, process, or deployable unit carries operational cost — deployment, monitoring, failure modes, network latency — that is only justified when there is an independent scaling need, an isolation boundary, or a separate ownership reason. Splitting for neatness increases the surface area without reducing complexity. Default to the existing structure and write down the specific reason if you depart from it.

### Boundaries, ownership, and failure

Draw a boundary where the rate of change or the reason for change differs. Code that changes for one reason belongs together; code pulled in two directions belongs apart. The practical test is locality: a change requested for one reason should land mostly inside one module. If every change cuts across many modules, the boundaries are in the wrong place.

Assign ownership of state explicitly. One module owns a given piece of data and is the only writer; others ask it for what they need or are told when it changes. Shared writable access from several modules is how invariants get bypassed. The direction of dependency should point toward the stable core and away from volatile details, so a change in a detail does not ripple inward.

Design the failure behavior as part of the structure, not afterward. For each dependency, state what happens when it is slow or unavailable: retry, degrade, fail fast, or queue. An architecture diagram that shows only the happy path hides the paths that dominate operational cost. State the observability that makes failures diagnosable: what is logged or measured at each boundary so a failure can be localized without reproducing it.

### Migration and rollback

A design that changes stored data or a public contract needs a migration story and a rollback story that are different things. Rollback is possible only while the old and new forms can both be read. Once the old form is destroyed, the change is one-way and should be the last step, taken after the new path has been verified. Say which steps are reversible and which are not.

### What crosses each boundary

Specify every interface by the operation, its inputs and outputs, and the errors it reports. Say which side owns the data and whether the caller waits for the result or learns about it later. A direct call couples availability, so the caller fails when the callee is unavailable; handing work to a queue decouples them but makes the result eventual rather than immediate. Pick one per interface and record the consequence, instead of letting every interaction default to a synchronous call.

Keep call direction consistent with the dependency direction, so a lower module never reaches back into a higher one that depends on it.

## Workflow

1. Map the parts of the current system the change touches and the constraints they impose.
2. Assign responsibilities and decide where state lives and which direction dependencies point.
3. Define the interfaces, the failure behavior, and where security and observability boundaries fall.
4. Compare the realistic alternatives and say why the chosen one fits better now, not in theory.
5. Classify each decision as reversible or one-way, and write a decision record for the one-way ones.
6. Describe migration, compatibility, and rollback, and name how the design will be verified.

## Worked example

A service needs to send email, and the proposal is an interface with a provider-agnostic adapter hierarchy plus a message-builder framework.

The deletion test: the service sends one kind of message through one provider. The hierarchy and builder hide nothing yet, because there is no second provider and no second message shape. Removing them leaves a single function that calls the provider. So the abstraction fails the test and is not built.

What is worth designing: one module that owns templating and sending behind a single function, since that complexity (retries, error mapping, templating) is real and worth hiding. The provider's client is called directly inside it. The interface is introduced later, if a second provider arrives.

The one-way decision is the stored format of queued messages, which consumers and persisted jobs will bind to. It gets a decision record noting that a versioned schema was chosen so a format change can be migrated rather than breaking in-flight jobs. The internal module split is reversible and needs no record.

Verification sits at the module boundary: tests assert on the send function's behavior with a fake transport, not on the internals of templating.

## Failure signals

- A new abstraction has exactly one implementation and no current need for a second.
- The design introduces a framework, plugin system, or generic layer for a single use case.
- A one-way decision such as a public contract or stored format is made without recording why.
- The proposed structure ignores the patterns the codebase already uses.
- Rollback is "redeploy the old version" for a change that also migrates data.
- The design can only be tested through its private internals.

## Evaluation scenario

Given a proposal to add a plugin system so "any notifier can be added later," when only email is required today, the result should apply the deletion test, recommend the smaller design that hides the complexity which actually exists, identify which decisions are one-way and record those, and state where the design is tested. It fails the method if it accepts the plugin system on the basis of speculative future notifiers, or if it treats a reversible internal choice as needing the same weight as a stored data format.

## Output

- Context and constraints
- Component responsibilities and dependency direction
- Interfaces, data flow, and failure behavior
- Alternatives considered and the decision
- Reversibility classification and decision records
- Migration, rollback, and verification points

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
