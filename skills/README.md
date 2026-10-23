# Bundled professional Skills

These 69 professional Skills ship inside `orca-project-delivery` so workers resolve them from the package only (no global sibling fallback).

## Provenance

The original 16 delivery Skills were imported as a baseline and then adapted in this package. The 22 capability Skills added in version 2.3.0 and eight added in version 2.4.0 are original methods written for this package; the 2.4.0 enhancements are also original package content. They cite public specifications or documentation below; they are not copies of upstream Skill collections, and no upstream Skill license is restated as a license for those original methods.

| Field | Value |
| --- | --- |
| Original baseline repository | https://github.com/guanwenpeng2001-bot/orca-professional-skills |
| Original baseline commit | `d9a174c7143bfb4c76ed042f457fb7785c35cea3` |
| Baseline import date | 2026-10-09 |
| Baseline license | MIT — see `LICENSE` in this directory; it covers the original 16-Skill baseline, not third-party references |
| Capability methods added | 2026-10-09, version 2.3.0, 22 original package methods |
| Depth methods added | 2026-10-10, version 2.4.0, eight original package methods |

## Capability source record

| Skill | Method origin | Reference checked | Use in this package |
| --- | --- | --- | --- |
| `frontend-visual-design` | Original | W3C WCAG 2.2 contrast criteria | Criteria only; method text is original |
| `browser-e2e` | Original | W3C ARIA role model | Accessible locator terminology only |
| `accessibility-audit` | Original | W3C WCAG 2.2 | Named success criteria only |
| `postgres-practices` | Original | PostgreSQL EXPLAIN and row-security documentation | Database behavior reference only |
| `observability` | Original | OpenTelemetry specification | Correlation and attribute guidance only |
| `ci-pipeline` | Original | NIST SP 800-218 | Reproducible pipeline concept only |
| `react-performance` | Original | React rendering and lazy documentation | Public API guidance; no vendor Skill copied |
| `react-composition` | Original | React component-props documentation | Public API guidance; no vendor Skill copied |
| `icon-assets` | Original | W3C image-alternative guidance | Accessibility decision reference only |
| `svg-logo-design` | Original | W3C SVG 2 | Coordinate and shape reference only |
| `web-assets` | Original | W3C app-manifest icon member | Manifest field reference only |
| `image-compression` | Original | W3C PNG specification | Chunk structure reference only |
| `image-generation` | Original example connector | OpenAI OpenAPI retrieved 2026-10-09 | Gated fetch execution tested with synthetic injected transport; no live call |
| `infographic-design` | Original | Edward Tufte; WCAG 2.2 contrast | Quantitative-display principle only |
| `editorial-illustration` | Original | NPPA Code of Ethics | Misleading-image principle only |
| `visual-slide-deck` | Original | WCAG 2.2 contrast | Readability criterion only |
| `code-video-production` | Original | HyperFrames commit `46f6cb356785bed79e1ce7b79d7e7accc697786a`, Apache-2.0 | Local HTML-to-video path; software not vendored |
| `generated-video` | Original example connector | Pexo scripts at `f724267e45a065b6be445ea6f07312e62d3207cd` | Bearer/SSE/status/history/download contract; injected transport tested, scripts not copied |
| `speech-production` | Original example connector | ElevenLabs speech API inspected 2026-10-09 | Gated fetch execution tested with synthetic injected transport; no live call |
| `audio-transcription` | Original example connector | ElevenLabs transcription API inspected 2026-10-09 | Gated fetch execution tested with synthetic injected transport; no live call |
| `media-transcoding` | Original | FFmpeg public option documentation | Option names only; no FFmpeg build vendored |
| `document-production` | Original | CommonMark; python-docx 1.2.0 / python-pptx 1.0.2 / openpyxl 3.1.5 (MIT); ReportLab 5.0.1 / pypdf 6.20.0 (BSD-3-Clause) | Independently written generation/read-back examples; dependencies installed separately, no proprietary Skill copied |
| `design-system` | Original | W3C WCAG 2.2 criteria 1.4.3 and 1.4.11 | Contrast thresholds only; token and component method is original |
| `domain-modeling` | Original | Package `database-design` and `solution-architecture` boundaries | Original aggregate and invariant example; no upstream Skill copied |
| `migration-upgrade` | Original | Package `database-design` boundary | Original compatibility-window and expand/contract example |
| `skill-authoring-evaluation` | Original | Package `templates/skill-authoring.md` registration checklist | Original triggering and outcome rubric; no agent experiment claimed |
| `mcp-server-development` | Original | MCP 2025-11-25 specification; JSON-RPC 2.0 | Protocol shapes and offline fixture checks; no server scaffold or upstream Skill copied |
| `technical-diagrams` | Original | SVG semantics and package-owned SVG examples | Editable-source and semantic checks; no renderer vendored |
| `localization` | Original | ICU message syntax and Unicode direction isolates | Placeholder and plural examples with offline consistency checks; no translation service |
| `subtitle-production` | Original | Public SRT layout; W3C WebVTT cue structure | Independently written local converter; no upstream Skill text copied |

## Game-family provenance (3.1.0)

The 23 game Skills use original package prose. External collections supply method references, not copied files, code, hooks or orchestration. Source reading establishes provenance, not successful gameplay, engine export, billing or publication. Repository licenses below apply to their source material; they do not grant rights to game assets or replace platform agreements.

Reference keys used in the per-Skill table:

- G: `gamedev-skills/awesome-gamedev-agent-skills`, SHA `38a4c2500eeb5ff9ac084336b8f66108069d2f8d`, Apache-2.0; LICENSE and root NOTICE were read by the design worker.
- H: `horn111/web-game-ad-skills`, SHA `6a482b9683b7082036337bf66ffeb973013500de`, MIT.
- R: `rondorkerin/gamestack`, SHA `0419358df31455e63820bdd89f3c5b446665f604`, MIT.
- S: `scenario-labs/skills`, SHA `5429dea302ccc7edbce8ace9d5c1fb6852499540`, MIT.
- D: `Donchitos/Claude-Code-Game-Studios`, SHA `05ad7c8a5b8aa2aa86bbd3439ae7cf7295cac418`, MIT.
- P: `pollocrudocompany/gamedev-claude-skills`, SHA `3811dcbc6e5dc28265ac1358d5d78bf78a9835b3`, MIT.

Design, engineering and production workers read their pinned repository references on 2026-10-23. Release methods inherit the scouts' pinned evidence; engine methods use official dated documentation and license snapshots. Engine repository links on main/master are explicitly not SHA-pinned: no SHA was supplied and none is inferred. The individual Skills carry source URLs and verification status; recheck moving policy and license pages for each project release.

| Skill | Method origin | References checked | Use in package |
| --- | --- | --- | --- |
| `game-design` | Original synthesis | G: nine genre entries and game-ui-ux | Rules, decisions, feedback and progression hypotheses |
| `game-economy-design` | Original synthesis | H: virtual-economy-review; R: difficulty-and-balancing | Source/sink/stock, currency-count guidance, uncertain ad issuance; scoped 80% dominance heuristic |
| `game-level-design` | Original synthesis | G: level-design; H: level-design-difficulty-curve | Movement metrics, blockout, gate reachability, 0.70/0.95 gap factors and contextual failure bands |
| `game-3c-design` | Original package method | No external 3C source; SHA/license not applicable | Coupled Character/Controller/Camera contracts and observable hypotheses |
| `gameplay-programming` | Original method rewrite | G: ai-behavior-trees-utility-ai, input-systems, save-systems | Decision structures, action abstraction, input grace/buffer semantics and save migration |
| `game-physics` | Original method rewrite | G: physics-tuning | Simulation timing, interpolation, CCD and contact/filter diagnosis |
| `game-content-pipeline` | Original package method | G: procedural-gen and create-game-assets, reference only | Stable identity, incremental conversion and compatible activation; source references constrain randomness and asset validation |
| `game-performance` | Original method rewrite | G: performance-optimization | Measure/classify/change one bottleneck/remeasure and budget checks |
| `game-multiplayer` | Original package method | No external multiplayer source; SHA/license not applicable | Authority, synchronization, prediction/reconciliation and fault tests |
| `game-asset-pipeline` | Original synthesis | G: create-game-assets; S: scenario-game-assets; D: balance-check and launch-checklist criteria (missing-data, unset-versus-none) | Asset production loop, identity/revision checks, missing-data refusal and unset-versus-none distinction |
| `game-audio` | Original method rewrite | G: audio-design and adaptive-music; D: missing-data criterion | Mixing graph, gain, ducking, adaptive music and timing; no vendor operations |
| `game-testing-ladders` | Original package ladder | D: regression-suite, balance-check, launch-checklist | Missing-data/explicit-none criteria and curated regressions; ladder and physical-device separation are local synthesis |
| `engine-web-canvas` | Original package method | phaserjs/phaser (MIT), docs.phaser.io, phaser.io; package 4.2.1 and 2026-10-23 snapshot, no SHA supplied | Browser/wrapper/cloud boundaries and platform/license facts; commercial terms separate |
| `engine-godot` | Original package method | godotengine/godot and godot-proposals, official 4.7 docs and MIT license; 2026-10-23 snapshot, no SHA supplied | Export constraints, project docs and absence of first-party MCP; unofficial routes remain qualified |
| `engine-cocos-creator` | Original package method | cocos/cocos-engine editor terms at v3.8.9, cocos/cocos-cli, official 3.8 docs; 2026-10-23 snapshot, no SHA supplied | Proprietary royalty-free editor terms, platform and tooling boundaries |
| `engine-unity` | Original package method | Unity 6/6000.0 and Tuanjie 1.10 manuals; Unity pricing; Tuanjie terms effective 2026-08-14 and Package Distribution License v1.0; 2026-10-23 capture, SHA not applicable | Separate global/Tuanjie matrices and proprietary terms; preserve threshold conflicts for recheck |
| `engine-unreal` | Original package method | Epic packaging/streaming docs, UE 5.8 tooling and EULA 18.1; 2026-10-23 snapshot, SHA not applicable | Native packaging versus streaming, experimental tooling and proprietary royalty conditions |
| `engine-urhox` | Original package method | taptap/instant-games-open-mcp docs and urho3d/urho3d MIT reference (moving branches, no SHA supplied); Maker agreement effective 2026-01-30 and Workshop agreement effective 2026-03-11, captured 2026-10-23 | Project-pulled docs, preview layers, MCP build boundary and separate proprietary platform grants/export limits |
| `game-publishing` | Original synthesis | D and G via scout; official platform documentation and Workshop agreement snapshot dated 2026-10-23 | Decision/missing-decision criteria, parallel listing/build readiness and per-release policy checks; unresolved platform facts remain explicit |
| `game-build-release` | Original package method | D via scout; MIT, pinned above | Task-required reproducibility, candidate and bounded patch/QA/recovery concepts; no upstream workflow imported |
| `game-live-ops` | Original package method | D via scout; MIT, pinned above | Task-required cadence/event concepts, cohort/economy observation and recovery; no agent shell imported |
| `game-monetization-iaa` | Original synthesis | H and P via scout, pinned above | Intent/timing, variable rewarded issuance and economy-derived sizing; timing constraints are design assumptions |
| `game-monetization-iap` | Original package method | P via scout, reference only, pinned above | Catalog skeleton; fulfillment/accounting method original and illustrative pricing explicitly unverified and project-calibrated |

No optional connector is selected as the user's production provider by being present here. `CAPABILITY_ONLINE_PROVIDERS_ENABLED=false` in the example project configuration keeps live calls unauthorized.
