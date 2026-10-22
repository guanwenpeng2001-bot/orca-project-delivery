---
name: game-economy-design
description: Model resource flows, progression costs, purchases, and reward incentives with explicit balance tests. Use when designing currencies, shops, crafting, upgrades, or currency rewards from ads or purchases.
---

# Game Economy Design

## 1. When to use / When not to use

Use when scarce resources mediate player decisions or progression, including non-monetized games. Review the economy before attaching paid or advertising rewards.

Do not use to select payment SDKs, implement ad callbacks, establish legal compliance, or forecast revenue from absent cohort data. Do not approve balance from prices alone: earning rates, purchase effects, and player behavior are required.

## 2. Novice orientation

An economy is a set of rules for obtaining, holding, and spending resources. A source creates a resource, a sink removes it, and stock is what remains in the player's possession. Moving coins between players is a transfer, not a source for the whole economy.

Start with a paper ledger or spreadsheet:

1. Name a resource and what it buys. List each way to earn it and each way to spend it.
2. Choose an explicitly hypothetical starting balance, session earning amount, and purchase price. Record a session as opening balance, earnings, spending, and closing balance.
3. Carry the closing balance into the next session. Only allow a purchase when its prerequisites and affordability rules are satisfied.
4. Add the purchase's actual effect: if it increases earnings, recalculate later income. Repeat until the first purchase and a later upgrade are reached.
5. Compare a play-only path with a reward-assisted path. Replace assumptions with observations from a prototype before judging fairness.

First-session checklist: a complete resource ledger, a purchase reached without unexplained money, a visible benefit from that purchase, and a list of unknown rates.

| Term | Meaning |
| --- | --- |
| Soft currency | A resource normally earned through play |
| Premium currency | A resource with restricted or paid acquisition; its name does not establish its value |
| Sink | Consumption that removes a resource from the modeled economy |
| Stock | Resource balance at a specified time |
| Payback | Time or uses required for an investment's extra output to recover its cost |
| Progression wall | A sharp increase in effort needed to advance |

## 3. Core method

### Define purpose and accounting scope

Inventory currencies, items, unlocks, conversion rules, and restrictions. For every currency, explain the distinct choice it creates. These starting counts come from the small web-game source in chapter 6, not a universal cap:

| Game scope | Source's suggested currency count | Review question |
| --- | --- | --- |
| Single-session / hypercasual | 1 | Does another resource introduce a different decision? |
| Casual with persistent progression | 1 soft and 1 rare or premium | Are their purposes actually distinct? |
| Mid-core web game | 2–3 | Can players explain why each exists? |

Choose player, cohort, or global accounting before classifying transfers. For each resource and interval:

`closing stock = opening stock + grants + incoming transfers - consumption - outgoing transfers`

Include refunds, expiry, conversion, caps, and overflow explicitly. In a global ledger, internal transfers cancel. Keep currencies separate unless a documented conversion exists; do not add coins and gems into a meaningless total.

### Model trajectories rather than isolated prices

Measure earning rate by progression state, skill cohort, and activity. Estimate session yield from that rate and active duration; include separately modeled idle income. With constant income and no competing expense, sessions to affordability is remaining price divided by session yield. If income changes, sinks compete, or a purchase has prerequisites, simulate the ledger session by session instead.

Build a table of tier, cost, effect, marginal benefit, affordability time, and alternatives foregone. Geometric prices and diminishing effects are candidate curve families, not mandatory laws. Check early access, mid-game decisions, and the end of finite upgrade ladders. A growing stock can be intentional saving; a zero balance can be an intentional purchase. Diagnose these patterns against goals and actions, not balance shape alone.

For an income upgrade with constant additional yield, payback time equals cost divided by additional yield per unit time. If additional yield is nonpositive, it has no financial payback; it may still offer utility. Include risk and opportunity cost before declaring a purchase mandatory.

### Treat advertising rewards as uncertain issuance

Ad-paid currency is a source whose realized rate the designer does not control: availability and player uptake vary. Designers can constrain reward size, eligibility, and a maximum frequency, but cannot assume an actual grant rate. Model no availability, observed availability, and the maximum allowed grant path separately. Never require an ad to complete the ordinary progression path unless that product decision is explicit.

Compute reward / normal session yield only when the denominator is positive, then examine what the reward buys and its effect on time to unlock. Compare the whole repeated strategy, including caps and eligibility, with playing. If repeatedly collecting rewards removes the need for the intended gameplay, repair the incentive before integrating the placement. SDK payout correctness is a separate implementation question.

### Audit option dominance with an explicit state distribution

Define comparable options, feasible states, player objective, time horizon, costs, and an expected-value model. For each option, compute the weighted fraction of evaluated states in which its expected value is strictly greater than every alternative. Use the source's 80% dominance heuristic as an investigation threshold: no option should exceed **80%** for a system intended to sustain strategic alternatives. Record ties, weights, excluded states, and sensitivity to the utility model.

This threshold is a source-authored heuristic, not empirical proof of fairness. A higher-tier upgrade may intentionally dominate its predecessor; compare alternatives available at the same decision point. An arbitrary sample or a single metric cannot establish global balance. Follow simulation with observed choices and player explanations.

Deliver the currency inventory, flow ledger, cost/effect table, cohort trajectories, ad scenarios, dominance model, and proposed telemetry. Separate observed values from assumptions and give the next experiment for each consequential unknown.

## 4. Failure criteria and measurable invariants

- Every modeled interval must reconcile the stock equation exactly in the resource's accounting unit. Unexplained creation or disappearance fails the model.
- Stock must remain within declared bounds; a purchase cannot spend unavailable funds unless debt is explicitly part of the design.
- Every required progression gate must have a feasible earning and spending path under the stated non-paying/non-ad scenario when that path is promised.
- A dominance share above 80% fails the proposed diversity criterion unless the scope explicitly calls for that dominance; report the exception and its rationale rather than silently passing it.
- Missing source rates, sink prices, purchase effects, session assumptions, or state weights means **not assessed: missing economy data** for the affected balance conclusion. A hypothetical model can guide instrumentation but cannot receive a measured-balance verdict.
- An empty sample or zero earning rate is not a zero-cost purchase trajectory. Report undefined ratios and unreachable affordability explicitly.

## 5. Platform/engine boundary

This skill owns quantities, incentives, and tests. Payment validation, receipt handling, ad SDK lifecycle, platform reward policies, engine persistence, and analytics APIs remain in project-side skills and versioned docs referenced through AGENTS.md, externalSkills, or roleBindings. Supply reward limits and accounting semantics to those owners. Store prices, platform eligibility, and compliance require current project-side verification; no platform operations are prescribed here.

## 6. Sources and verification status

Accessed 2026-10-23. Methods are rewritten in original prose; upstream scripts, plugin state, and workflow dependencies are not adopted.

- [Virtual economy method](https://github.com/horn111/web-game-ad-skills/blob/6a482b9683b7082036337bf66ffeb973013500de/skills/virtual-economy-review/SKILL.md): source/sink/stock framing, the currency-count table, and uncertain ad issuance. Verified as source recommendations; effectiveness for a particular audience is unverified.
- [Balance method](https://github.com/rondorkerin/gamestack/blob/0419358df31455e63820bdd89f3c5b446665f604/plugins/gamestack/skills/difficulty-and-balancing/SKILL.md): the 80% dominance heuristic. Verified in the source; sampling and utility controls above are this package's operationalization.
- License snapshots: [horn111 MIT](https://github.com/horn111/web-game-ad-skills/blob/6a482b9683b7082036337bf66ffeb973013500de/LICENSE) and [gamestack MIT](https://github.com/rondorkerin/gamestack/blob/0419358df31455e63820bdd89f3c5b446665f604/LICENSE). verify-current-policy: review obligations if the source reuse changes.

No unsourced numerical price, revenue, or retention target is prescribed. Project measurements remain unavailable until supplied; platform monetization policy is outside this source verification.
