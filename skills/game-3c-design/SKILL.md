---
name: game-3c-design
description: Co-design Character, Controller, and Camera behavior as a measurable perception-and-action system. Use when specifying movement, aiming, traversal, animation response, camera transitions, or diagnosing inconsistent game feel.
---

# Game 3C Design

## 1. When to use / When not to use

Use when the player's embodied actions depend on movement, presentation, and viewpoint working together. Character means abilities and their visible expression; Controller means how intent becomes motion or actions; Camera means what the player can perceive and how the view moves.

Do not treat these as independent tuning lists. Do not use this skill for engine API implementation, animation asset production, or medical claims about motion comfort. For a game without embodied movement, evaluate whether 3C is relevant before prescribing it. Without an executable movement prototype, produce a proposed contract rather than a validated feel verdict.

## 2. Novice orientation

Pressing forward is only the beginning of an action. The controller decides direction and acceleration, the character shows movement, and the camera determines whether the player can see where they are going. Changing any of these can change the meaning of the same input.

For a first session:

1. On paper, draw a character, a destination, and the camera's viewing direction. Write what forward means: toward the screen's top, the character's facing, or a fixed world direction.
2. Describe starting, stopping, turning, and reaching the destination. State what the player should see during each action.
3. Using an existing plain movement prototype, perform those actions in open space and beside an obstruction. Record input, visible response, overshoot, and loss of sight. If no prototype exists, hand this exercise to implementation and mark measurements unavailable.
4. Repeat while turning the view and while keeping it fixed. Note whether the intended direction changes without the player's intention changing.
5. Adjust a coupled hypothesis, such as reducing view rotation during a precision landing, then replay the same route. Do not judge success from a stationary screenshot.

First-session checklist: a declared direction convention, start/stop/turn observations, an obstruction case, a camera-motion comparison, and recorded unknowns.

| Term | Meaning |
| --- | --- |
| Reference frame | The axes used to interpret a directional input |
| Acceleration curve | How speed changes over time after input |
| Dead zone | Input or screen region that does not yet trigger a response; specify which kind |
| Animation blend | Transition between visible poses or motion cycles |
| Root motion | Character displacement authored in animation |
| Occlusion | An object hiding the character or a decision-relevant target |
| Camera curvature | How sharply a moving camera path changes direction, distinct from view rotation |

## 3. Core method

### Write one shared behavioral contract

For every movement mode, specify input frame, maximum speed, acceleration/deceleration profile, facing policy, ability and cancellation rules, animation driver, view framing, and transition conditions. Include grounded, airborne, aiming, locked-target, constrained-space, and recovery modes only when they exist in the game.

Assign displacement authority explicitly. If animation supplies root motion in a mode, decide how collision and player steering constrain it; if the controller supplies motion, animation must describe the resulting motion rather than silently replace it. Define which frame is used when the camera changes during held input and how the transition avoids an unexpected reversal.

| Change | Coupled question | Required observation |
| --- | --- | --- |
| Faster acceleration | Does the animation reach its moving pose soon enough, and does framing expose the destination? | Speed, pose, and visible travel space on the same timeline |
| Tighter camera path bend | Does apparent movement change faster than the player can interpret or correct? | Screen-space direction and correction attempts during the bend |
| Longer stopping distance | Do the stop animation and visible free space correctly communicate commitment? | Release-to-stop trajectory and landing error |
| Target lock transition | Does movement keep its declared meaning when the camera rotates? | Held-input direction before, during, and after the transition |
| Reduced-motion setting | Are threats still readable with less camera motion? | Same challenge under both presentation settings |

### Derive motion and animation together

Choose observable outcomes such as stopping within a landing zone or reaching a selected speed at a specified point. Measure velocity over time before adjusting animation thresholds. For a constant positive acceleration magnitude `a`, time from rest to speed `v` is `v/a`; for constant braking magnitude `b`, stopping distance from speed `v` is `v²/(2b)`. These are kinematic identities under their stated assumptions. Integrate the actual curve when acceleration is nonlinear or collision interrupts motion.

Use measured speed, direction, acceleration, and contact state to place blend boundaries. Distinguish requested input from actual movement: pushing into a wall should not imply unrestricted forward travel. Define separate enter and exit thresholds where noisy measurements would otherwise oscillate between poses. Derive that separation from recorded noise and the desired response, not an unexplained constant.

When acceleration changes, rerun the speed-to-pose mapping and inspect foot sliding, stop anticipation, turning, and landing transitions. Tune playback or motion policy only after establishing which system owns displacement. A visually smooth blend that hides late input response does not repair control latency.

### Design camera motion around readable control

Specify both camera position and view orientation. For a smooth camera path with curvature `kappa` and speed `v_camera`, path-heading change rate is `kappa × v_camera`; this describes the path tangent, not necessarily the view's yaw. A camera can travel straight while rotating rapidly, or move around an arc while looking at a fixed target. Measure both path changes and view angular velocity.

Camera curvature constrains controller readability through the resulting projection: a bend, orbit, or changing perspective can alter the apparent direction and speed of an unchanged world trajectory. In a camera-relative controller, rotation may also change the intended world direction itself. Test a held input across these transitions, record the projected trajectory, and define whether direction is continuously remapped, preserved until release, or blended according to the mode contract.

For an approaching hazard, compare visible travel distance with stopping and decision distance. Under a constant-speed reaction approximation, a proposed visibility budget is `v × reaction_time + braking_distance + project_margin`. Reaction time and margin must come from the target audience and task; they are not universal constants. If the camera cannot reveal that distance, change framing, speed, hazard placement, or the action contract together.

Inspect obstructions, narrow spaces, elevation changes, loss of target, respawn, and mode transitions. Decide what remains visible and how the camera recovers after each obstruction. Make comfort options part of the test matrix, with player-reported discomfort recorded directly rather than inferred from smooth motion.

### Run controlled comparisons

Use the same route, starting state, movement revision, and input conditions to compare a baseline with a proposed change. Measure input-to-visible-response delay, stopping error, directional error in a declared frame, target visibility duration, unintended reversals, and animation/contact mismatch. Record time units, capture method, frame cadence, device, and player feedback.

Choose project tolerances before judging a result and repeat at the supported frame rates and input modes. A change is accepted only when the coupled task improves without violating another declared behavior. Report tradeoffs rather than collapsing comfort, accuracy, responsiveness, and visual quality into an unsupported score.

Deliver the mode contract, direction/authority rules, movement curves, animation threshold rationale, camera visibility requirements, test matrix, measurements, and unresolved hypotheses.

## 4. Failure criteria and measurable invariants

- Every movement mode has a declared displacement authority and input reference frame. Conflicting authorities or an undefined frame transition fail the contract.
- With the same movement state and input, a camera transition must follow the declared direction policy. Any unexplained direction reversal is a failed case, even if the animation looks smooth.
- Measured stopping error, response delay, target visibility, and pose mismatch must satisfy the project's predeclared tolerances. Missing tolerances mean the measurements can be reported but a pass verdict cannot.
- Where collision prevents translation, the presentation must match the declared blocked-motion behavior. Unrestricted locomotion animation without intended explanation is a contract violation.
- Without synchronized motion/view observations, input details, and test conditions, report **not assessed: missing 3C evidence**. Do not infer latency, comfort, or playability from a video with unknown timing or from an isolated screenshot.
- A route tested by its author does not establish novice readability or comfort. Missing audience observations remain an explicit validation gap.

## 5. Platform/engine boundary

This skill owns the coupled behavior specification and measurement plan. Input sampling APIs, character movement components, animation graph operations, root-motion integration, camera collision APIs, engine units, SDK capabilities, and profiling commands belong to project-side skills and versioned documentation referenced through AGENTS.md, externalSkills, or roleBindings. Pass contracts and measurement requirements to those instructions; engine operations are not embedded here.

## 6. Sources and verification status

Authored from scratch on 2026-10-23. No external repository, camera skill, controller snippet, or character-animation text was used as a source for this method. The coupled design procedure is an original proposal requiring independent review and project playtests; its effectiveness is unverified.

The constant-acceleration, constant-braking, and path-curvature equations are mathematical relationships with their assumptions stated above, not empirical game-feel benchmarks. No numerical comfort, latency, or blend threshold is claimed as industry standard. Supply measured project values instead of inventing an industry-common range.

verify-current-policy: engine-specific behavior and input/platform restrictions must be checked in current project-side documentation when implementing the contract. No platform policy has been verified by this method-only skill.
