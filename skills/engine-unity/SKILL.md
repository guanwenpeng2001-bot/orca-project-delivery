---
name: engine-unity
description: Select and validate Unity projects with separate global Unity and Tuanjie platform, tooling, and license paths. Use when developing a C# game in Unity or assessing Unity for a target channel.
---

# Engine Unity

## 1. When to use / When not to use

Use for C# teams, existing Unity content, or a game whose target platforms and rendering needs fit the chosen editor. Decide between global Unity and Tuanjie before creating the project; they are separate products, not interchangeable regional documentation sites.

Do not proceed when a required channel is absent from that product's official matrix, its license is incompatible with the project, or the required editor, build modules, SDKs, and platform access are unavailable. Global Unity 6 is not the official WeChat, Douyin, or HarmonyOS path; evaluate Tuanjie explicitly for those needs.

## 2. Novice orientation

A scene holds game objects; components give them behavior; prefabs preserve reusable object configurations. The editor previews a scene, while a build produces a target-specific player. A successful editor preview does not prove that player works.

For the first session, record the intended device/channel, global Unity or Tuanjie, exact editor version, C# experience, and license eligibility. Install that editor through its matching Hub with the target build support, create a small template project, save one scene with one visible object, and enter Play mode. Then build that same scene for one accessible target and launch it. Keep the first milestone to one input, one visible response, and a repeatable restart.

## 3. Export matrix

These are documentation indexes, accessed 2026-10-23. A documented target still requires its modules, SDKs, account permissions, and applicable subscription. “Not listed” means no official path established by these sources, not physical impossibility.

### Global Unity 6

Official source: [Unity 6 platform development](https://docs.unity3d.com/6000.0/Documentation/Manual/PlatformSpecific.html), version 6000.0, accessed 2026-10-23.

| Target | Official path / condition |
| --- | --- |
| Windows, macOS, Linux | Native player; install matching build support |
| Android, iOS | Native mobile build; platform SDK/signing requirements apply |
| Web | Browser build; not a mini-game export |
| tvOS, UWP, visionOS, XR | Target-specific modules and device requirements |
| Dedicated Server, embedded systems | Separate target requirements; check entitlement and hardware |
| PlayStation, Xbox (Game Core), Nintendo | Closed platforms; platform-provider agreements and matching modules required |
| WeChat / Douyin mini-games | Not listed; use the separate Tuanjie assessment below |
| HarmonyOS / OpenHarmony | Not listed |

### Tuanjie Engine China

| Target | Official path / condition | Official source; accessed 2026-10-23 |
| --- | --- | --- |
| WeChat, Douyin, Kuaishou, TapTap, 233 mini-games; mini-game host | MiniGame subplatform packages; exactly one active subplatform for a build | [MiniGame build settings](https://docs.unity.cn/cn/tuanjiemanual/Manual/BuildSettingsMiniGame.html) |
| OpenHarmony | Native Tuanjie integration; not an Android wrapper | [OpenHarmony](https://docs.unity.cn/cn/tuanjiemanual/Manual/openharmony.html) |
| Windows, macOS, Linux, Android, iOS, WebGL | Listed in Tuanjie 1.10; verify the installed version's target modules before promising delivery | [Tuanjie platform development](https://docs.unity.cn/cn/tuanjiemanual/Manual/PlatformSpecific.html) |

The MiniGame documentation permits at most one active subplatform because SDK packages conflict. Select exactly one when building; inactive subplatform packages are excluded. Do not add community converters to either official matrix; assess any proposed converter separately, with its own support and license evidence.

## 4. Project-side docs boundary

Keep API signatures, render-pipeline details, package versions, SDK setup, signing, and migration instructions in the project or the version-matched official documentation. Global projects use docs.unity3d.com; Tuanjie-specific platforms use docs.unity.cn. Record the chosen manual version and access date in the project's documentation index, optionally under docs/engine/unity/.

Preserve project settings, package manifests/locks, assets and their metadata in the project's normal version control policy. This skill is a method and reference index, not a manual mirror. Unlike Maker's managed documentation pull-down, no equivalent automatic engine-docs refresh is assumed here.

## 5. Working method

1. Inspect the existing editor version, product identity, package lock, rendering pipeline, platform modules, and build configuration before opening or upgrading the project.
2. Choose one target and a measurable playable slice. Agree on input behavior, restart behavior, frame-time budget, and representative device before implementation.
3. Use the matching Hub/editor and build support. For Tuanjie MiniGame, select exactly one subplatform and verify the inactive SDKs are excluded.
4. Implement the smallest scene-to-player path. Keep gameplay decisions separate from platform SDK integration; consult project-side references for APIs.
5. Preview in the editor, build the selected target, then run the produced player on the intended device/runtime. Check startup, input, scene transitions, persistence, and logs against the slice's acceptance criteria.
6. Record editor/product, target, configuration, artifact location, device, and observed result. A compile success or editor-only pass cannot stand in for a target run. Resolve missing modules or permissions before claiming platform verification.

## 6. AI tooling

Detect the actual product/version, installed packages, Unity CLI, and exposed tools first. For global Unity, follow [Unity AI](https://docs.unity.com/en-us/ai) and [replacement of Assistant MCP with Unity CLI](https://docs.unity.com/en-us/unity-cli/replace-mcp-server-unity-cli), accessed 2026-10-23. The official entry is Unity CLI's `unity mcp`; the Assistant-embedded MCP is deprecated. Check the documented compatibility requirements, including Unity 6.0 LTS or later and Assistant 2.13 or later for the replacement path, before changing a working connection.

Tuanjie's first-party MCP compatibility is unverified in this snapshot. Consult its installed version's official tooling documentation; do not assume the global CLI works unchanged. If no compatible first-party connection exists, edit project files and use the supported editor/build workflow, reporting manual verification explicitly. Do not install a community MCP as an implicit substitute. Automation must remain within the product's account and license permissions.

## 7. License snapshot

Access date for all sources below: 2026-10-23. These are pinned commercial facts, not a promise that future terms remain unchanged.

### Global Unity

[Pricing updates](https://unity.com/products/pricing-updates) documents Personal as free up to USD 200,000 in revenue and funding; Pro is USD 2,310 per seat/year prepaid (or USD 210 per seat/month). The page describes Enterprise as required above USD 25 million annual revenue and funding. The [pricing page](https://unity.com/pricing) specifies the prior-12-month window for Personal and the last-12-month window for Enterprise; verify the applicable subscription terms at that exact boundary. The Unity Runtime Fee was canceled, including for Unity 6 and other versions: this global licensing path has no runtime royalty. Do not transfer these dollar thresholds or that pricing conclusion to Tuanjie.

### Tuanjie

[Store subscription snapshot](https://store.unity.cn/tuanjie-licenses): prices include tax and are prepaid annually; each bundle includes Tuanjie and Unity editions for the same authorized user.

| Bundle | Annual prepaid price | Store qualification wording: trailing-12-month overall financial scale |
| --- | --- | --- |
| Pro | CNY 18,888 | Non-industry: at least CNY 1.5 million and no more than CNY 200 million; industry: at least CNY 1.5 million and no more than CNY 10 million |
| Enterprise | CNY 31,999 | CNY 200 million or above; minimum subscription/spend commitments may apply |
| Industry | CNY 40,832.55 | Content outside games, entertainment, and vehicle applications, with CNY 10 million or above |

[Terms of service](https://unity.cn/tuanjie/legal/terms-of-service), effective 2026-08-14, section 1.3.2 instead states Personal at no more than CNY 1,500,000; Pro from CNY 1,500,001 through CNY 200,000,000; Enterprise at CNY 200,000,000 or above; and Industry for industrial customers exceeding CNY 10,000,000. The store and terms disagree at the CNY 1.5 million and CNY 10 million boundaries, and Pro/Enterprise overlap at CNY 200 million. Preserve this discrepancy; obtain current vendor clarification for a boundary case rather than silently choosing eligibility. Industrial classification also differs in wording and is subject to the terms' definition.

Financial scale is not simply a game's revenue: section 1.3.2 covers organizational assets, annual income or nonprofit budget, controlling entities, and in service work the client's scale. Reassess eligibility across the trailing twelve months. Additional platform, build-server, industrial runtime, or service rights can require separate authorization/payment; a bundle price is not an all-platform deployment quote.

[Tuanjie Package Distribution License v1.0](https://unity.cn/tuanjie/legal/licenses/tuanjie-package-distribution-license) grants a royalty-free, non-exclusive, non-sublicensable license for covered works, with distribution limited to binaries integrated into Project Content under the runtime distribution terms. It does not grant unrestricted package/source redistribution or establish that all Tuanjie services are free.

**Verify current policy:** before procurement, upgrade, or release, re-read the pricing page, applicable product terms, platform entitlements, and package licenses; record the date and resolve any boundary discrepancy with the vendor.

## 8. Common structural traps

- Global Unity and Tuanjie project types are not interoperable. Treat a move between them as an explicit migration with compatibility testing, not reopening the same project in another editor.
- A Web build is not a WeChat or Douyin mini-game. The runtime, SDK, and distribution contract differ.
- Tuanjie MiniGame subplatforms are mutually exclusive; enabling multiple SDK paths does not create a universal build.
- A render pipeline or package upgrade can change assets and serialization. Pin the project version before evaluating target failures.
- An installed module or successful AI tool call does not prove entitlement, packaging success, or device behavior. Keep those checks distinct.
