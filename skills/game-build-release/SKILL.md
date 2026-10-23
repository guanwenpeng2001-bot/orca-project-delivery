---
name: game-build-release
description: Define reproducible game builds, release candidates, gold masters, patches, and rollback decisions across engines. Use when preparing a game build or planning a release update.
---

# Game Build and Release

## 1. When to use / When not to use

Use for a release candidate, a platform build matrix, or a patch after content freeze. Do not use this method to choose an engine, execute a store submission, or justify releasing a build that has not passed QA. Build success alone is not release readiness; pair this with game-publishing.

## 2. Novice orientation

A build turns source code and assets into something a player can install or open. A release is the decision to deliver a particular build to a particular audience. A release candidate is a build proposed for that decision; the gold master is the approved baseline frozen for launch.

For a first session:

1. Write down the target device, operating system, engine version, and smallest playable journey (start, play, save, exit, resume).
2. Identify the source revision and the assets/configuration needed to build it. Ask the project owner for missing signing access; never place secrets in the release notes.
3. Use the matching engine-* skill to produce a test build and run that journey on a target device.
4. Record the build identifier, observed result, and one next action. Do not label an editor preview as a tested distribution package.

Terms: an artifact is the produced package; a dependency is an input supplied by another component; signing establishes the publisher identity; rollback restores a known usable release; a migration transforms saved or server data.

## 3. Core method

### Define reproducibility before building

Record source revision, asset versions, dependency lockfiles, engine/editor and SDK versions, build host requirements, target architecture, configuration, content variants, and the signing identity reference. Exclude credentials themselves. Start from a clean environment with those inputs and document the build procedure through the engine-specific pointer.

A reproducible build produces equivalent deliverable contents from the same declared inputs. Declare whether the project promises byte-identical output or functionally equivalent output with known differences such as signing timestamps; never claim byte reproducibility from a successful smoke test. Rebuild once independently, compare against the declared equivalence rule, and investigate unexplained differences.

### Version and candidate discipline

Give each candidate a unique build identifier and associate its player-facing version, source revision, content version, supported save schema, and backend compatibility. Do not silently replace a tested candidate's contents. A changed candidate receives a new identity and relevant QA. A changelog describes actual player-visible changes, known issues, compatibility, and recovery implications; it must agree with the candidate.

Run smoke, changed-feature, regression, and platform/device checks selected with game-testing-ladders. Test both clean installation and upgrade from the supported previous release, including existing saves and interrupted updates. Freeze the gold master only after the required checks pass. Record excluded issues with impact and a decision owner.

### Gold master and day-one patch

Keep the gold master immutable. A day-one patch is a tightly bounded correction to that baseline, not a second feature milestone. Admit only P1/P2 issues that are safe and fast to fix within the patch window. Establish the project's severity definitions first: a label alone does not prove urgency. For each candidate fix record player impact, smallest change, affected systems, expected test time, and rollback feasibility.

Defer new features, broad refactors, speculative optimizations, and fixes whose safety or QA cannot fit the window. A more severe incident requires an explicit launch stop or separate emergency decision; it must not be smuggled into the limited patch queue. Every accepted fix needs reproduction, regression coverage, relevant device checks, and a QA decision on the actual patch artifact.

### Rollout and recovery

Define rollout audience, observation window, owner, and project-specific stop thresholds before release. Verify that the previous artifact is available and that saves, backend state, and content remain compatible. If a migration cannot be reversed, specify a tested forward-recovery path instead of promising a binary rollback. Exercise recovery in a test environment; record time to recovery and unresolved incompatibilities. Handoff the approved candidate and recovery decision to game-publishing and game-live-ops.

## 4. Failure criteria and measurable invariants

- Missing build inputs or an untested rebuild means `NOT ASSESSED — NO DATA` for reproducibility, not pass.
- Every shipped candidate has exactly one recorded identity and a matching QA result; any content change invalidates that result for affected checks.
- All supported upgrade paths selected in the release matrix pass save/load checks; unexplained data loss blocks release.
- Every day-one patch item meets the severity, safe/fast scope, QA, and recovery conditions. One unmet condition excludes that item.
- Recovery completes within the project's declared recovery budget in rehearsal. Missing budget or rehearsal means recovery readiness is unassessed.

Evaluation: if a candidate passes clean install but corrupts an existing save, reject release readiness. If two clean builds differ only in declared signing metadata, report functional equivalence and leave byte reproducibility unproven.

## 5. Platform/engine boundary

Use engine-unity, engine-godot, engine-unreal, engine-cocos-creator, engine-web-canvas, or engine-urhox for engine-specific build paths. SDK invocation, signing commands, console credentials, CI flags, and store promotion belong to project-side documentation and official platform skills. This method defines the inputs, acceptance, and recovery decision; it does not execute publication or authorize it.

## 6. Sources and verification status

Original method prose, prepared 2026-10-23. Reference: [Donchitos/Claude-Code-Game-Studios](https://github.com/Donchitos/Claude-Code-Game-Studios), commit `05ad7c8a5b8aa2aa86bbd3439ae7cf7295cac418`, MIT, day-one-patch and release-checklist concepts as summarized in the dated methods reconnaissance. The narrow P1/P2 patch scope, QA gate, and recovery discipline are method references, not copied implementation. No upstream hooks, agents, configuration shell, or automation modes are included.

Reproducibility, version identity, and compatibility checks are project methods, not claims of an engine guarantee. Actual build performance and recovery results remain unverified until measured in the target project. Platform signing, SDK requirements, and review policy are `verify-current-policy` for every release.
