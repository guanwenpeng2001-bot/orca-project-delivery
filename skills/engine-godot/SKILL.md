---
name: engine-godot
description: Select and verify Godot projects using version-matched documentation, export presets, and explicit platform and tooling limits. Use when building, previewing, or exporting a Godot game.
---

# Godot Engine

## 1. When to use / When not to use

Use for independent projects that value MIT licensing and a scene-based workflow across desktop, mobile, and Web. GDScript is the primary language; C# is an official alternative with a distinct toolchain and target constraints.

Veto the proposed path when the required channel is unsupported, licensing requirements conflict with the chosen dependencies or distribution arrangement, or the necessary editor/export toolchain is unavailable. WeChat, Douyin, and HarmonyOS have no official export route in this snapshot. A console requirement needs a separately established publisher/provider route; do not promise an official console export from this matrix.

## 2. Novice orientation

A project holds scenes and resources; a scene is a tree of objects. Running the main scene provides the first preview. An export preset describes a deliverable for a particular platform.

1. Obtain the project-approved editor version. For a first GDScript project, use the standard editor; select the .NET edition and required workloads only when choosing C#.
2. In the Project Manager, create a project in an empty directory. Record the renderer choice against the target device and name the project.
3. Create and save one scene containing visible content, designate it as the main scene, and add one input-driven behavior using the version-matched beginner manual.
4. Run the project from the editor. Confirm visible content, input response, and a clean debugger; stop and restart to establish a repeatable first preview.
5. Save `project.godot`, scene/resource sources, and the selected editor version. Add export templates and a target preset when moving from preview to an exported build.

First-session checklist: a saved main scene, one visible interaction, a repeatable run, and a known language/editor edition. Begin at the [versioned Godot manual](https://docs.godotengine.org/en/4.7/), snapshot accessed 2026-10-23; use the manual matching the installed version instead of blindly following `stable`.

## 3. Export matrix

Snapshot: Godot 4.7, accessed 2026-10-23. Supported means listed by the official export documentation. Not listed is treated as unsupported for selection, not physically impossible.

| Engine | WeChat mini-games | Douyin mini-games | Android | iOS | HarmonyOS/OpenHarmony | Windows/macOS/Linux | Web |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Godot 4.7 | Not listed [1] | Not listed [1] | Supported | Supported | Not listed [2] | Supported | Supported |

Official sources, both accessed 2026-10-23: [Exporting projects](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html) and [Godot FAQ](https://docs.godotengine.org/en/4.7/about/faq.html). The detailed list includes Windows, macOS, Linux/*BSD, Android, iOS, and Web. This engine-level matrix is not a guarantee for every language, renderer, host OS, or engine version; verify the chosen combination before committing to it.

[1] Unofficial community mini-game adaptations exist; the [mini-game discussion](https://github.com/godotengine/godot-proposals/discussions/10947), accessed 2026-10-23, does not establish official export support. No community adapter is recommended here.

[2] Unofficial community work only: [HarmonyOS PR #108553](https://github.com/godotengine/godot/pull/108553) was unmerged as of 2026-10-23. It is not an official export capability.

## 4. Project-side docs boundary

The version-matched [Godot manual and class reference](https://docs.godotengine.org/en/4.7/) own API signatures, shader syntax, renderer limitations, migration steps, and platform-specific export instructions. Documentation snapshot accessed 2026-10-23. Platform SDK and signing instructions stay with the project's target-platform documentation.

No UrhoX-style bundled documentation download and managed policy-update mechanism was established. Maintain selected links or snapshots under project-owned `docs/engine/godot/` with version and retrieval date; point project `AGENTS.md` or external skill bindings there. Keep required `addons/` and non-secret export presets in version control under the project's rules. Never turn this package into a copy of the class reference.

## 5. Working method

1. Detect the project version, installed editor and edition, language, renderer, plugins, export templates, and target SDK availability. Do not silently migrate an existing project to the currently installed editor.
2. Choose a supported platform/language/renderer combination and define the first playable scene plus measurable acceptance behavior.
3. Build the smallest scene-based slice and run it in the editor. Check scene ownership, startup state, resource loading, input, and reset behavior before expanding it.
4. Install matching export templates and configure the target preset using the version-matched export manual. Separate credentials from shareable preset configuration.
5. Export through the editor or its documented CLI/headless path. Record the exact project command and artifact path rather than embedding a version-specific invocation in this skill.
6. Run the exported artifact on the target device or browser. Verify startup, input, assets, and lifecycle behavior independently of the editor preview. Record version, preset, environment, results, and untested combinations.

## 6. AI tooling

There is no first-party Godot MCP in the 2026-10-23 snapshot. The official proposals were closed: [AI assistant proposal #12409](https://github.com/godotengine/godot-proposals/issues/12409) was closed as not planned, and [official ACP/MCP discussion #14918](https://github.com/godotengine/godot-proposals/discussions/14918) was closed as a duplicate. Both sources accessed 2026-10-23. Recheck their current status before claiming a newly official entry.

Detect the editor version, project addons, configured client integrations, and installed export tools first. If an existing project mentions an MCP integration, inspect its package provenance, compatibility, permissions, and license; an Asset Library listing does not make it first-party. If researching such a listing is required, search the library and verify its publisher against the actual source before deciding anything. Do not install or recommend a third-party plugin as the default route.

The supported degradation path is direct project-file editing plus editor preview and the version-matched engine CLI/headless export workflow. Report unavailable editor automation explicitly; a successful file edit or headless export does not establish interactive gameplay correctness.

## 7. License snapshot

Godot is MIT licensed. Source: [Godot license](https://godotengine.org/license/), accessed 2026-10-23. Copyright notices cover 2014-present Godot Engine contributors and 2007-2014 Juan Linietsky and Ariel Manzur. MIT imposes no engine royalty or revenue threshold; redistribution of covered software requires the copyright and permission notices.

The game's own content is not forced under MIT by using Godot. Include the applicable engine and third-party notices with distribution; the engine's MIT license does not replace asset or addon licenses. This snapshot concerns the engine, not a separate console-provider agreement.

Verify-current-policy: terms and bundled components change. Before adoption and release, re-read the official license page and the licenses shipped with the selected editor, addons, and assets; record the versions and check date.

## 8. Common structural traps

- Treating Web export as compatibility with a mini-game runtime.
- Assuming the engine-wide platform matrix applies unchanged to C#; verify .NET workloads and that version's export restrictions first.
- Opening a Godot 3 project in Godot 4 as though it were a routine interchangeable editor choice.
- Mixing editor and export-template versions, then blaming application code for packaging failures.
- Mistaking a successful editor run or headless build for a tested exported game.
