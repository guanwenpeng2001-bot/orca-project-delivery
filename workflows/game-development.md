# Game Development Workflow

## Goal

Turn a game or gameplay-feature objective into designed, independently reviewed, integrated, and verified changes. Use [Feature Development](feature-development.md) as the base contract for isolation, rolling dispatch, review, integration, re-entry and closure.

## Entry contract

Record objective, players and problem, scope and non-goals, acceptance criteria, delivery branch, user-pinned Agent/model choices and external side-effect approvals.

## Adaptive stages

Keep the global stage chain: intake, reconnaissance, design, planning, task-graph, implementation, review, final-verification. Reuse `routing/workflow-selection.json` adaptiveDepth unchanged. Game design is mandatory: a game-development objective at light depth upgrades to standard, because the game-development design trigger requires design before planning. Integration remains the coordinator's responsibility after independent review.

### Intake

Probe only missing facts that can change direction:

- Target platforms and distribution surfaces, including minimum devices.
- Engine and version, or explicit engine-selection-needed.
- Genre and core player activity.
- Monetization: IAA, IAP, both, or explicit none. Unset is not none.
- User familiarity: novice or veteran.

These answers select the Task's Skill subset and exact chapters in its brief. Novices start with chapter 2 (beginner orientation) before the relevant method; veterans start with method and failure criteria (chapters 3–4 for non-engine Skills, chapters 5 and 8 for engine Skills). Both still receive platform boundaries and current-policy checks. Do not load every game Skill by default.

Use `game-design` for core decisions; add economy/monetization methods for IAA or IAP, `game-level-design` for spatial or challenge progression, and `game-3c-design` for action genres. Select one suitable `engine-*` method after target/engine reconnaissance. Add physics, multiplayer, content, performance, audio or build methods only when that Task needs them. Platform SDK/API/CLI operations remain in project-side `AGENTS.md`, externalSkills and roleBindings.

### Reconnaissance

Dispatch isolated scouts in parallel for independent unknowns: existing gameplay and saves, platform/engine fit, licensing and policy, assets and rights, device budgets, test/build entry points. If engine selection is needed, compare target support, project constraints and license snapshots before selecting the implementation path. Record unknown policy or tool support as unverified.

### Design

Record `stageDecisions.design` as required with the game-development trigger and dispatch `game-designer` before planning. Product ambiguity may first require `requirements-analyst`.

- Always produce `game-design-spec`: core loop, decisions, win/loss conditions, pacing, feedback and observable acceptance.
- Produce `game-economy-spec` whenever IAA or IAP is selected; include sources/sinks/stocks, rewards, purchase constraints and balance hypotheses. Explicit none does not waive economy design when the game itself has currencies or progression costs.
- Produce `game-level-spec` for levels or challenge sequences; record a reason when the objective has neither.
- Produce `game-3c-spec` for action genres, coupling Character, Controller and Camera.
- Produce `monetization-design` for selected IAA/IAP paths, dependent on the economy model.

Design outputs identify interfaces, data ownership, integration points, save/content compatibility, recovery and verification. Missing playtest data leaves hypotheses unverified. These outputs are planning and task-graph inputs; discoveries reopen design before dependent implementation.

### Planning

Use one plan for a bounded solution; use independent Solution Planners and adjudication for material alternatives or high risk. Include gameplay acceptance, asset consumption contracts, economy integration, target-device budgets and release checks. Keep the selected Skill chapters and novice/veteran entry path explicit in Task briefs.

### Task graph

Each Task carries one Primary Role, exact baseline, allowed/forbidden paths, dependencies, inputs, outputs, acceptance, tests, report path and required Skills.

Run two tracks in parallel once their real design dependencies settle:

- Gameplay implementation: `software-implementer` with `gameplay-programming` and the selected `engine-*`; conditional physics/content/multiplayer/performance/build methods.
- Asset production: `media-producer` with `game-asset-pipeline` and `game-audio` when audio is needed; stable IDs, dimensions, budgets and licensing connect the tracks.

Create separate monetization implementation Tasks for selected IAA/IAP paths, dependent on economy and monetization design. Do not serialize asset production behind unrelated gameplay work. Integration of consuming code depends on compatible asset outputs where real dependencies exist. A source dependency settles only after independent review and integration, not worker_done alone. Dispatch ready Tasks immediately with disjoint write scopes.

### Implementation

Each source Task runs in an independent branch/worktree and runs relevant checks. Workers do not merge. `game-test-engineer` builds `game-test-plan` and records `game-test-evidence` using `game-testing-ladders`: smoke → story → regression → soak → real-device → certification. Define entry/exit criteria, fixtures, environments and failure/skip rules for each applicable rung. Offline logic and null-renderer success do not stand in for engine, physical-device, performance or certification evidence. Every bug fix needs a regression that catches the original defect.

### Independent review

Dispatch independent review when each source Task completes, in parallel with other implementation. Supply objective, acceptance, exact base/branch SHAs and relevant contracts. Reviewers use read-only scope, inspect changed code and evidence, and do not treat implementer self-checks as independent acceptance. Return fixes and re-review to the original retained sessions under [Session reuse](../references/worker-handoff.md#fix-returns-to-original-implementer-session).

### Integration and publishing readiness

The coordinator integrates approved branches serially into `delivery_branch`, after checking the approved commit and clean trees, and runs the full suite at each integrated HEAD. New Tasks use the updated delivery baseline.

After intended changes integrate and before final verification, dispatch `game-test-engineer` with `game-publishing` for a `publishing-readiness-report`. Apply each target platform's checklist and applicable China compliance matrix to the current release candidate. Require current-policy rechecks, rights/materials/qualification checks, listing and build readiness, and explicit handling of unknown or unavailable evidence. Re-run compliance per release, including content updates; a prior release's approval does not carry forward. Failed or unverified required checks block readiness and route to scoped remediation. This gate does not authorize an upload, purchase or publication; external side effects still require the user's authorization.

### Final verification

Only after integration and publishing readiness pass, dispatch `release-verifier` in a clean worktree from the latest delivery branch. Run the full suite and end-to-end acceptance, including gameplay, assets, selected monetization, target-device evidence, regressions and process-artifact exclusion. A candidate change reopens affected tests and publishing checks before final verification can pass.

### Close and live-ops handoff

After final verification, provide a `game-live-ops` handoff pointer and, when ongoing operation is in scope, `game-designer`'s `live-ops-plan`: event/season cadence, ownership, cohort/economy monitoring, stop/disable/compensation rules and unresolved observations. The handoff is not permission to activate a live event. Write delivery and pending-decision reports, settle workers and reclaim eligible worktrees under the base workflow.

## Re-entry loops

Missing evidence returns to reconnaissance; gameplay ambiguity to design; plan defects to planning; review findings to the original implementation/review sessions; integration or release-readiness failure to a scoped fix on the latest delivery state. Preserve completed work and append-only completedStages while recording the reason for reopening affected decisions.
