---
name: game-asset-pipeline
description: Plan and validate game assets from type selection through generation or import, postprocessing, and engine intake while preserving identity and provenance. Use when producing, replacing, or accepting a game asset family.
---

# Game Asset Pipeline

## 1. When to use / When not to use

Use for sprites, tiles, icons, meshes, materials, animation, or audio files whose production must end in a usable game resource. Apply the same acceptance contract to generated, commissioned, purchased, and existing assets.

Do not use this method to choose gameplay rules or define an entire content database. Route those decisions to game design or content-pipeline methods. Engine import commands and generation-service operations belong to project-side instructions. If rights, target dimensions, or intended use are unknown, a draft can be prepared but production acceptance is blocked.

## 2. Novice orientation

An asset is a file the game consumes, such as a character image. The pipeline turns its editable source into a tested runtime resource. A good-looking preview is only an intermediate result.

Start with one collectible icon, not a whole art set:

1. Find the game's existing asset folder and a screen where the icon will appear. Record the slot size and background. If neither exists, make a clearly labeled draft contract and defer engine acceptance.
2. Give the icon a logical name such as `collectible.health`. Record its purpose, required dimensions, transparency, source rights, and intended import settings in the project's existing asset record.
3. Author or obtain one candidate. Preserve the original separately from the processed export.
4. Resize and clean the candidate to the contract; inspect its transparent edges against both light and dark backgrounds at actual display size.
5. Import using the project's engine instructions, place it in that slot, and capture whether it remains legible. Replace it once and confirm that the same game reference still resolves.

First-session checklist: one asset record, one editable source, one processed export, one in-game observation, and an explicit accepted/draft/rejected decision. An unavailable engine leaves the last check unassessed.

| Term | Meaning |
| --- | --- |
| Logical ID | The persistent identity used to refer to an asset, independent of filename or revision |
| Source | The editable or originally obtained input retained for future changes |
| Postprocess | Measurable cleanup such as sizing, trimming, encoding, or mesh reduction |
| Pivot | The anchor around which an image or object is placed and rotated |
| Intake | Importing and checking the export in its actual engine context |
| Revision | A particular saved version of the source, processing recipe, and export |

## 3. Core method

### Define the contract before choosing a production route

List the asset type, gameplay role, camera/view, style reference, variants, dimensions or world units, pivot convention, runtime budget, target contexts, and rights constraints. Choose an authoring, generation, or acquisition route that can meet these requirements. If generation is appropriate, choose the model by required output capabilities rather than by popularity; inspect its supported inputs before spending a batch budget.

Use explicit decisions for optional features. `animation: none` means a still image was selected; a missing animation field means nobody has settled the requirement. Keep that distinction in the acceptance record.

### Run a small loop before batch production

1. **Type and capability:** select one representative asset and its required outputs, including any alpha channel, rig, loop, or material dependencies.
2. **Generation or import:** produce or acquire the source with its rights record and production settings. Retain enough information to revise it; a random seed alone does not guarantee reproducibility across generator versions.
3. **Postprocess:** apply a recorded recipe to a separate export. Repair dimensions, alignment, alpha, seams, color space, scale, topology, or encoding as the type requires.
4. **Engine intake:** import with the target project's settings and observe the resource at actual scale, in motion where applicable, with its real neighbors.
5. **Decision and iteration:** compare measurements with the contract. Fix the earliest stage responsible for a mismatch, then regenerate downstream exports. Expand to a family only after the representative passes.

| Type | Checks before accepting the family |
| --- | --- |
| Sprite or icon | Exact canvas dimensions; correct alpha; stable pivot; silhouette readable in the intended slot |
| Tile | Intended neighboring edges join in a repeated test patch; no visible seam at target filtering and scale |
| Mesh or material | Units, bounds, normals, UVs, material dependencies, and geometry/texture budgets fit the runtime context |
| Animation | Required frames or clips exist; anchors remain stable; transitions and loops work during playback |
| Audio | Duration, channel layout, encoding, and loop points fit intake requirements; listening and mixing proceed under game-audio |

### Preserve identity across revisions

Allocate the logical ID once. Store the engine's assigned reference alongside it using the engine's own metadata mechanism; never fabricate or casually regenerate an engine identifier. A filename move or compatible visual refresh retains the logical ID. A different semantic asset receives a new ID.

Version the source, processing recipe, export, and required import settings together. Record which source revision produced each export. A pivot, dimensions, rig, or material-interface change can break consumers even when the logical ID stays stable: either migrate and retest all affected consumers or introduce a new identity with an explicit mapping. Retain a known working revision for rollback.

For replacement, list scenes and data records that consume the asset, replace through the supported import path, and rerun their intake checks. Removed assets need a consumer check before deletion. An export with missing dependencies must not replace the working version.

## 4. Failure criteria and measurable invariants

Define thresholds in the project contract before inspection; illustrative dimensions are not universal requirements.

- Every accepted logical ID resolves to exactly one intended active revision; duplicate IDs and unresolved consumer references must both count zero.
- Required dimensions, frame counts, and dependency counts match the declared contract exactly. Runtime bytes or resident memory stay at or below the declared budget, measured after engine conversion.
- A compatible replacement retains the same logical and engine references. Consumer checks must demonstrate the replacement and rollback, not merely find the files on disk.
- Each accepted export has a source revision, processing recipe, and rights record. A generated preview without these is a candidate, not an accepted asset.
- If a required input or measurement is missing, return `NOT ASSESSED - NO DATA` for that check and list the missing input and the next observation needed. Do not issue an overall production-ready verdict while any required check is unassessed. Known defects remain visible as failures even when other checks lack data.

Evaluation scenario: replace an icon while preserving its ID, then supply an export with a shifted pivot and no rights record. The first case must retain consumer references; the second must expose the measured pivot violation and refuse rights clearance. A blank rights field must not be treated as a decision that no restrictions apply.

## 5. Platform/engine boundary

Use the project's `AGENTS.md`, `externalSkills`, or `roleBindings` to locate the active engine importer, asset-authoring tools, and service documentation. They own API names, authentication, generation calls, import settings syntax, metadata allocation, and export commands. This skill supplies the acceptance contract and observations to hand them; it does not install tools or authorize paid generation, publishing, broader scope, or branch integration.

## 6. Sources and verification status

Sources consulted on 2026-10-23; original prose and independently organized workflow, with no upstream files or scripts incorporated:

- Pattern reference: [asset production discipline](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/38a4c2500eeb5ff9ac084336b8f66108069d2f8d/skills/disciplines/create-game-assets/SKILL.md), Apache-2.0. Source inspection verified its production-constraint and in-context validation approach.
- Pattern reference only: [asset production source](https://github.com/scenario-labs/skills/tree/5429dea302ccc7edbce8ace9d5c1fb6852499540), MIT. Only the type/capability, production, cleanup, and export sequence informed this method; no vendor operations are carried over.
- Judgment criteria reference: [assessment source](https://github.com/Donchitos/Claude-Code-Game-Studios/tree/05ad7c8a5b8aa2aa86bbd3439ae7cf7295cac418), MIT. Only missing-data refusal and the distinction between an absent decision and an explicit none informed the checks.

Verification status: the references were inspected as text. Stable-ID, revision, and rollback rules are local method design; their effectiveness in a specific engine has not been demonstrated by that reading. Require project intake evidence before claiming a working pipeline.

Verify-current-policy checklist: recheck source terms before reuse, the rights of each actual input asset before distribution, and the installed engine's current import/metadata documentation before replacement. Repository licenses do not establish the rights of assets generated or acquired separately.
