---
name: domain-modeling
description: Assign entities, value objects, aggregates, and invariants to a bounded context before choosing storage. Use when the domain language is unsettled and no schema change is in scope yet.
---

# Domain Modeling

## Core principle

Put each fact in the one concept that owns it, and make invalid combinations unrepresentable. A model that relies on callers to remember the rules will be bypassed by the next caller.

## Decision criteria

Classify every noun from the domain language before drawing a box:

| Kind | Test | Lives |
| --- | --- | --- |
| Entity | Two instances with the same attributes are still different things | Inside exactly one aggregate, addressed by identity |
| Value object | Two instances with the same attributes are interchangeable, and replacing them is the only change | Inside the entity that uses it |
| Aggregate | A cluster that must change together to keep one invariant true | The consistency boundary and the only write entry |
| Domain event | A fact that already happened and other contexts may react to | Named in past tense, owned by the aggregate that recorded it |

An invariant belongs to the smallest concept that has every fact the rule needs. If a rule needs facts from two aggregates, either the split is wrong or the rule is eventual and must say so. A rule that is checked "wherever convenient" has no owner.

Use the domain's words in code. `Reservation` stays `Reservation` when the business says reservation; renaming it `BookingRecord` for symmetry creates a second language that drifts.

### Where this stops

`database-design` owns tables, constraints, indexes, and migrations once the store exists. This method stops at the concepts and the invariants those constraints will later enforce. `solution-architecture` owns module and service boundaries; an aggregate is not a service, and one service may hold several aggregates.

Do not invent an aggregate per entity. An aggregate earns its boundary by naming an invariant that would be violated if its members were saved separately. No such invariant means the extra boundary is ceremony.

Identity comes from the domain, not from the database. A surrogate key can support storage later; it does not decide whether two reservations are the same reservation.

## Workflow

1. Collect the terms the business actually uses, and write down the synonyms to retire.
2. List the facts that must always be true, as sentences with subjects.
3. Assign each sentence to the smallest concept that holds its facts.
4. Group concepts into aggregates only where one transaction must protect the invariant.
5. Name what other contexts may learn, as events, and what they may not reach in and change.
6. Walk the worked cases below and confirm each rejected model violates a named invariant.

## Worked example

A desk takes reservations for a room. The business rules are: a room has one reservation per night, a reservation covers contiguous nights, and a quoted price is money with a currency.

Rejected model: `Reservation`, `Night`, and `Price` are three independently saved entities. `Night` points at `Reservation` and at `Room`. Nothing stops two reservations writing the same room-night, because no single save owns that fact.

Accepted model:

| Concept | Kind | Owner of |
| --- | --- | --- |
| `RoomStay` | Aggregate | The room and the nights it holds |
| `Reservation` | Entity inside `RoomStay` | Guest, contiguous date range, identity |
| `DateRange` | Value object | Contiguity: start before end, no gaps |
| `Money` | Value object | Amount and currency stay together |
| `StayReserved` | Event | The room id, the date range, the reservation id |

The invariant "one reservation per room per night" sits on `RoomStay`, which is why the nights are not saved on their own. `Money` has no identity: 90 USD equals 90 USD. Persistence of `RoomStay` is a later decision for `database-design`, which can enforce the same invariant with a constraint; this model only decides who owns it.

A second context that bills the stay consumes `StayReserved`. It does not reach into `RoomStay` to mark a night paid.

## Failure signals

- Every table or class is declared an aggregate with no invariant named.
- A rule such as uniqueness is documented as "the service checks" with no owning concept.
- The same term means two different things in two contexts and both are called by one name.
- Value objects grow identity and start being updated in place.
- The model proposes columns, indexes, or migration steps.
- An event is named as a command (`ReserveStay`) rather than a fact (`StayReserved`).

## Evaluation scenario

Given a room reserved per night with a price that includes currency, the result should name one aggregate owning the room-night invariant, model the date range and the money as value objects, and leave storage to `database-design`. It fails the method if each night is its own independently saved entity, or if the answer includes a migration.

## Output

- Glossary with retired synonyms
- Invariants as sentences, each with an owning concept
- Aggregates and the reason each boundary exists
- Events published, and what other contexts must not modify
- Decisions explicitly deferred to storage or service design

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. It does not design a schema, choose a database, or split services. Product direction, scope, and irreversible choices stay with the user.
