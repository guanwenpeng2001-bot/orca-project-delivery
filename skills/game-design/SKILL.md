---
name: game-design
description: Define and evaluate a game's core loop, choices, rules, feedback, and progression through playable hypotheses. Use when designing a game, specifying a gameplay feature, or diagnosing an unclear or unrewarding play loop.
---

# Game Design

## 1. When to use / When not to use

Use to turn a player experience into rules an implementer can build and a tester can falsify. Apply across genres; a narrative consequence can be as meaningful as a combat advantage.

Do not use as an engine implementation guide, a substitute for player research, or proof of commercial viability. Decline a final design verdict when the target player, intended experience, or observable prototype is missing. A provisional concept is still possible if its assumptions are explicit.

## 2. Novice orientation

Game design describes what a player can do, how the game responds, and why the next action is worth taking. Art and programming realize those decisions; they cannot decide whether the decisions are interesting.

For a first session, take paper, a token, and a pencil:

1. Write a player goal and an action in ordinary language, such as reaching an exit by choosing a safe or rewarding route.
2. Draw a start, a goal, and routes with different costs. State what information is visible before a choice.
3. Write the consequence of each action, the completion condition, and what happens after failure. Move the token according to those rules.
4. Have someone unfamiliar with the rules play while you record where they hesitate or need an explanation. If testing alone, label the result a rule walkthrough, not player validation.
5. Change the rule responsible for the clearest problem and repeat. Keep the before/after observations.

First-session checklist: a playable start-to-end path, an explicit failure or continuation rule, a visible consequence, and an observation that could contradict the intended experience. No engine or finished art is required.

| Term | Meaning |
| --- | --- |
| Core loop | The recurring sequence of decisions, consequences, and reasons to keep playing |
| Mechanic | A rule connecting an action or condition to a change in state |
| Feedback | Information that lets the player understand that change |
| Progression | How available actions, knowledge, stakes, or rewards evolve |
| Dominant choice | An option that removes the practical reason to choose alternatives |
| Prototype | The cheapest playable representation of a design question |

## 3. Core method

### Specify the experience before the feature list

Name the audience, input conditions, intended session pattern, player fantasy, and constraints. Express the design as a hypothesis: a particular decision should produce a particular observed response. Separate what the player must understand from what they may discover. Record what evidence would reject the hypothesis.

Describe the loop as observation, decision, action, state change, and feedback. Specify the state at entry, legal actions, information available, costs, resolution order, terminal conditions, and restart or continuation. For randomness, describe which outcomes are possible and how tests reproduce them. For story choices, record the later consequence rather than assuming a branch is meaningful because it exists.

### Use genre examples to derive common tests

| Design concern | Cross-genre examples | General criterion |
| --- | --- | --- |
| Rules resolve predictably | Card effects, puzzle cascades, turn schedules | The same state and controlled random input have an explainable outcome |
| Decisions have context | Shooter exposure, tower placement, narrative branches | A player can identify relevant information before committing |
| Feedback supports learning | Jump landing, hit confirmation, story reaction | A consequence can be associated with the action that caused it |
| Progress opens possibilities | RPG growth, crafting dependencies, run rewards | Advancement changes available decisions instead of only increasing numbers |
| Failure preserves the intended stakes | Puzzle undo, run death, checkpoint retry | The reset boundary is specified and matches what the player was told |
| Presentation preserves agency | Menus, targeting, dialogue choices | Supported inputs can reach and leave every required interaction |

Do not import a genre's entire feature checklist. A survival game may deliberately exhaust resources; a narrative game need not have combat or numeric victory. Preserve the criterion and decide the appropriate expression.

### Test decisions and pacing

Create a decision table containing state, alternatives, visible information, cost, benefit, and consequence. Compare options under different states and player goals; raw damage or currency alone is not a universal utility function. Investigate an option that wins under every modeled condition before adding more content.

Map the learning sequence: isolated introduction, safe practice, variation, combination, and mastery. Define where tension releases and where the next goal becomes legible. Test the smallest complete loop before adding progression layers. Separate comprehension failures from execution failures and from a player choosing to stop.

Define measurements before observation: loop completion time, unaided completion count / eligible attempts, decision distribution by state, and failures by cause. Report cohort, build, input device, sample size, and observation window. Set project targets before comparison; there is no universal retention or fun threshold.

Review the information path as part of the rules: readable objectives, distinguishable states without color alone, input focus, back/pause behavior, text scaling, and framing across supported displays. Verify actual navigation with each supported input rather than approving a screenshot.

Deliver a design specification containing the experience hypothesis, rules and state transitions, decision table, learning arc, prototype scope, observed results, and unresolved assumptions. Hand pricing questions to `game-economy-design`, spatial layout to `game-level-design`, and embodied movement to `game-3c-design`.

## 4. Failure criteria and measurable invariants

- Every required action has a defined precondition and observable result; every terminal state has a defined continuation or intentional end. Undefined transitions fail the specification review.
- For a deterministic rule test, replaying the same initial state, actions, and random sequence must reproduce the same logical outcome. Visual variation must not change the rules.
- Every required menu action must be reachable using each input mode claimed as supported; a focus trap or inaccessible exit fails that mode.
- A design claiming consequential choice must show a state or experience difference for the choices tested. Merely counting branches is insufficient.
- Without a playable prototype and recorded observations, mark enjoyment, comprehension, and difficulty conclusions **not assessed: missing playtest data**. Provide the proposed test and missing inputs; never invent player reactions or pass percentages.
- A successful rule walkthrough establishes internal consistency only. It does not establish audience fit, balance, retention, or accessibility for untested players.

## 5. Platform/engine boundary

This skill owns design intent and acceptance criteria. Engine scene construction, input APIs, UI widgets, persistence APIs, platform SDKs, build commands, and store operations belong to project-side skills and versioned documentation. Locate those through the project's AGENTS.md, externalSkills, or roleBindings. Hand off the rule specification and supported-device requirements; do not convert external repository commands into package instructions.

## 6. Sources and verification status

Accessed 2026-10-23. Original synthesis of methods, with no copied source files, code, or prose passages. Reading a source verifies what it recommends, not the effectiveness of that recommendation in this project.

- [Genre method collection](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/tree/38a4c2500eeb5ff9ac084336b8f66108069d2f8d/skills/genres): reviewed card-game, fps-shooter, platformer, puzzle, roguelike, rpg, survival-crafting, tower-defense, and visual-novel SKILL.md files. Verified source coverage; cross-genre criteria above are this package's synthesis.
- [UI method](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/38a4c2500eeb5ff9ac084336b8f66108069d2f8d/skills/disciplines/game-ui-ux/SKILL.md): input navigation, display adaptation, and state readability; engine examples excluded.
- [License snapshot](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/38a4c2500eeb5ff9ac084336b8f66108069d2f8d/LICENSE): Apache-2.0; repository NOTICE also exists at this revision. verify-current-policy: reassess attribution and license obligations if future work incorporates upstream expression or code.

Project playtest effectiveness is unverified until the specified experiments run. No genre-specific timing or commercial benchmark is asserted as universal.
