---
name: engine-urhox
description: Develop UrhoX games within TapTap Maker using project-pulled documentation and local, remote, and device verification. Use when the delivery target is a TapTap Creative Workshop game.
---

# Engine UrhoX

## 1. When to use / When not to use

Use for a TapTap Maker project whose intended delivery is a TapTap Creative Workshop game and whose creator accepts the platform's distribution and content-license terms. UrhoX combines an Urho3D-derived engine with Lua 5.4 gameplay and NanoVG-based UI; Maker supplies project setup, assets, remote builds, and device testing.

Do not choose it for required standalone APK/iOS application delivery, WeChat/Douyin export, or independent engine/source redistribution. Stop the relevant path when the creator's rights conflict with the platform license, or when the required Maker runtime/account/MCP connection is unavailable. Local implementation may proceed, but cannot be reported as a remotely built or device-verified release.

## 2. Novice orientation

A script controls game behavior, an asset supplies visible or audible content, and the Maker project binding identifies the remote project used for builds. A local preview runs a window on the development machine; a remote preview checks a platform-built revision; a test QR code opens the device-test path.

For the first session, identify the project directory, active Maker CLI distribution/version, account/project binding, installed MCP tools, and intended phone/PC experience. If the project already exists, read its AGENTS.md and engine-docs before changing it. For a new project, use the active Maker CLI's `init` flow in the intended directory, select a small scaffold, and confirm the downloaded documentation and managed instructions exist. Follow the scaffold's local-preview instructions to show one scene, one input response, and a restart. Then advance through the three layers below before calling the slice verified.

## 3. Export matrix

This platform has one distribution channel, not a general export menu. Index snapshot accessed 2026-10-23; consult the initialized project's engine-docs for runtime behavior.

| Target | Supported form / boundary | Official reference; accessed 2026-10-23 |
| --- | --- | --- |
| TapTap Creative Workshop on supported phones/PC | Platform-hosted playable content | [Maker](https://maker.taptap.cn/), [Creative Workshop agreement](https://www.taptap.cn/doc/ugcgame-agreement/) |
| Local development window | Preview only; not a redistributable player | [Maker project workflow](https://github.com/taptap/instant-games-open-mcp/blob/main/docs/MAKER.md) |
| Remote Web preview | Preview of the platform build; not standalone Web export | [Maker project workflow](https://github.com/taptap/instant-games-open-mcp/blob/main/docs/MAKER.md) |
| Independent APK, iOS app, desktop binary, source-code export | No standalone export service under section 2.1 | [Maker agreement](https://www.taptap.cn/doc/taptap-maker-agreement/) |
| WeChat / Douyin, HarmonyOS / OpenHarmony | No official export route established by these sources | [Maker agreement](https://www.taptap.cn/doc/taptap-maker-agreement/) |

Do not turn the MIT license of the upstream engine into an implied Maker export capability. Community ports, if evaluated, must be labeled separately and must not be placed in this official matrix.

## 4. Project-side docs boundary

Maker's `init` pulls engine-docs/, examples/, templates/, urhox-libs/, and an AGENTS.md managed policy block into the project. **The project's engine-docs are authoritative for UrhoX APIs and engine behavior. Never search the web for engine documentation or substitute generic Urho3D documentation.** Read the managed instructions and matching local examples before implementing unfamiliar behavior.

Use the active distribution's `agents update` operation to refresh only the Maker-managed AGENTS.md block; preserve user-owned instructions outside that block. This operation is not evidence that every engine-docs file was refreshed. If the local development kit is missing or mismatched, use the installed Maker workflow's documented repair/update path, then confirm its version and files. Keep project-specific rules separate from managed content.

The development-kit paths are normally ignored by Git. Inspect the actual ignore rules before staging; do not force-add downloaded manuals, examples, libraries, or managed instructions into the deliverable. Own gameplay scripts, assets, and project metadata according to the project's policy. This skill stores methods and reference pointers, not API, Lua UI schema, shader, or platform SDK documentation.

Mechanism reference: [official Maker workflow](https://github.com/taptap/instant-games-open-mcp/blob/main/docs/MAKER.md), accessed 2026-10-23. This reference explains tooling boundaries; it does not replace project-local engine docs.

## 5. Working method

1. Read project instructions and Maker status first. Confirm target directory, active runtime version, remote binding, and current preview state. Reuse an existing project; do not initialize over it to recover a tool connection.
2. Define one playable loop and measurable acceptance criteria. Put tunable gameplay parameters in the project's configuration convention, such as Config.lua, rather than scattering them through UI and simulation logic.
3. Implement using local engine-docs and examples. Run Lua diagnostics before remote building; exercise any relevant offline gameplay tests. Diagnostics and mocked UI tests do not replace rendered verification.
4. **Layer 1 — local window:** use the active Maker CLI's `preview --target-dir <project>` flow for a requested local run. After edits, inspect status and refresh an already running preview; do not revive a deliberately stopped session. Check startup, input, visual layout, restart, and local logs.
5. **Layer 2 — remote build and Web preview:** inspect status, identify the exact files/revision being submitted, and invoke **maker_build_current_directory through MCP only**. Follow its current schema and returned next action. Do not substitute a shell build/push command. Wait for the actual build outcome, open the resulting preview, and repeat the playable loop on that revision.
6. **Layer 3 — real device via QR:** use the exposed generate_test_qrcode flow for the built project and test on a representative device. Check touch, safe areas, performance, lifecycle transitions, and any ads. Ad behavior must be validated on device; read the project's current ads-integration guide before ad work.
7. Record which layers ran, build/revision, device, observations, and failures. This local-window → remote-build/Web-preview → real-device-QR ladder is the verification sequence. If a layer is unavailable, record it as unverified and name what restores it; never promote a local-only pass to release readiness.

Publishing, store material submission, account administration, and test-plan operations belong to the project-side taptap-cli skills, such as taptap-publish-game, taptap-app-edit, and taptap-test-plan. Resolve those through the project's external skill bindings/instructions; this skill does not provide their console commands or authorize publication.

## 6. AI tooling

Detect the active Maker runtime and exposed tool schemas first. Start with maker://status where available, otherwise maker_status_lite. Read the project-local guides named by status before UI, ads, or asset metadata work. Tool availability is version-dependent: discover the build, asset, QR, and feedback tools actually exposed rather than inventing calls from an old list.

Use the official Maker installation/configuration entry supplied by the active distribution if the integration needs setup. The installer is not the long-running MCP server executable; do not register an `install` command as that server. Keep the initialized project and its managed instructions as the source of tooling configuration.

If MCP is disconnected, proceed with local file work, diagnostics, and an authorized local preview where available. Report the missing remote/device verification and restore the supported integration before building. There is no shell-build fallback: builds remain MCP-only. Current-game device feedback goes through the exposed Maker feedback tool; unrelated platform operations stay with project-side taptap-cli skills.

## 7. License snapshot

All sources accessed 2026-10-23. Distinguish the upstream engine license, Maker service contract, and Creative Workshop content grant.

| Layer | Pinned source/version | Material consequence |
| --- | --- | --- |
| Urho3D base | [Upstream MIT license](https://github.com/urho3d/urho3d/blob/master/licenses/urho3d/LICENSE), captured 2026-10-23 | MIT permits use/modification/distribution of covered upstream software with copyright and permission notices; it does not license every UrhoX/Maker component or platform service |
| Maker service | [TapTap Maker agreement](https://www.taptap.cn/doc/taptap-maker-agreement/), effective 2026-01-30 | Section 2.1 provides no export/delivery of the underlying source code corresponding to outputs and no source package or binary independently distributable/runnable outside the platform; low-level engine logic is not delivered |
| Creative Workshop fast publishing | [Creative Workshop content authorization agreement](https://www.taptap.cn/doc/ugcgame-agreement/), effective 2026-03-11 | Publishing grants the designated game publisher a worldwide, exclusive, free, multi-level sublicensable content license |

Tell the creator plainly before choosing this publishing route: **the Creative Workshop grant is exclusive, not merely permission to host a copy.** It covers reproduction, translation, compilation, network distribution, modification, adaptation, derivative works, performance/display, and uses including operation, promotion, marketing, and machine learning. The agreement describes withdrawal through the required delisting process with 30 days' prior written notice to TapTap; do not characterize this particular grant as irrevocable.

The Maker agreement also contains separate permanent, irrevocable, exclusive, worldwide, free, multi-level sublicensable grants in sections 6.3–6.4 for TapTap publication and promotional use. Do not assume withdrawal of the Workshop authorization cancels these separate terms. Output ownership provisions preserve platform/third-party rights, and section 2.3 permits pricing changes; “MIT base” does not mean unrestricted export or permanently free services.

**Verify current policy:** before platform adoption or publication, re-read both service agreements, the accepted developer agreement, content/asset rights, current fees, and withdrawal conditions. Confirm the creator understands the exclusive grants and can authorize all included material. Record the versions/date; obtain clarification for incompatible downstream licensing plans before publishing.

## 8. Common structural traps

- Generic Urho3D examples can describe the wrong API. Use the project's downloaded UrhoX engine-docs, and repair missing documentation through the supported Maker tooling.
- Lua arrays conventionally start at one; ported zero-based indexing can silently skip content or read nil.
- Generated assets still need format and runtime checks. Audio generation does not guarantee OGG conversion; inspect actual project requirements and files.
- Local preview, remote Web preview, and device testing prove different things. Ads, touch behavior, and device performance cannot be signed off from a desktop window.
- Managed documentation and ignored development-kit files are not project-owned source; refreshing a managed block must not overwrite user instructions.
- Platform content ownership does not imply source export, a standalone binary, or a non-exclusive publishing grant.
