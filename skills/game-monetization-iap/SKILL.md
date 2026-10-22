---
name: game-monetization-iap
description: Design game purchase catalogs, first-purchase offers, revenue measurement, and entitlement/refund duties. Use when planning or evaluating in-app purchases and subscriptions.
---

# Game Monetization: In-App Purchases

## 1. When to use / When not to use

Use to design a small understandable catalog, evaluate purchase timing, or define fulfillment and refund behavior. Do not use pricing guesses as revenue forecasts, substitute monetization for a playable game, or integrate a payment provider before confirming the release platform's rules.

## 2. Novice orientation

IAP means an in-app purchase. A consumable is spent (such as currency); a durable entitlement persists (such as removing ads). A subscription grants benefits for an active period, while a one-time purchase does not renew. A funnel follows players from seeing an offer to receiving its benefits.

For the first session:

1. Describe one benefit the player can understand after experiencing the normal loop.
2. Write a product card: benefit, amount, duration, eligible audience, localized price source, and what survives reinstall or account recovery.
3. Decide whether it is consumable, durable, or recurring. Explain what happens on cancellation and refund.
4. Walk through purchase success, cancellation, pending payment, retry, restore, and refund on paper.
5. Choose a small trial audience and measurement window. Ask for economy and storefront data before recommending a final price.

## 3. Core method

### Build a coherent catalog

Start with a few products whose benefits do not overlap ambiguously:

| Product | Design decision | Failure to avoid |
| --- | --- | --- |
| Remove ads | State exactly which ad formats disappear and whether optional rewarded ads remain; preserve the durable entitlement | Selling an unclear promise or making the purchaser watch forced ads |
| Starter pack | Offer a comprehensible early benefit after the player understands its value; define purchase limit | A fake deadline or an offer that makes ordinary progression feel broken |
| Currency bundles | Show currency quantity, localized total price, and any genuine bonus; model spend and sinks | Unexplained conversion rates or stock inflation that defeats progression |
| Subscription | Provide recurring value, clear renewal/cancellation terms, and explicit inactive/grace-period behavior | Recurring billing for a benefit that is effectively delivered only once |
| One-time unlock | Define persistent content/access and recovery across supported devices/accounts | Treating reinstall or restore as a new sale |

An illustrative remove-ads price is USD 1.99–3.99: **industry-common range, unverified market heuristic; calibrate against the project's own data**. It is not an optimal-price claim or a recommended default. Do not import a single sweet-spot price or DAU threshold from an unsourced reference. Derive actual price candidates from benefit value, regional purchasing power, platform tiers, taxes/fees, and experiments. Express any other speculative price figures as labeled industry-common ranges with the same calibration limitation, or omit them.

### Time the first purchase around understood value

Let the player experience the core loop and benefit before offering a purchase. Place the first offer at a relevant optional decision, with an obvious dismiss path. Avoid an automatic purchase modal on first launch or immediately after a failure designed to pressure spending. Compare new and returning players separately; there is no universal minute at which a first purchase should occur.

Model the purchased currency or advantage with game-economy-design. Check non-paying progression and maximum paid uptake, not only the average payer. A starter pack should not eliminate the intended learning loop. Evaluate IAA and IAP together so a remove-ads product and rewarded offers keep their stated promises.

### Measure a defined funnel

Track eligible players → offer viewers → purchase initiators → platform-confirmed purchases → fulfilled entitlements. Include pending, canceled, failed, refunded, and restored transactions as distinct outcomes. Use stable transaction identity to avoid counting retries as additional sales.

Define metrics before reading results:

- Payer conversion = distinct paying players / eligible players in the same window and population; state if a different denominator is used.
- Purchase completion = confirmed purchases / initiated purchase attempts, with a stated pending-payment cutoff.
- ARPPU (average revenue per paying user) = recognized purchase revenue / distinct paying users for the same interval. Declare gross versus net revenue, currency conversion, fees, taxes, refunds, and subscription recognition treatment. A zero payer count produces an undefined metric, not zero success.
- LTV (lifetime value) = cumulative revenue or contribution per acquired player over a defined lifetime/horizon. Distinguish observed cohort value to date from a forecast, and state retention, spend, cost, and discount assumptions. Include ad revenue only if the definition says so; do not present ARPPU as LTV.

Compare like cohorts and disclose sample size, exposure, and uncertainty. Evaluate incremental net value alongside retention, support load, refund rate, and economy guardrails. Do not forecast lifetime profit from a short launch spike.

### Fulfillment, refunds, and compliance

Use platform-confirmed transaction state as the purchase authority; a client success screen alone is insufficient. Make grants repeat-safe, support durable-entitlement restoration, and reconcile delayed notifications and out-of-order refund events. Define how a refund revokes access or reconciles spent consumables without silently corrupting the player's inventory. Keep an auditable transaction history and a support route.

Assign responsibility for minor-initiated purchase refunds, chargebacks, cancellation, privacy, randomized reward disclosures, and consumer terms. Re-check the current storefront and jurisdiction rules for every release. Show localized prices and subscription terms before confirmation; do not hard-code a currency symbol from a design mockup. Test with the platform's supported test environment through project-side integration guidance.

## 4. Failure criteria and measurable invariants

- Without catalog values, exposure counts, revenue definitions, and an observation window, report `NOT ASSESSED — NO DATA` for pricing effectiveness or LTV.
- Every confirmed transaction grants its entitlement once; retries and restores never duplicate consumables.
- Every durable product has a tested recovery path; every subscription has explicit renewal, cancellation, and entitlement-expiry behavior.
- Refund and pending-payment test cases reconcile transaction state with entitlements within the project's stated processing budget. A missing budget is unassessed, not pass.
- All displayed prices come from the selected storefront context; all unverified design price figures are labeled ranges requiring calibration.

Evaluation: a purchase succeeds while the client disconnects; reconciliation grants once after reconnect. High ARPPU with falling payer conversion and rising refunds does not establish improved LTV.

## 5. Platform/engine boundary

StoreKit, Google Play Billing, platform payment SDKs, receipt verification endpoints, product-console configuration, and refund APIs belong to official project-side platform documentation. The engine-* skills own runtime integration details. Use game-publishing for release policy checks and game-economy-design for value and stock modeling. This method does not authorize charges, refunds, product activation, or live experiments.

## 6. Sources and verification status

Primarily original method prose, prepared 2026-10-23. [pollocrudocompany/gamedev-claude-skills](https://github.com/pollocrudocompany/gamedev-claude-skills), commit `3811dcbc6e5dc28265ac1358d5d78bf78a9835b3`, MIT, monetization-casual is a skeleton reference only, through the dated methods reconnaissance. Its price and performance numbers have no cited dataset; none is treated as verified market evidence. No external text, code, or workflow shell is copied.

Metric definitions above are explicit measurement conventions; a project must preserve its chosen accounting basis. Price effectiveness and lifetime forecasts are unverified until supported by project data. Billing exceptions, refunds, minor protection, randomized rewards, privacy, and subscription disclosures are `verify-current-policy` with game-publishing's dated platform sources.
