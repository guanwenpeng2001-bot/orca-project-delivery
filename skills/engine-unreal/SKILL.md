---
name: engine-unreal
description: Plan Unreal projects around target packaging, Blueprint and C++ boundaries, experimental tooling, and pinned royalty terms. Use when developing an Unreal game or evaluating Unreal for a target device.
---

# Engine Unreal

## 1. When to use / When not to use

Use when high-fidelity 3D, an existing Unreal project, or desktop/console production justifies the editor and packaging toolchain. Blueprint supports visual gameplay iteration; C++ supports code-level systems and engine integration. Choose their boundary by ownership and testability, not by declaring one universally superior.

Do not choose this path when required channels lack official support, the commercial terms conflict with the project, or required hardware, SDKs, platform access, and build tools cannot be obtained. A lightweight H5 or WeChat/Douyin mini-game requirement is not met by a desktop Unreal project streamed to a browser.

## 2. Novice orientation

A level is a playable space; Actors are objects in it; components provide behavior; Blueprints are visual classes/scripts. Cooking converts content for a target, and packaging combines cooked content and executable code into a distributable product.

For a first session, record the engine version, target device, Blueprint/C++ choice, installed SDKs, and Launcher versus source build. Install a matching editor, create a small template, run Play in Editor, and verify one input with one visible result. Package a Development build for an available desktop target and launch it outside the editor. The first milestone is a playable start-to-restart loop, not a large level or a Shipping build.

## 3. Export matrix

Official index: [Packaging projects](https://dev.epicgames.com/documentation/en-us/unreal-engine/packaging-your-project) and [Launching on devices](https://dev.epicgames.com/documentation/en-us/unreal-engine/launching-unreal-engine-projects-on-devices), accessed 2026-10-23. Select the documentation version matching the installed UE 5.x release.

| Target | Documented path / condition |
| --- | --- |
| Windows, macOS, Linux | Native packaging; Linux may need additional SDKs/components |
| iOS, iPadOS, tvOS, Android | Native packaging with target SDKs and signing/device requirements |
| Major consoles | Supported packaging category; requires platform access and an engine source build rather than the Launcher build |
| XR | OpenXR, PSVR2, ARKit, ARCore, visionOS are listed; target-specific requirements apply |
| Web browser | Pixel Streaming is a remotely running native application streamed to a browser, not a standalone Web export |
| WeChat / Douyin mini-games | No official export path established in the cited platform index |
| HarmonyOS / OpenHarmony | No official export path established in the cited platform index |

Pixel Streaming reference: [Pixel Streaming overview](https://dev.epicgames.com/documentation/en-us/unreal-engine/overview-of-pixel-streaming-in-unreal-engine), accessed 2026-10-23. A community exporter, if separately evaluated, belongs in a clearly marked community footnote; it must not turn an unsupported cell into an official capability.

## 4. Project-side docs boundary

Use the version selector on dev.epicgames.com and retain the resolved version or application_version parameter in the project's reference index. Keep APIs, engine-source changes, shader syntax, SDK versions, and platform signing steps there, not in this skill. A project may maintain focused references under docs/engine/unreal/; do not mirror the documentation site.

Keep the project's .uproject, source/content, plugins, and Config under its version control policy. Identify generated outputs separately. There is no assumed Maker-style managed engine-docs pull-down: maintain references explicitly when the project changes engine versions.

## 5. Working method

1. Inspect engine association, build origin, plugins, C++ toolchain, target SDKs, and existing packaging configuration. Do not upgrade the engine merely to obtain an AI integration.
2. Define one playable slice with input, success/failure, restart, and a device-specific frame-time budget. Assign gameplay state ownership across Blueprint and C++ before duplicating logic.
3. Implement and test in the editor, then cook and package the selected target using the version-matched official workflow. Use Development for diagnosis; validate Shipping separately before release.
4. Run the packaged artifact outside the editor on representative hardware. Verify startup map, asset loading, input, transitions, saves, and shutdown; inspect runtime logs and performance against the agreed budget.
5. Repeat the relevant checks after a configuration, plugin, engine, or target change. Record engine version, source/Launcher build, configuration, device, artifact, and actual observations. Packaging success alone is not a playable-build pass.

## 6. AI tooling

Detect the installed engine version, plugins, enabled toolsets, and endpoint before connecting. The [official Unreal MCP documentation](https://dev.epicgames.com/documentation/unreal-engine/unreal-mcp-in-unreal-editor), accessed 2026-10-23, documents the Experimental Unreal MCP plugin for UE 5.8. Follow that version's plugin enablement and generated client configuration; expose only the toolsets needed for the task. Its experimental status means tool contracts may change.

For older versions or an unavailable/incompatible plugin, continue through project-file editing, the editor, and supported build tools. State which editor actions need manual execution and collect their results. Do not pretend a community MCP is first-party or require an engine upgrade just to automate editor actions. A successful tool response still requires checking the resulting project and playable build.

## 7. License snapshot

Pinned source: [Unreal Engine EULA 18.1 PDF](https://cdn2.unrealengine.com/unreal-engine-end-user-license-agreement-18-1-a8e14000e547.pdf), accessed 2026-10-23. These figures summarize that version's Royalty Addendum, not every possible current Epic agreement or negotiated license.

- The royalty rate is **5% of Royalty Revenue**. This is based on the agreement's worldwide gross-revenue definition, not profit; relevant categories include sales, in-app purchases, DLC, subscriptions, advertising, crowdfunding, and advances.
- The first **USD 1 million lifetime gross revenue per product** is excluded, subject to timely Notice of Distribution. It is not a fresh allowance each year or per store.
- A calendar quarter with **less than USD 10,000** gross revenue for that product is excluded. Exactly USD 10,000 does not meet the “less than” condition.
- Revenue from Unreal Engine Marketplace and Epic Games Store sales, and subsequent in-product purchases using Epic's payment services, is excluded as specified in the addendum. Do not extend this exclusion to unrelated storefronts or payment providers.
- Submit the **Notice of Distribution** as early as reasonably possible before distributing a revenue-generating Royalty Product; if a distributed product will begin generating revenue, submit it before that revenue begins. Failure to submit on time can remove permitted exclusions, including the lifetime exclusion.

**Verify current policy:** before distribution or monetization, compare the agreement actually accepted by the project with this 18.1 snapshot. Re-check royalty definitions, notice/reporting duties, exclusions, any seat requirements applicable to the use case, and any separately negotiated terms. Record the applicable version and date; do not calculate a liability from this short index alone.

## 8. Common structural traps

- Play in Editor can mask missing cooked assets, startup maps, and configuration differences; only a packaged run validates the delivered path.
- A Launcher build and a source build do not have identical platform capabilities. Console packaging requires the appropriate source build and platform permissions.
- Blueprint/C++ changes can leave stale editor state after hot reload. Reproduce suspicious behavior after a clean editor restart and rebuild before diagnosing gameplay logic.
- Experimental MCP operations do not replace runtime testing; avoid concurrent conflicting editor mutations and verify each resulting state.
- Pixel Streaming adds server, network, and latency requirements. It is not an offline browser artifact or mini-game exporter.
