---
name: engine-web-canvas
description: Choose and verify browser-first games built with Phaser or native Canvas while keeping wrapper, channel, and cloud-service boundaries explicit. Use when building or exporting a JavaScript or TypeScript browser game.
---

# Web Canvas Engine

## 1. When to use / When not to use

Use for browser games, embedded experiences, and lightweight prototypes where JavaScript or TypeScript fits the team. Choose native Canvas for a deliberately small rendering surface; choose Phaser when a game framework reduces project work.

Veto the proposed path when the required channel has no supported delivery route, its license or service terms conflict with the project, or its build and test toolchain is unavailable. A required native background lifecycle or native interaction model needs a wrapper feasibility check before choosing this path. An adapter is a separate integration decision, not evidence of official mini-game export support.

## 2. Novice orientation

A development server previews source changes; a production build produces the files players receive. A wrapper packages those files inside a native application.

1. Start in an empty project directory and record the target browser and one playable interaction.
2. For Phaser, follow the starter linked from the [official documentation](https://docs.phaser.io/) and use its current project-creation instructions. Install the starter's declared runtime and dependencies. For native Canvas, create a minimal page and canvas using the project's chosen web toolchain.
3. Use the starter's documented development-server command, open its local address, and display one moving object with one input response. Keep engine-specific implementation in the project.
4. Confirm that the page loads without console or network errors and input visibly changes the scene. This is the first preview, not a packaged mobile build.
5. Save the selected dependency version, lockfile, startup command, and expected preview behavior in project documentation.

First-session checklist: a served page, visible content, working input, and a repeatable restart. Consult the official documentation for the installed version; documentation snapshot accessed 2026-10-23.

## 3. Export matrix

Snapshot: Phaser 4 / native Canvas, accessed 2026-10-23. Supported means the scout's official route is listed; conditional means additional packaging or adaptation is required. Not listed is treated as unsupported for selection, not physically impossible.

| Engine | WeChat mini-games | Douyin mini-games | Android | iOS | HarmonyOS/OpenHarmony | Windows/macOS/Linux | Web |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Web Canvas (Phaser 4 / native Canvas) | Conditional: adaptation layer [1] | Conditional: same [1] | Conditional: Capacitor wrapper | Conditional: Capacitor wrapper | Not listed | Supported: browser is the platform | Supported: first-class |

Official sources, all accessed 2026-10-23: [Phaser documentation](https://docs.phaser.io/), [Capacitor mobile packaging tutorial](https://phaser.io/tutorials/bring-your-phaser-game-to-ios-and-android-with-capacitor), and [Phaser Game Agent export announcement](https://phaser.io/news/2026/07/phaser-game-agent-export). The mobile tutorial establishes the Phaser wrapper route; native Canvas wrapper compatibility must be checked in its own project. The desktop cell means browser delivery. The separate commercial Game Agent service advertises Web ZIP and Windows/Linux/macOS exports; it is not a local engine export guarantee.

[1] Unofficial community adaptation only: neither WeChat nor Douyin has an official Phaser export in this snapshot. An adapter must be independently evaluated against the channel runtime; this footnote is not an endorsed implementation or plugin recommendation.

## 4. Project-side docs boundary

Keep Phaser classes, signatures, rendering details, browser API usage, shader syntax, migration notes, and wrapper/channel SDK instructions outside this skill. The [Phaser documentation](https://docs.phaser.io/) owns framework details; the project's pinned browser documentation and wrapper documentation own their respective details. Official documentation accessed 2026-10-23.

No UrhoX-style combined document download and managed policy-update mechanism was established for this path. Maintain project-owned source links or selected snapshots in `docs/engine/web-canvas/`, recording version and retrieval date. Project `AGENTS.md` or external skill bindings should identify those authorities and the build commands. Do not mirror the documentation site into this package.

## 5. Working method

1. Detect the installed framework, dependency lockfile, runtime, build scripts, and any existing wrapper. Separate native Canvas from Phaser rather than assuming the same toolchain.
2. Choose the delivery route from the matrix before implementing channel integrations. Record whether the deliverable is a static site, wrapped app, or commercial cloud export.
3. Implement one playable slice and preview it through the project's server. Check touch and keyboard input, viewport resizing, device-pixel scaling, safe areas, and loading behavior.
4. Produce the production static build with the pinned project command. Serve that output independently of the development server; verify asset paths and clean-start behavior.
5. If wrapping, use the version-matched official wrapper instructions and validate the installed package on the target device. Test browser and native lifecycle behavior separately.
6. Record the artifact location, tested browser/device, versions, and observed behavior. A browser pass cannot establish mini-game or mobile-package readiness.

## 6. AI tooling

Detect the actual framework, installed tools, configured integrations, and account availability first. For Phaser, the first-party commercial entry is [Phaser Game Agent / Agent MCP](https://phaser.io/agent/mcp), accessed 2026-10-23. Discover the currently exposed capabilities before using them: the source snapshot confirms the entry, not individual MCP tool behavior. Cloud exports depend on the service account and terms.

If that service is unavailable or the project chooses the local open-source route, edit project files and use the project's development server and build scripts. Native Canvas does not inherit a first-party Phaser integration. Mini-game adaptation likewise has no first-party MCP route established by this snapshot. Do not substitute a third-party MCP recommendation for a missing official capability.

## 7. License snapshot

Phaser engine: MIT, with no engine royalty or revenue threshold under that license. Source: [Phaser LICENSE.md](https://github.com/phaserjs/phaser/blob/master/LICENSE.md), accessed 2026-10-23; the scout pairs this with package `phaser@4.2.1`. The observed copyright is 2026 Richard Davey, Phaser Studio Inc. Retain the copyright and permission notice when redistributing covered software.

This is a Phaser engine snapshot, not a blanket license for native Canvas dependencies, game assets, wrappers, or commercial services. Game Agent and Editor subscriptions have separate terms and costs; their engine-independent prices are not pinned here. The source URL follows a moving branch, so retain the installed package's actual license in the project.

Verify-current-policy: terms change. Before adoption and release, re-read the linked license and applicable service and dependency terms, and record the project's selected versions and check date.

## 8. Common structural traps

- Treating desktop browser support as a native desktop packaging pipeline.
- Ignoring device-pixel scaling, safe areas, or touch input because a desktop preview looks correct.
- Exceeding mobile memory and texture budgets despite acceptable desktop performance.
- Assuming a mini-game runtime exposes the browser facilities the game relies on.
- Treating a paid cloud export account as a prerequisite for the local MIT engine workflow.
