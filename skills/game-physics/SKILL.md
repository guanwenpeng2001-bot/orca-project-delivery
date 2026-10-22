---
name: game-physics
description: Diagnose unstable motion through simulation timing, interpolation, collision coverage, and contact budgets. Use when game objects jitter, tunnel, bounce unpredictably, or behave differently across render rates.
---

# Game Physics

## 1. When to use / When not to use

Use for motion that changes with frame rate, visible jitter, missed collisions, unstable resting contacts, or collision filtering mistakes.

Do not use physics tuning to decide when a jump is allowed, redesign camera feel, or select engine components. Those concerns belong to gameplay-programming, game-3c-design, and project-side engine guidance respectively. Do not change global physics settings without identifying affected scenes and their acceptance cases.

## 2. Novice orientation

Physics advances positions and contacts in discrete time steps. Rendering displays those positions on a separate schedule. A collider is the shape used for contact tests, which may differ from the visible art.

For a first session, use an existing project test scene or a small scene containing a floor and one falling body. Record its drop height and landing behavior, then repeat at a lower and a higher render rate while keeping the simulation rate unchanged. Add a small fast body and a thin wall to expose missed contacts. Use project-owned instructions to run and instrument the scene.

First-session checklist:

- Record distance units, simulation frequency, render-rate settings, and body motion ownership.
- Observe whether the simulated position jitters or only the displayed image does.
- Write expected contacts for the floor and wall cases.
- Agree a position tolerance and a maximum resting drift for the test duration.

Terms: **fixed timestep** means equal simulated time per update; **interpolation** blends completed states for display; **CCD** means continuous collision detection along motion; **tunneling** is crossing an obstacle without contact; **solver** means the numerical process resolving contacts; **collision layers** classify which objects may interact.

## 3. Core method

### Establish timing before geometry

Treat mismatch between a fixed simulation cadence and a variable render cadence as the first diagnosis for apparently bad physics. The upstream method identifies this as a frequent root cause, not proof that every bad contact is a clock defect.

Follow a fixed-frequency-before-collider ordering rule: inspect and stabilize simulation stepping and motion ownership before changing collider geometry. Choose a simulation frequency that meets movement and CPU needs, then measure actual steps under load. Forces, velocity changes, and collision-dependent state must use the simulation clock. A second writer moving the same body during rendering can defeat an otherwise correct solver.

Record the catch-up policy after a stall: bounded extra steps, accumulated delay, or deliberate time loss. Do not hide that tradeoff by feeding a huge variable step into a supposedly fixed simulation. A fixed timestep improves repeatability but does not establish identical results across processors or physics implementations.

### Separate display smoothness from simulation correctness

Inspect consecutive simulation transforms independently of the displayed transform. Interpolate between completed states for presentation using the remaining fraction of a simulation step; acknowledge the display latency this introduces. Keep interpolation out of collision state, and reset its history after a teleport or respawn. If the simulation is stable but the camera samples a different timeline, align presentation ownership before tuning contacts.

### Diagnose contacts with the smallest reproduction

Estimate motion per step as `distance = speed / simulation_frequency`. Compare it with relevant obstacle thickness and body dimensions to identify tunneling risk; this is a screening calculation, not a guarantee of collision coverage, especially for rotation and moving targets. Reproduce the failing path, then choose supported swept detection/CCD, substeps, or a design-approved speed/geometry change. Measure the cost and retest grazing angles and relative motion. Apply expensive detection to the bodies that need it.

For resting jitter, inspect initial penetration, object scale, mass ratios, friction/restitution, joint constraints, and solver effort one change at a time. Gravity is acceleration: increasing mass alone is not a general way to make an object fall faster. For unwanted or missing interactions, enumerate a named pairwise collision matrix, including triggers and queries; mask combination semantics are engine-specific.

### Close with a repeatable stress case

Repeat the drop, fast-wall, stack, and moving-contact cases at the chosen low/high render rates and under a controlled stall. Compare trajectories and contact outcomes within declared tolerances. Record simulation cost as well as visible improvement so a stability change does not silently exhaust the frame budget.

## 4. Failure criteria and measurable invariants

- At equal simulated time, the drop trajectory across tested render rates differs by no more than the project-declared position tolerance.
- Every expected blocking collision in the fast-wall test is observed; there are zero missed contacts within the declared speed, size, and angle envelope.
- A settled stack stays within the agreed drift distance over the recorded observation interval.
- Each tested collision pair matches the declared interaction matrix; a teleport does not visually sweep through an obsolete interpolation history.
- Measured physics time stays within the selected subsystem budget after tuning.

Without the simulation frequency, a reproducible failing scene, and measured tolerances, decline a stability verdict. Report **not assessed** for untested rates, platforms, and contact cases. A smooth video alone cannot establish correct contact detection or deterministic simulation.

## 5. Platform/engine boundary

The project's AGENTS.md, externalSkills, and roleBindings own body types, physics callbacks, interpolation facilities, CCD modes, layer semantics, and profiler instructions for the installed engine version. Engine documentation is authoritative for supported shape combinations and solver behavior. The implementation owner chooses settings within the agreed movement and performance contract; this skill supplies diagnosis order and tests, not engine operations.

## 6. Sources and verification status

Consulted on 2026-10-23: [Physics tuning](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/38a4c2500eeb5ff9ac084336b8f66108069d2f8d/skills/disciplines/physics-tuning/SKILL.md), gamedev-skills/awesome-gamedev-agent-skills, commit `38a4c2500eeb5ff9ac084336b8f66108069d2f8d`, Apache-2.0. Timing diagnosis, interpolation, tunneling, contact tuning, and collision filtering are method concepts verified in that source and rewritten here without copied prose or code. The ordering rule and tolerance-based acceptance procedure are this package's synthesis.

No engine experiment was run to validate this skill's effectiveness. Engine-specific detection guarantees, cross-device repeatability, and usable frequency are unverified until tested in the project. Verify-current-policy before application: confirm current engine physics documentation, supported CCD combinations, target performance constraints, and the project's authority to change global settings.
