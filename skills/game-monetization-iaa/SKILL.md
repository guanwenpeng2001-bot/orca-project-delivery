---
name: game-monetization-iaa
description: Design intent-based game ad placements and economy-sized rewards with measurable player-experience guardrails. Use when adding or evaluating in-app advertising in a game.
---

# Game Monetization: In-App Advertising

## 1. When to use / When not to use

Use for deciding where ads belong, how rewarded ads affect progression, or whether a placement improves the game's economics. Do not begin with SDK integration or a timer that interrupts play. If there is no playable loop or economy model, establish those before approving monetization.

## 2. Novice orientation

IAA means in-app advertising. An interstitial is a full-screen interruption; a rewarded ad is an optional exchange whose reward is explained before the player chooses it. An impression is a displayed ad; fill rate measures whether ad requests receive usable ads; eCPM is revenue per thousand impressions.

For the first session:

1. Play one complete round and mark moments when the player naturally pauses or wants a benefit.
2. Select one optional rewarded offer, state its benefit and a decline path, and keep ordinary play possible without it.
3. Write what the reward buys and how long normal play takes to earn it.
4. Walk through accept, decline, no-fill, interrupted playback, and a repeated completion callback without requiring a live ad network.
5. Record the measurement plan and request platform integration through project-side documentation only after the placement design is clear.

## 3. Core method

### Place ads at player-intent moments

Map intent before inventory: continuing after failure, voluntarily increasing an earned reward, or obtaining a clearly priced optional resource. Offer the benefit where the player understands its value. Do not invent frustration or withhold promised rewards to manufacture conversion. Reject a placement that obscures the exit/decline action.

Use these design guardrails, not claims of universal revenue optimization:

- Never show an interstitial mid-gameplay or while a player is making a time-sensitive decision.
- Do not show interstitials during the first 3 minutes of the first session.
- Set a minimum interstitial interval in the 2–3 minute range, defaulting to 3 minutes pending project data; never go below 2 minutes under this method. Measure from the end of the previous interstitial. A timer expiring makes an ad eligible, not mandatory: wait for a natural break.
- After a player death, offer an optional rewarded ad instead of an interstitial. If unavailable or declined, continue the normal retry/exit path without substituting an interstitial.
- Apply stricter platform and audience rules where required. No-fill must not prevent the player from continuing the ordinary loop.

### Derive rewards from the economy

Treat ad currency as a source whose external delivery rate the game does not control: availability, fill, and player uptake vary. The game still controls eligibility and caps. Never assume unlimited ads, or a stable number of completions, to make basic progression viable.

From game-economy-design obtain normal earning rate, balances, purchase costs, sources, sinks, and target progression time. For reward size R and normal earning rate E, R/E is the amount of normal play displaced, when E is positive and both use the same time units. Compare it with the value of the intended benefit. Estimate added currency as completed rewarded views × R, segmented by cohort; model zero-fill, expected uptake, and the highest allowed uptake. Choose caps and reward size that preserve the economy in all three cases. If E is zero, use a documented non-currency value model instead of dividing by zero.

Show the exact reward before consent, grant only on the platform-confirmed qualifying completion, and deduplicate fulfillment by a stable transaction/entitlement identity. A retry must not multiply rewards. Decide how rewards recover after reconnects and how players report missing grants.

### Rank slots by observed conversion

For each slot record eligible moments, offers actually shown, accepts, starts, qualifying completions, granted rewards, impressions, and revenue. Keep denominators explicit: offer conversion = accepts / shown offers; completion conversion = qualifying completions / starts; realized slot conversion = completed rewarded views / eligible moments. Rank comparable slots by realized conversion, with sample sizes and observation window. Do not import a universal ranking from another game.

Use revenue per active user and retention/progression guardrails alongside conversion. Compare cohorts with similar exposure and use controlled rollout when possible. A slot with higher conversion but broken progression or worse retention fails the design. Define project-specific thresholds before collecting results, and retain a way to disable each placement independently.

## 4. Failure criteria and measurable invariants

- Without economy inputs and a placement funnel, report `NOT ASSESSED — NO DATA` for reward sizing or monetization effectiveness.
- Interstitials shown during active play, within the first-session exclusion window, or before the configured minimum interval must total zero in the tested sessions.
- A death flow has zero fallback interstitials; declining the rewarded offer reaches the ordinary retry/exit route.
- One qualifying completion produces exactly one promised grant; duplicate callbacks produce zero additional currency.
- No-fill and failed playback produce no false success and leave ordinary progression accessible.
- Simulated maximum permitted ad uptake stays within the project's economy budget; missing budget means sizing is unassessed.

Evaluation: a timer expires during combat; defer the interstitial until a valid break. A highly converting currency offer halves intended progression time beyond the agreed budget; resize or remove it rather than celebrating conversion alone.

## 5. Platform/engine boundary

Ad-network SDK calls, consent APIs, ad unit creation, platform eligibility, and settlement configuration belong to project-side official platform documentation. For Maker, the connected provider's ad guide and configuration capability own integration. This package contains no SDK calls or console instructions. Use game-publishing to re-check regional and audience policy per release, and engine-* skills for runtime lifecycle integration.

## 6. Sources and verification status

Original prose prepared 2026-10-23, using the dated methods reconnaissance:

- [horn111/web-game-ad-skills](https://github.com/horn111/web-game-ad-skills), `6a482b9683b7082036337bf66ffeb973013500de`, MIT: virtual-economy-review and f2p-monetization-ethics-review inform reward-source reasoning and player choice. No platform implementation is copied.
- [pollocrudocompany/gamedev-claude-skills](https://github.com/pollocrudocompany/gamedev-claude-skills), `3811dcbc6e5dc28265ac1358d5d78bf78a9835b3`, MIT: monetization-casual is a skeleton reference for timing, intent moments, and placement comparisons. Its numbers lack supporting market data. The 3-minute first-session exclusion and 2–3-minute spacing are explicit design constraints here, not verified industry performance facts.

Reward values, conversion rankings, and revenue effects require project measurements. Platform ad eligibility, privacy/consent, minor protection, and settlement requirements are `verify-current-policy` for the release jurisdiction and current SDK.
