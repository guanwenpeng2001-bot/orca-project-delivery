---
name: game-multiplayer
description: Choose multiplayer authority and synchronization models with testable simulation, latency, and recovery contracts. Use when designing state replication, input synchronization, prediction, rollback, or lag compensation.
---

# Game Multiplayer

## 1. When to use / When not to use

Use before coupling gameplay to a network transport, when choosing a synchronization model, or when diagnosing divergent state, delayed actions, repeated effects, and recovery failures.

Do not use this skill as an engine networking API reference, matchmaking-service setup guide, or authorization to change a shared backend. Do not select an architecture until player count, interaction style, trust model, supported devices, and latency expectations are known. Where inputs are missing, develop an offline experiment and state the undecided constraint.

## 2. Novice orientation

Multiplayer clients see different information at different times. The design must decide who can declare a result and how others learn it. A smooth local view does not mean that every participant agrees on the world.

For a first session, choose one interaction: two players compete to collect one item. Write the rule that only one player receives it and identify who decides. Run the rule in a local simulation with two command streams and no real network. Feed delayed, duplicated, and reordered commands through a test adapter. Confirm one award, then replace the adapter with project-owned networking only after the rule is understood.

First-session checklist:

- Name the owner of the final item state and the commands each player may send.
- Record the initial state, command order, and resulting award.
- Choose explicit delay/loss test conditions from the intended audience's network needs.
- State what a disconnected player sees and what state they receive on return.

Terms: **authority** decides accepted state; **state synchronization** sends world results; **input synchronization** sends commands for peers to simulate; **prediction** responds locally before confirmation; **reconciliation** corrects a predicted result; **rollback** restores an earlier state and resimulates; **lockstep** advances only when required inputs are available; **lag compensation** evaluates an action against a bounded historical view.

## 3. Core method

### Separate authority from synchronization

Write an authority map for movement, damage, inventory, score, and persistent progress. A trusted server can validate commands while clients predict movement; rollback is a time-management technique, not a declaration that clients are trustworthy. Peer ownership may be acceptable in a trusted session but is not an anti-cheat guarantee.

| Candidate | Suitable starting conditions | Cost or failure to prove |
| --- | --- | --- |
| Authoritative server with replicated state | Untrusted clients and centrally validated outcomes | Hosting cost, correction behavior, bandwidth, server failure |
| Deterministic input lockstep | Compact commands and reproducible simulation | Slowest-input delay, cross-platform divergence, dropouts |
| Input prediction with rollback/resimulation | Immediate response matters and state can be restored cheaply | Replay CPU/memory, correction artifacts, duplicate effects |

These can be combined. Select both an authority model and a synchronization strategy, explain the rejected alternatives, and prototype the expensive assumption before committing the game to it. Lockstep and rollback require controlled simulation behavior; a fixed timestep or shared seed alone does not establish determinism.

### Build an offline simulation seam

Make the world advance from explicit state, tick-indexed commands, and controlled randomness. Keep transport, wall-clock reads, rendering, and irreversible external effects outside this transition. Capture and restore all state needed for replay, including timers, random state, and relevant spawned entities. Specify ordering when commands share a tick.

Replay the same initial state and commands across supported execution environments, comparing canonical state at agreed ticks. Local replay establishes only local repeatability. For rollback, buffer history for the chosen correction horizon and emit effects with stable event identities so resimulation cannot award currency or play an effect repeatedly. Confirm irreversible consequences through the authority boundary.

### Specify synchronization and correction

For state synchronization, define entity identity, spawn/despawn, snapshot ordering, baseline recovery, and how a client discards obsolete data. Smooth remote presentation separately from authoritative state. For local prediction, track the last acknowledged command, restore confirmed state when needed, and replay outstanding commands under the declared model.

For input synchronization, define tick numbering, input availability deadlines, late-input handling, and behavior when history has expired. Do not silently substitute missing input without an explicit prediction/default policy. Budget update frequency, payload size, recipient count, and transport overhead from measured workloads; there is no universal tick rate or latency window.

Validate commands at the authority: identity, allowed ownership, sequence, legal action rate, and game-rule bounds. Transport authentication does not make a requested move or reward valid. Establish protocol/content compatibility before joining a session.

### Bound latency compensation and recovery

For historical hit evaluation, define the server-side time mapping, retained history, maximum rewind, and fairness rule. Validate client timestamps against server knowledge and clamp to the permitted history rather than trusting arbitrary past times. Test moving targets, cover transitions, and targets that no longer exist. Historical evaluation should not leave the live world rewound.

Exercise delay, jitter, loss, duplication, and reordering with a local transport adapter, then verify on the actual transport and devices. Record authority state and each client's correction. Specify reconnect resynchronization, late join, and host/server loss; if host migration is unsupported, state the session-ending behavior explicitly instead of implying seamless recovery.

## 4. Failure criteria and measurable invariants

- The contested item produces exactly one authoritative award despite duplicate or reordered requests.
- A client cannot change another player's owned state or grant itself an authoritative reward through an invalid command.
- For input-synchronized simulation, replayed canonical state agrees at each checked tick across the supported test environments; any divergence blocks a determinism claim.
- Within the declared network envelope, corrections converge within the project-selected time and position tolerances; expired history follows the documented recovery path.
- Historical evaluation never exceeds the configured rewind bound, and replay emits each externally committed event at most once.
- Reconnection restores a compatible authoritative snapshot or refuses clearly, without merging stale local authority into shared progress.

Without an authority map, network envelope, simulation trace, and measured synchronization outcomes, report **not assessed** for fairness, responsiveness, or network readiness. Offline tests verify rule and fault-handling seams only; they do not establish real transport compatibility, service capacity, or security of a deployment.

## 5. Platform/engine boundary

Project-side AGENTS.md, externalSkills, and roleBindings own transport APIs, authentication integration, engine replication facilities, hosting, matchmaking, device networking, and operational deployment. The gameplay owner defines authoritative rules; the implementation owner defines protocol and simulation contracts; the service owner controls infrastructure and capacity. Refer to version-matched project/engine guidance for concrete operations, with shared-system changes subject to project authorization.

## 6. Sources and verification status

Original method authored for this package on 2026-10-23. No suitable engine-neutral upstream method source was established for this assignment, and no external multiplayer source or implementation is claimed as provenance. The architecture comparison and acceptance procedures are engineering recommendations requiring project-specific verification, not measured findings.

Verification status: offline and network experiments have not been run for this document. Architecture fit, deterministic replay, correction cost, fairness, and service behavior remain unverified until the stated tests are performed. No numerical network defaults are prescribed. Verify-current-policy before application: consult the project's pinned engine/network documentation, supported protocol versions, service restrictions, authentication requirements, and authority/recovery policy; record their URLs, versions, and consultation dates in the project decision.
