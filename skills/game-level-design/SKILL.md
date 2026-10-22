---
name: game-level-design
description: Design playable spaces and challenge sequences using movement metrics, reachability, teaching order, and failure data. Use when creating or reviewing levels, rooms, encounters, waves, tracks, or difficulty ramps.
---

# Game Level Design

## 1. When to use / When not to use

Use for spatial layouts or ordered challenges that teach and test player abilities. The method applies to authored content and to acceptance criteria for generated content.

Do not use to implement a generator, configure engine collision, or operate an editor. Do not certify reachability without movement measurements or difficulty without defined playtest data. A paper layout can be reviewed for dependencies, but cannot prove that a physical jump works.

## 2. Novice orientation

A level arranges decisions in space or time. A blockout is a rough playable layout made with plain shapes; decoration comes after its routes and challenges work.

For a first session:

1. Draw an entrance, a goal, and a route on squared paper. Mark obstacles and any key needed to pass them.
2. Choose the action being taught. Put a safe practice opportunity before a mandatory challenge using it.
3. Move a token through the route and track acquired keys or abilities. If a gate requires something behind itself, repair the dependency.
4. In an available prototype, measure the actual movement needed by the layout. Record units and starting conditions. Without a prototype, leave physical dimensions provisional.
5. Build or request a plain-shape version through the project's implementation guidance. Observe a new player, mark confusion and failure locations, then change the layout before adding art.

First-session checklist: a route from entrance to goal, an explicit learning objective, a dependency walkthrough, and either measured movement dimensions or a visible list of missing measurements.

| Term | Meaning |
| --- | --- |
| Critical path | Actions or spaces required to reach the goal |
| Expected route | The route most players are intended to discover |
| Gate | A connection requiring a key, ability, or condition |
| Soft-lock | A reachable state from which intended progress is impossible without an unintended reset |
| Encounter | A bounded challenge with an entry condition and outcome |
| Difficulty curve | How demands change over the sequence of challenges |

## 3. Core method

### Establish metrics before layout

Record character dimensions, movement speed, acceleration and braking, jump distance and height, reach, camera visibility, and relevant enemy ranges. Tag the controller revision, input mode, surface, approach speed, landing elevation, and ability state. Re-measure after changes to movement or camera behavior.

For comparable running jumps, let `MAX_JUMP_DIST` be the measured horizontal reach under documented conditions. The referenced level-design source proposes:

- `SAFE_GAP = 0.70 × MAX_JUMP_DIST` for ordinary required crossings.
- `HARD_GAP = 0.95 × MAX_JUMP_DIST` for optional precision challenges.

These are source-authored starting heuristics, not guarantees. Define whether gap measures edge-to-edge clearance or character reference-point displacement, and use the same convention in measurement and layout. A gap above measured maximum reach is invalid for those conditions unless another available mechanic bridges it. Different elevations, moving surfaces, standing starts, collision margins, or input modes require separate measurements. A nominally safe gap still needs player testing.

### Block out, test, revise, then dress

Write each space's purpose: introduction, practice, variation, combination, pressure, recovery, or reward. Arrange these into an intentional arc. Build the complete required route with plain geometry or minimal challenge data; test it before spending on visual detail. Iterate on distances, sightlines, checkpoints, and encounter timing. Add art only after the route works, then test again because decoration can hide signals or alter collision expectations.

Represent progression as states containing location plus keys, abilities, and consumed resources. A room-only connectivity check misses a consumed key or irreversible drop. Explore reachable states to ensure required gates can be opened in order and optional routes do not trap the player. Declare intentional terminal failure and recovery separately from accidental soft-locks.

Before increasing execution pressure, verify that the player saw the mechanic, could practice it safely, and received legible feedback. Frame threats, destinations, and irreversible moves before commitment. Make retry distance and lost progress part of the difficulty budget.

### Use failure data with stable denominators

Define an attempt identifier and mutually exclusive outcomes: completed, failed, abandoned, or still active. Deduplicate events. Report starts and resolved outcomes separately; do not interpret a session disconnect as a gameplay death. Compute failures / starts for a closed observation window and disclose unresolved attempts. Compare first attempts separately from retries, and segment by input device, skill cohort, build, and assistance settings.

The following are recommendations from the casual web-game source, suitable only as calibration hypotheses for a comparable audience:

| Position | Source's proposed failure proportion |
| --- | --- |
| Opening level | Below 5% |
| Levels 2–3 | 5–15% |
| Levels 4–10 | 15–30% |
| Middle progression | 25–40% |
| Deliberate difficulty peak | Up to 50%, followed by relief |

Do not apply these as universal targets to hard action games, narrative games, or expert audiences. The same source suggests median 2–4 attempts before success for casual web games; exclude neither unsolved players nor abandoned runs silently when reporting that statistic.

Define quit-after-fail as the fraction of failed attempts followed by no retry or continuation within a declared observation window. Report that window and account for censored users who have not had time to return. A high failure rate with continued attempts suggests a different problem from low recorded failure with heavy abandonment. Neither establishes fairness without observation. Inspect the first unlearned mechanic, misleading cue, camera obstruction, or excessive retry cost before simply reducing enemy health.

Deliver a level beat table, movement metric sheet, route/gate model, playtest observations, difficulty table with counts, and a revision plan tied to specific causes.

## 4. Failure criteria and measurable invariants

- Every required traversal must be within measured ability limits for its actual starting and landing conditions. Missing measurements yield **not assessed: missing traversal data**, not a reachable verdict.
- Every reachable nonterminal progression state must retain a documented route to a goal or intended recovery. An inaccessible key, unintended irreversible trap, or resource dependency cycle fails the progression review.
- Each attempt has at most one terminal outcome. Duplicate or incompatible telemetry invalidates the affected rate until reconciled.
- No starts means the failure rate is undefined, not zero. Without counts, cohort, build, and observation window, refuse a measured difficulty verdict and supply the needed collection plan.
- Crossing a chosen failure target triggers investigation, not automatic proof that the level is unfair. Report uncertainty and unresolved attempts; never fabricate confidence from a tiny sample.
- Required mechanics introduced only under unavoidable lethal pressure fail a design that promises safe onboarding.

## 5. Platform/engine boundary

This skill specifies dimensions, progression dependencies, pacing, and tests. Scene editing, tile tools, navigation APIs, collision setup, camera implementation, telemetry SDKs, and platform preview commands remain in project-side skills or versioned documentation located through AGENTS.md, externalSkills, or roleBindings. Pass the metric sheet and acceptance cases to those instructions; no engine or platform operations are defined here.

## 6. Sources and verification status

Accessed 2026-10-23. Original method rewrite; no upstream implementation snippets or prose passages are incorporated.

- [Level design method](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/38a4c2500eeb5ff9ac084336b8f66108069d2f8d/skills/disciplines/level-design/SKILL.md): metrics before geometry, blockout iteration, progression dependencies, and 0.70/0.95 gap factors. Verified as recommendations, not validated physical guarantees.
- [Difficulty curve method](https://github.com/horn111/web-game-ad-skills/blob/6a482b9683b7082036337bf66ffeb973013500de/skills/level-design-difficulty-curve/SKILL.md): positional failure ranges and retry/abandonment interpretation. Verified source values; empirical validity for this project's audience remains unverified.
- License snapshots: [Apache-2.0](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/38a4c2500eeb5ff9ac084336b8f66108069d2f8d/LICENSE), with NOTICE present at this revision, and [MIT](https://github.com/horn111/web-game-ad-skills/blob/6a482b9683b7082036337bf66ffeb973013500de/LICENSE). verify-current-policy: revisit obligations if future reuse includes upstream text or code.

Event definitions and uncertainty controls are this package's method additions. No unsourced numeric difficulty threshold is presented as an industry fact.
