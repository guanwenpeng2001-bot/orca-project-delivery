# Professional Skills

**English** | [简体中文](zh-CN/professional-skills.md)

Orca Project Delivery coordinates workers that load **professional Skills** —
method-only instruction packs (`SKILL.md`) for reconnaissance, product work,
architecture, implementation, review, and verification, plus methods for
software delivery, local assets, images, and audio, video, and documents.
All thirty-eight Skills ship **inside this package** under
`skills/<skill-id>/SKILL.md`.

## Upstream sources

Provenance is recorded **per Skill** in `skills/README.md`: upstream
repository, pinned commit, license, and the license file shipped beside the
Skill. There is no single upstream for the package.

| Group | Source | License |
| --- | --- | --- |
| The original sixteen | [orca-professional-skills](https://github.com/guanwenpeng2001-bot/orca-professional-skills) at `d9a174c7143bfb4c76ed042f457fb7785c35cea3`, then maintained in this package | MIT — `skills/LICENSE`, plus the project MIT `LICENSE` |
| Software, asset, image, audio, and video methods added in 2.3.0 | One pinned upstream per Skill, listed in `skills/README.md` | The upstream's own license, copied to `skills/<id>/LICENSE.txt`. Apache-2.0 stays Apache-2.0 |
| `document-production`, `media-transcoding` | Written in this project; no upstream text copied | Project MIT |

This project's MIT license covers its original work only. It does not relicense
third-party material. Two upstreams are intentionally absent: the Anthropic
docx, pptx, pdf, and xlsx Skills are proprietary and are not copied, and
OpenMontage (AGPL-3.0) is not copied. The rules and the per-capability status
are in [Professional capabilities](professional-capabilities.md).

The recorded commit is the upstream baseline for the original sixteen. Their
current bodies are package-maintained MIT adaptations, enriched with domain
methods, decision criteria, worked examples, failure signals and evaluation
scenarios. Edit any Skill deliberately in place and recompute its current
content SHA256 row in `skills/README.md`; retain the unchanged upstream MIT
notice in `skills/LICENSE` and each Skill's own `LICENSE.txt`. The hashes
track today's adaptations, not byte-identical upstream copies. See
[Extending](extending.md) for authoring, registration and validation.

## The original sixteen

Paths in `routing/skill-catalog.json` are relative to this package and resolve as
`skills/<skill-id>/SKILL.md` under the package root.

| Skill ID | Purpose |
| --- | --- |
| `codebase-reconnaissance` | Inspect code, branch, history, configuration, and tests for scoped factual questions without modifying source. |
| `technical-research` | Research technical behavior from primary sources, code, standards, and reproducible experiments. |
| `product-discovery` | Turn vague product intent into problem, users, outcomes, scope, non-goals, and acceptance direction. |
| `product-design` | Design flows, information architecture, interaction states, accessibility, and testable UX acceptance. |
| `requirements-analysis` | Produce traceable, testable functional and non-functional requirements from objectives and evidence. |
| `solution-architecture` | Design boundaries, interfaces, data flow, migration, rollback, and operational behavior for scoped changes. |
| `api-design` | Design HTTP/RPC/event/CLI/module contracts with validation, errors, idempotency, auth, and compatibility. |
| `database-design` | Design models, constraints, migrations, transactions, indexes, queries, retention, and rollback. |
| `implementation-planning` | Break approved design into Tasks with scope, acceptance, tests, roles, skills, branches, and reports. |
| `test-driven-development` | Implement behavior with RED-GREEN-REFACTOR and focused automated tests. |
| `systematic-debugging` | Reproduce, isolate, explain, fix, and verify defects with evidence-driven hypotheses. |
| `code-review` | Independent review for correctness, lifecycle, concurrency, errors, maintainability, and tests. |
| `security-review` | Review trust boundaries, auth, input, secrets, injection, dependencies, and abuse paths. |
| `performance-review` | Measure and analyze latency, throughput, queries, memory, concurrency, and capacity. |
| `integration-verification` | Verify acceptance with commands, runtime evidence, integration checks, and explicit skips. |
| `merge-conflict-resolution` | Resolve merge conflicts using branch intent, base, history, interfaces, and tests. |

## The twenty-two added in 2.3.0

Scope, evidence labels, and license rules for these are in
[Professional capabilities](professional-capabilities.md). The one-line purpose
below is the contract; it is not a test result.

| Skill | Purpose |
| --- | --- |
| `frontend-visual-design` | Typography, color, and visual hierarchy, checked against hierarchy, error states, keyboard path, and zoom. |
| `browser-e2e` | Browser regression: selector strategy, trace capture, fixture handling, on the project's existing Node and Playwright. |
| `accessibility-audit` | Accessibility evidence: focus order, labels, error association, contrast. An automated scan is not WCAG conformance. |
| `postgres-practices` | PostgreSQL indexes, `EXPLAIN`, and row-level security, measured on an isolated test database. |
| `observability` | Decide the runtime question first, then place metrics, logs, and traces. Vendor-neutral. |
| `ci-pipeline` | Organize quality gates around the checks the project actually has. |
| `react-performance` | React and Next.js request-waterfall and bundle-cost rules, applied only to React tasks. |
| `react-composition` | Component composition, shared state, and boolean-prop sprawl. React 19-only advice applies only when named. |
| `icon-assets` | Icon selection with source and license recorded per icon set. The Iconify lookup needs a network and no key. |
| `svg-logo-design` | SVG logo design and export check, with local tooling only. |
| `web-assets` | Favicon, manifest, and social-image sizes from a local master, using Python and Pillow. |
| `image-compression` | Local image compression with the measured ratio and transparency preserved. No ratio is guaranteed. |
| `image-generation` | Prompt, aspect ratio, and acceptance checks for one selected image backend. Generation is online and unverified. |
| `infographic-design` | Layout, reading order, and the claims an infographic must carry. |
| `editorial-illustration` | Cover and article-illustration direction. |
| `visual-slide-deck` | A sequence of slides as images. An image deck is not an editable Office document. |
| `code-video-production` | A code-explainer video planned as frames and rendered locally. HyperFrames is the preferred method. |
| `generated-video` | A video requested from an online provider. Real online, not verified; no provider is selected. |
| `speech-production` | Speech synthesis for a named piece of text. Real online, not verified. |
| `audio-transcription` | Transcript and timestamps for a supplied recording. Real online, not verified. |
| `media-transcoding` | Local cut, remux, and transcode with FFmpeg, written from FFmpeg's own documentation. |
| `document-production` | Editable documents, slides, spreadsheets, and PDF, authored against libraries whose licenses allow it. |

## Installation

1. Clone this coordinator package (see [installation.md](installation.md)).
2. Run `scripts/verify-package.ps1` — skill-path checks expect each bundled
   `skills/<skill-id>/SKILL.md` to exist inside the package. No separate Skills
   clone or copy step is required.

## What these Skills are not

- They are **not** orchestration control: they do not start Runs, dispatch
  workers, merge branches, or widen Task scope.
- They are **not** a substitute for the global Orca Skills (`orchestration`,
  `orca-cli`, `orca-per-workspace-env`).
- They do **not** imply affiliation with Anthropic, Orca, or any vendor named
  as an example connector, and naming a vendor does not select it.

## When something is missing

| Symptom | Likely cause | What to check |
| --- | --- | --- |
| `verify-package.ps1` skill-path FAIL | Bundled file missing or corrupt | `Test-Path <package>/skills/<skill-id>/SKILL.md`; compare hashes in `skills/README.md` |
| Worker cannot read assigned Skill | Wrong path in Task or sandbox | Task `explicit-path` matches an existing bundled `SKILL.md` |
| Catalog lists Skill but file missing | Incomplete checkout or local deletion | Restore from Git; re-run integrity check |
| Hash mismatch after manual edit | Current body and integrity table disagree | Review intentional adaptations, recompute SHA256 and update the table; restore accidental changes from package Git |

For coordinator behavior and evidence paths, see [usage.md](usage.md) and
`references/evidence-binding.md`.
