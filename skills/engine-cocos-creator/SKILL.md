---
name: engine-cocos-creator
description: Choose and verify Cocos Creator delivery paths across mini-games, native targets, and Web using official platform and tooling boundaries. Use when building, previewing, or exporting a Cocos Creator game.
---

# Cocos Creator Engine

## 1. When to use / When not to use

Use when WeChat, Douyin, HarmonyOS, or a broad mini-game platform set is central to the project. TypeScript is the main gameplay path; native integration may also involve C++.

Veto the proposed path when the required channel is unsupported, the proprietary editor or dependency terms conflict with the project, or the required editor and platform toolchain are unavailable. A high-end PC/console requirement should reopen engine selection rather than assume this mobile/Web-oriented path fits it.

## 2. Novice orientation

The editor organizes scenes and assets. Preview runs the current game for development; Build produces a target-specific artifact, which still needs testing in its destination runtime.

1. Install the project-approved Cocos Creator version and create a project in an empty directory using its simplest suitable template.
2. Open and save one scene, add visible content, and add one TypeScript-driven interaction using the matching beginner manual. Keep implementation details in the project.
3. Run the editor's preview and confirm that input visibly changes the scene with no reported loading or script errors.
4. Stop and restart the preview. Save scene and asset sources plus project settings so another session can repeat it.
5. Choose one Build target only after this first preview works. Follow its official setup page for the required SDK or channel developer tools; editor preview alone does not validate that platform.

First-session checklist: known editor version, saved scene, visible interaction, repeatable preview, and a named initial build target. Use the [Cocos Creator 3.8 manual](https://docs.cocos.com/creator/3.8/manual/en/), accessed 2026-10-23, or the manual matching the project's actual version.

## 3. Export matrix

Snapshot: Cocos Creator 3.8, accessed 2026-10-23. Supported means listed by the official export documentation; not listed is treated as unsupported for selection, not physically impossible.

| Engine | WeChat mini-games | Douyin mini-games | Android | iOS | HarmonyOS/OpenHarmony | Windows/macOS/Linux | Web |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Cocos Creator 3.8 | Supported | Supported | Supported | Supported | Supported: including AppGallery Connect | Supported | Supported |

Official source: [Publishing overview](https://docs.cocos.com/creator/3.8/manual/en/editor/publish/index.html), accessed 2026-10-23. Additional listed mini-game routes include Facebook Instant Games, OPPO, vivo, Honor, and Huawei Quick Games. Native entries include iOS, Android, Huawei AppGallery Connect, Huawei HarmonyOS, Google Play, macOS, and Windows; Web includes mobile H5 and desktop Web.

Read the grouped cells as an index, not interchangeable platform implementations. HarmonyOS and AppGallery Connect are separate publishing paths; the grouping does not establish every OpenHarmony variant. The grouped desktop cell is retained, but the official publishing overview's detailed native list names macOS and Windows, not Linux. Native Linux export is not established by that list; evaluate desktop Web separately and verify the exact requested target before promising support.

## 4. Project-side docs boundary

The [version-matched Cocos manual](https://docs.cocos.com/creator/3.8/manual/en/) owns editor workflow, publishing setup, and scripting guidance; its matching API reference owns classes and signatures. Documentation accessed 2026-10-23. Shader syntax, version migration details, platform SDK versions, ad/payment APIs, and plugin configuration remain project-side or in their official vendor documentation.

No UrhoX-style combined documentation download and managed policy-update mechanism was established. Maintain selected official links or snapshots in project-owned `docs/engine/cocos-creator/`, recording editor version and retrieval date. Preserve project `settings/` and `assets/` under the project's version-control policy; use project `AGENTS.md` or external skill bindings to locate documentation and build instructions. Do not copy the entire manual into this package.

## 5. Working method

1. Detect the installed editor version, project metadata, language/native extensions, available build modules, and target SDKs. Match documentation to that version before changing configuration.
2. Choose the exact publishing path and artifact form. Record channel credentials and developer-tool prerequisites without putting secrets into shared project settings.
3. Build one playable scene and verify it in editor preview. Keep gameplay changes separate from target adapter and SDK integration so platform failures can be isolated.
4. Select the target in Build and complete its documented configuration. WeChat and Douyin need their channel-specific setup; do not assume a generic CLI build performs that setup automatically.
5. Build into an agreed artifact directory. Record the selected platform, editor version, configuration, and output so subsequent builds can reproduce the same route.
6. Open the result in the destination developer tool or install it on the target device. Verify startup, input, resource loading, lifecycle transitions, and the configured channel integrations. Record what passed and which targets remain untested; editor preview is only the first rung.

## 6. AI tooling

Detect the editor version, installed `cocos-cli`, its reported version/help, and existing client configuration before starting an integration. The official first-party entry is `cocos start-mcp-server`; resolve its project-path and port options from the installed version's help and [official cocos-cli commands documentation](https://github.com/cocos/cocos-cli/blob/main/docs/en/commands.md), accessed 2026-10-23.

When compatible tooling is present and local editor automation is intended, start that official entry against the actual project and inspect its exposed capabilities before invoking them. Confirm that it targets the expected editor/project rather than treating a running endpoint as sufficient evidence. Keep the selected CLI version and invocation in project documentation.

If the official entry is unavailable or incompatible, fall back to project-file editing, editor preview, and the documented build route. Record the missing automation capability; do not treat it as a reason to invent tool names or install a third-party replacement by default.

[1] Unofficial only: Cocos Store also lists third-party MCP integrations. They are not the first-party CLI entry, their versions were not verified as of 2026-10-23, and none is recommended here.

## 7. License snapshot

The editor is proprietary, with a royalty-free license for developing games/applications for target platforms; it is not MIT or Apache licensed. Source: [EDITOR license and terms, v3.8.9](https://github.com/cocos/cocos-engine/blob/v3.8.9/licenses/EDITOR_license_and_terms_en.txt), accessed 2026-10-23. Section 1.2 describes a limited, worldwide, royalty-free, non-assignable, revocable, non-exclusive grant from Xiamen Yaji Software Co., Ltd. Section 2.3 preserves the developer's rights in game products.

The [official free-use FAQ](https://www.cocos.com/en/post/de646eafb46fad3dd363e893401c2db9), accessed 2026-10-23, states free use with no royalty fees. The relevant cost snapshot is therefore no game-development royalty; do not invent a revenue threshold. Open engine source and a closed editor have different redistribution boundaries: source availability does not grant unrestricted redistribution of the engine/editor itself. Check the actual grant before redistributing any covered component.

The license source is tagged v3.8.9 while the [official releases list](https://github.com/cocos/cocos-engine/releases), accessed 2026-10-23, listed 3.8.8 as the latest stable release; the tag is a pinned terms source, not an instruction to upgrade or proof of the installed version's license. Verify-current-policy: terms change. Before adoption and release, re-read the linked terms and those shipped with the selected editor and dependencies, confirm applicability, and record the check date. Channel SDKs, assets, and services require their own license checks.

## 8. Common structural traps

- Combining mini-game SDKs or build settings from different channels and assuming a preview validates their coexistence.
- Treating HarmonyOS and AppGallery Connect as the same target or setup sequence.
- Assuming TypeScript gameplay and native C++ integrations have identical target surfaces.
- Reading a grouped desktop capability cell as proof of a native Linux exporter.
- Confusing the open engine source with an unrestricted license to redistribute the proprietary editor.
