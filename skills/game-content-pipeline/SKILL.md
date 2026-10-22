---
name: game-content-pipeline
description: Define reproducible conversion from authored game content to compatible runtime data with stable identity and incremental updates. Use when building import rules, content catalogs, generated levels, or content update validation.
---

# Game Content Pipeline

## 1. When to use / When not to use

Use when authored files must become runtime content reliably, renames break references, incremental imports leave stale results, or a content update must remain compatible with existing builds and saves.

Do not use this method to create an art style, generate production artwork, operate an engine importer, or publish a remote update. Asset creation belongs with game-asset-pipeline; executable build and distribution operations belong to project-owned release guidance. Do not promise compatibility without a declared consumer-version matrix.

## 2. Novice orientation

A content pipeline converts editable source material into what a game loads. Source may be a drawing, a sound, a spreadsheet of items, or rules for generating a level. Converted files are derived outputs; editing them alone loses the change on the next conversion.

Start with one item, one image it references, and one small scene that displays it. Write a record containing an immutable item ID, source location, import settings, expected dimensions or fields, and supported game build. Use the project's existing conversion instructions, inspect the item in the scene, then rename its source file and repeat. The item must retain its identity and reference. Change one property and check that the new value arrives without unrelated content changing.

First-session checklist:

- Locate the editable source and identify who owns it.
- Record one stable ID and its dependent references.
- Specify one import rule and one rejected input.
- Compare a clean conversion with the incremental result.

Terms: **import** converts source to runtime form; a **stable ID** identifies content across renames; a **dependency** is another input needed to produce an output; **incremental conversion** rebuilds affected outputs only; a **manifest** lists content and compatibility information; **schema** defines a record's fields and meaning.

## 3. Core method

### Describe the authoring-to-runtime contract

For each content class, define editable format, units, coordinate/pivot conventions, color or audio interpretation where relevant, required fields, output format, and runtime budget. Assign ownership of source, converter, and consumer. Preserve provenance and license restrictions alongside the source record. Separate placeholders from accepted content so missing production assets cannot pass unnoticed.

Make import settings explicit and versioned with the source. Reject an invalid input before replacing a usable output, with a diagnostic naming the source and violated constraint. Preview representative output in its gameplay context; a successful conversion does not prove readable art or correct collision scale.

### Separate identity from storage location

Use persistent content IDs rather than file paths or display names as references. Obtain engine-managed IDs through project-native tooling; never fabricate their metadata. Preserve identity on move/rename, allocate a new identity on intentional duplication, and validate uniqueness and reference resolution. For removal, declare replacement, migration, or explicit unsupported status for existing saves and dependents. Do not silently reuse a retired ID for unrelated content.

### Make incremental work explainable

Track dependencies between sources, import settings, converter version, and outputs. A change invalidates affected outputs and their dependent consumers. A no-op run should leave runtime meaning unchanged. Compare incremental results with a clean conversion to detect missing dependency edges and stale artifacts; exclude only documented nondeterministic metadata from the comparison.

For generated content, record seed, generator version, settings, and required input versions. A seed alone does not promise the same world after an algorithm change. Validate generated structure, such as reachable exits, before accepting it, and bound generation attempts so invalid content cannot hang a build.

### Make compatibility and update failure explicit

Define which runtime builds understand each content schema and which save versions reference it. Test supported pairs and reject unsupported pairs before replacing active content. Stage a complete candidate set, validate its references and compatibility, then use the project's activation mechanism to expose a consistent set. Retain a compatible previous set for recovery; a partial update must not mix dependent records from incompatible versions.

Test interruption during conversion and activation, deletion and rename, duplicate IDs, missing dependencies, and a converter-version change. Keep this as a content contract: actual download, packaging, signing, and activation operations belong to the project.

## 4. Failure criteria and measurable invariants

- The accepted content set contains zero duplicate stable IDs and zero unresolved required references.
- Renaming the sample source preserves its ID and all intended references; duplicating it yields a distinct identity.
- For the declared source set, incremental and clean conversions produce equivalent runtime records under a documented comparison.
- Every supported runtime/content pair loads the sample correctly; unsupported pairs are refused before activation.
- Interrupted activation leaves either the prior compatible set or the complete new compatible set accessible, never a mixed set.

If there is no source inventory, import specification, or supported-version list, report **not assessed** for completeness or compatibility and list the missing inputs. Passing a converter exit code cannot substitute for inspecting output and loading it in a supported runtime. Budgets must come from the project; this method supplies no universal size or update-duration target.

## 5. Platform/engine boundary

Project-side AGENTS.md, externalSkills, and roleBindings own importer APIs, resource metadata and ID creation, packaging, build dependencies, remote delivery, signing, and activation facilities. Content authors own editable sources; the implementation owner owns conversion and reference integrity; the release owner owns distribution and rollback policy. Engine and platform documentation supply operational instructions outside this method.

## 6. Sources and verification status

This is an original method assembled for this package; no engine-neutral upstream content-pipeline procedure was established. Two constraint references were read on 2026-10-23 from gamedev-skills/awesome-gamedev-agent-skills at `38a4c2500eeb5ff9ac084336b8f66108069d2f8d` (Apache-2.0):

- [Procedural generation](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/38a4c2500eeb5ff9ac084336b8f66108069d2f8d/skills/disciplines/procedural-gen/SKILL.md): controlled randomness, data-before-rendering, structural validation.
- [Asset creation](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/38a4c2500eeb5ff9ac084336b8f66108069d2f8d/skills/disciplines/create-game-assets/SKILL.md): explicit technical constraints, provenance, and in-context inspection.

Verified: those references describe the listed constraints. Stable identity, dependency invalidation, and compatibility procedures above are original engineering recommendations, not externally validated results. No project import or update was exercised. Verify-current-policy before use: confirm source rights, installed importer version, metadata ownership, supported runtime/content combinations, and distribution restrictions in project-owned guidance.
