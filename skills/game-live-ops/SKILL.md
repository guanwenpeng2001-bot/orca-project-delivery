---
name: game-live-ops
description: Plan game seasons, events, economy monitoring, and recovery using player cohorts and operational capacity. Use when operating a released game or designing a repeatable content cadence.
---

# Game Live Operations

## 1. When to use / When not to use

Use to design a season, evaluate a recurring event, or respond to a measured economy change. Do not use live events to disguise a broken core loop, promise retention improvements without data, or execute production changes without project authorization. First establish a playable, observable baseline.

## 2. Novice orientation

Live operations means maintaining the player's experience after launch: scheduled content, fair rewards, service health, and support. A season is a bounded progression period; an event is a shorter activity with entry, rules, rewards, and an end. A cohort is a group with a shared starting condition, such as install week; a sink removes currency and a source creates it.

For the first session:

1. Play the normal loop and list what a returning player can do today.
2. Pick one player need, such as a reason to revisit a mastered level, and one small event that serves it.
3. Write the start/end time with timezone, eligibility, one objective, reward, completion rule, and what happens to unclaimed rewards.
4. Check the reward against game-economy-design and walk through the event as a new player and a returning player.
5. Identify who watches the event, how to disable it, and which results will decide whether to repeat it. If telemetry is absent, run a limited usability trial and report that limitation.

## 3. Core method

### Set a sustainable cadence

Build the season calendar from content-production capacity, QA time, player progression time, and support coverage. Reserve time for stabilization and recovery. Separate the season's long-term goal from shorter events so players can understand both without competing deadlines. Decide whether progress resets, carries over, converts, or expires, and communicate that before entry. Do not infer a universal optimal season length.

Map events against player segments and fatigue: avoid demanding simultaneous daily commitments merely to fill the calendar. Include a return path for late joiners and a clear outcome for players who cannot finish. Schedule rollout, observation, and post-event analysis as real work, not just content creation.

### Design an event contract

Specify hypothesis, audience, entry conditions, start/end timezone, objectives, difficulty, attempts, reward budget, purchase/ad interactions, and completion/claim rules. Describe the experience before monetization. Model new, returning, highly active, and paying players separately. Test clock boundaries, reconnects, full inventory, already-claimed rewards, and the season transition.

Make reward grants repeat-safe: replaying a claim or reconnecting must not duplicate the economic effect. Define how interrupted sessions finish when the event closes. Explain expired event currency and unclaimed rewards before players spend effort or money. Re-run publishing compliance checks for every content update, including remotely configured events.

### Observe economy and experience together

Measure currency created and removed per active player and per cohort, balance distributions, reward claim rates, progression speed, and scarce-item availability. Reconcile opening stock + sources - sinks with closing stock over the same population and interval, accounting explicitly for transfers, expiration, and corrections. A rising average can hide a small group accumulating most currency; inspect percentiles and segments.

Pair participation and completion with retention, session quality, support complaints, crash rates, and refund signals. Define each denominator and window before comparing events. Compare comparable cohorts or a controlled rollout; calendar effects and player selection prevent a simple before/after difference from proving causation. For small samples, report uncertainty and avoid declaring a winning event.

### Operate and learn

Before activation, assign an owner, stop thresholds, communication plan, and recovery action. Rehearse disablement and compensation without duplicate grants. During rollout watch both service health and economic drift. Stop or reduce exposure when the predefined threshold is crossed; preserve transaction history for reconciliation.

After closure, compare outcomes with the hypothesis, review production effort and player fatigue, and decide repeat, revise, or retire. Carry only supported learning into the next season. Hand technical patches to game-build-release and store/content review to game-publishing.

## 4. Failure criteria and measurable invariants

- Without cohort definitions, event exposure, observation windows, and comparable measurements, report `NOT ASSESSED — NO DATA` for effectiveness.
- Each reward entitlement is fulfilled at most once, including retries and reconnects; a replay test must leave stock unchanged after the first successful grant.
- Every event has explicit start, end, timezone, closure behavior, owner, and a tested disablement path. Any missing field blocks activation readiness.
- Currency reconciliation differences must fit the project's declared rounding/timing tolerance; unexplained creation or loss blocks economy approval.
- All configured alerts have numeric project-specific thresholds and an observation window. Missing thresholds cannot be called healthy operation.

Evaluation: an event with higher revenue but a breached retention guardrail does not pass on revenue alone. A season with no telemetry may be described and playtested, but its retention impact remains unassessed.

## 5. Platform/engine boundary

Remote configuration, analytics queries, scheduler APIs, platform events, payment refunds, and production switches belong to project-side tools and approved access. Engine-* skills own implementation specifics. This skill supplies event design and decision criteria, not a scheduler, agent team, console workflow, or authorization to change live state.

## 6. Sources and verification status

Original method prose, prepared 2026-10-23. Reference: [Donchitos/Claude-Code-Game-Studios](https://github.com/Donchitos/Claude-Code-Game-Studios), commit `05ad7c8a5b8aa2aa86bbd3439ae7cf7295cac418`, MIT, team-live-ops and economy-designer concepts documented in the methods reconnaissance. Season cadence and event design are extracted as general method only; the upstream sub-agent shell, hooks, roles, and configuration mechanism are excluded.

The operating contract and measurements here are original project guidance. No season duration or revenue uplift is verified by this source. Actual effectiveness requires the game's own data. Event eligibility, privacy, paid rewards, expiration, and regional requirements remain `verify-current-policy` each release.
