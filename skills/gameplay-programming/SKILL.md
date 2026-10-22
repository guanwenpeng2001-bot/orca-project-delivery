---
name: gameplay-programming
description: Structure game rules, behavior decisions, action input, and versioned saves around testable simulation boundaries. Use when implementing gameplay, NPC decisions, responsive controls, or save migration.
---

# Gameplay Programming

## 1. When to use / When not to use

Use for a playable rule, an actor's decision logic, device-independent controls, or persistent progress. Start from an agreed player action and observable result.

Do not use this method to invent missing game design, select an engine API, or diagnose a GPU bottleneck. If the desired rule is undecided, obtain that decision before implementing its consequences. Network authority belongs with game-multiplayer; collision stability belongs with game-physics.

## 2. Novice orientation

Gameplay code turns a player's intention into a change in the game world. A simulation is the data and rules that produce that change; presentation shows it through pictures and sound.

For a first session, choose one rule: a character may jump once while grounded. Write down its starting state, the Jump action, and the expected airborne state. Use the project's existing run/test instructions to observe it with a placeholder character. Add a case where Jump is refused in midair, then reload the game and check the progress that should persist. Do not add an inventory, AI framework, or persistence framework just to demonstrate this rule.

First-session checklist:

- Identify the state owner and the place where rules advance.
- Name one action and its success and refusal conditions.
- Record a repeatable input sequence and its expected result.
- Identify which fields survive restart and which are temporary.

Terms: an **action** is an intention such as Jump, independent of a button; a **tick** is one simulation step; a **state machine** is named modes with allowed transitions; a **behavior tree** arranges conditional tasks by priority; **utility scoring** compares graded preferences; a **schema** describes saved fields and their meaning.

## 3. Core method

### Make the rule observable

Describe each rule as initial state, command, allowed transition, emitted event, and rejected transition. Keep simulation state separate from animations and sound. Inject time and randomness where repeatable tests need them; distinguish the simulation clock from real elapsed time during pause. Assign one owner to each changing field so two update loops cannot both move the actor.

### Choose the smallest decision structure

| Situation | Starting structure | Cost to examine |
| --- | --- | --- |
| A few exclusive modes with explicit transitions | State machine | Transition count and unreachable states |
| Prioritized tasks that can be interrupted | Behavior tree | Cancellation and resuming unfinished tasks |
| Several valid choices whose desirability varies | Utility scoring | Normalization, ties, and rapid switching |

Use a hybrid only when both sequencing and graded choice are needed. For a tree, define whether conditions are reevaluated while a task runs, and how an interrupted task releases reservations. For utility scoring, give comparable inputs a documented scale and use a deliberate tie rule or switching margin. Trace the facts and selected action at each decision point; a correct-looking animation does not explain a decision.

### Treat input as commands

Map device signals to stable action names outside gameplay. Distinguish a press edge from a held value. Capture short presses between simulation ticks and consume each edge once; do not make a render callback the owner of gameplay state. Handle rebinding conflicts and preserve an accessible route to the menu. Filter analog drift and verify diagonals, device changes, and prompts on supported devices.

For jumping, keep separate timestamps for the last eligible grounded state and the latest unconsumed press. **Coyote time** permits a jump briefly after walking off a ledge; **jump buffering** retains an early press until landing makes it legal. Choose both windows from playtests, in time units rather than render frames. On a successful jump, consume the press and the ground grace eligibility so one press cannot launch twice. Explicitly define pause behavior and the difference between walking off a ledge and an already-consumed jump.

### Evolve saves as a data contract

Save durable values and stable content IDs, not live scene references. Include a schema version; separate content/generator versions when they affect reconstruction. Read and validate the version before applying state. Migrate supported older versions through explicit transformations, validate the result, and reject unsupported newer versions without overwriting the original.

Keep fixtures for each supported schema and preserve the last recoverable save during replacement. Storage durability and atomic replacement depend on the project platform; verify interruption behavior there rather than promising that a rename is universally safe. Define how simultaneous saves are serialized and how missing or retired content IDs are handled. Prove save/load with a full restart, not only an in-memory round trip.

## 4. Failure criteria and measurable invariants

- One captured press produces at most one successful discrete action, including when several simulation ticks occur in one render frame.
- At the chosen buffer and grace boundaries, tests immediately inside and outside each window match the declared rule; an ordinary jump cannot obtain a second grace jump.
- Every interrupted decision task releases its owned reservation, and a repeated input trace produces the declared state transitions under the tested clock and randomness configuration.
- Every supported save fixture migrates and preserves its declared progress fields; unsupported versions leave the original bytes intact. A restart restores the expected stable IDs.

If the action contract, timing windows, or supported save versions are absent, report the missing inputs and limit the work to defining them. Without a replay, device run, or save fixture, mark the corresponding behavior **not assessed**; do not claim responsiveness, determinism, or migration safety from inspection alone.

## 5. Platform/engine boundary

Project-side AGENTS.md, externalSkills, and roleBindings own the selected engine input adapter, update callbacks, scene serialization, storage operations, and device tooling. Refer to the project's version-matched engine documentation for those implementations. This method defines their behavioral contracts, not their API calls. Product design owns action meaning; the implementation owner owns state transitions and migration compatibility.

## 6. Sources and verification status

Method concepts were consulted on 2026-10-23 at gamedev-skills/awesome-gamedev-agent-skills commit `38a4c2500eeb5ff9ac084336b8f66108069d2f8d` (Apache-2.0):

- [Behavior decisions](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/38a4c2500eeb5ff9ac084336b8f66108069d2f8d/skills/disciplines/ai-behavior-trees-utility-ai/SKILL.md): priority trees, graded choice, interruption and switching concerns.
- [Input systems](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/38a4c2500eeb5ff9ac084336b8f66108069d2f8d/skills/disciplines/input-systems/SKILL.md): action abstraction, press capture, buffering and grace windows.
- [Save systems](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/38a4c2500eeb5ff9ac084336b8f66108069d2f8d/skills/disciplines/save-systems/SKILL.md): plain-data persistence and schema migration.

Verified: those concepts appear in the pinned source. The method and examples here are independently worded; no upstream code or text is reproduced. Project-specific timing, storage guarantees, and gameplay outcomes are unverified until exercised. Before applying, verify-current-policy: confirm supported devices, current storage restrictions, engine version, and save compatibility policy against project-owned documentation.
