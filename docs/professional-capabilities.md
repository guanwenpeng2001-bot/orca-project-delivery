# Professional capabilities

**English** | [简体中文](zh-CN/professional-capabilities.md)

Version 2.4.0 deepens the methods added in 2.3.0 and adds eight more:
engineering methods, a design system, subtitles, and bounded document blocks.
Together with the original sixteen and the twenty-two from 2.3.0, the package
carries **46 professional Skills**, **16 Roles**, and **4 workflows**. This
guide explains what each new or deepened capability is for, what it does not
do, and how far its claims have actually been checked.

This guide describes the 3.0.0 package: 46 Skills, 16 Roles, and 4
workflows. Install the complete matching release. Confirm `VERSION` is `3.0.0`,
`routing/skill-catalog.json` contains 46 Skills, `roles/catalog.json`
contains 16 Roles, `workflows/` holds 4 definitions, and
`PACKAGE-MANIFEST.json` agrees before running the
[tutorial](professional-capability-tutorial.md). A version that does not match
is not this release. The tutorial rejects a mismatched installation.

## How to read a capability

Every new capability is one of four things. The labels are not interchangeable.

| Label | What it means | What it does not mean |
| --- | --- | --- |
| **Method** | A `SKILL.md` that tells a worker how to decide, check, and report. | It does not execute anything by itself, and loading it is not a test result. |
| **Implemented local tool** | A command the package actually ships and that this revision's scripts can run, such as the contrast, resize, header, subtitle, composition, and probe helpers. | It does not mean a browser, database, encoder, or model ran. |
| **Offline verification** | A check that runs without a network and without a provider account. Package structure checks are in this class. | Passing one does not measure generated pictures, audio, or video. |
| **Real online, not verified** | A provider call that needs a key, a network, and an explicit approval of provider, budget, and upload scope. | No such call has been made for this release. Configuration presence is not a successful generation. |

A method can be delivered and reviewed while its execution remains unverified.
The document says which is which. It never reports a generation as tested, and
it never treats an example provider as a provider the user selected.

## The original sixteen

These remain the core delivery methods. Their purpose is unchanged; see
[Professional Skills](professional-skills.md) for the per-Skill descriptions and
the integrity rules.

`codebase-reconnaissance`, `technical-research`, `product-discovery`,
`product-design`, `requirements-analysis`, `solution-architecture`,
`api-design`, `database-design`, `implementation-planning`,
`test-driven-development`, `systematic-debugging`, `code-review`,
`security-review`, `performance-review`, `integration-verification`,
`merge-conflict-resolution`.

They are package-maintained adaptations. Their upstream baseline and current
content hashes stay in `skills/README.md`.

## Software methods

Eight Skills. None of them declares a provider key. A task that only needs the
method can run with no new credential. Three of them gained local tools or integration with those tools in
2.4.0; the other five are unchanged methods.

| Skill | Adds | Does not replace | Execution status |
| --- | --- | --- | --- |
| `frontend-visual-design` | Typography, color, and visual hierarchy for a page or component, with checks for hierarchy, error states, keyboard path, and 200% zoom. 2.4.0 adds `scripts/contrast-ratio.mjs`, a local WCAG 2.2 contrast calculation. | `product-design`, which still owns flows, information architecture, and interaction states, and `design-system`, which owns tokens shared across screens. | Method plus one implemented local tool. A page check needs the project's own runtime and a browser; this release has not run that check. |
| `browser-e2e` | Selector strategy, trace capture, and fixture handling for browser regression, plus a local sample journey against a static fixture page. | `integration-verification`, which stays the general acceptance method. | Method plus local scripts. The sample runner launches an already installed local Chromium through the caller's Python Playwright and reports a named missing-dependency error when Python, Playwright, or that Chromium is absent; the corresponding optional test skips. A skip is not browser coverage, and nothing here installs a browser. |
| `accessibility-audit` | Turns an accessibility requirement into evidence: focus order, labels, error association, contrast measured with the `frontend-visual-design` contrast command. | `product-design`, which states the requirement at design time. | Method. An automated scan is not a WCAG conformance claim. |
| `postgres-practices` | PostgreSQL-specific rules: indexes, `EXPLAIN`, row-level security. | `database-design`, which stays the general modeling and migration method. | Method. Measurement needs an isolated test database. No shared or production database is part of the method. |
| `observability` | Decide the runtime question first, then place metrics, logs, and traces. | `systematic-debugging`, which starts from a defect rather than from instrumentation design. | Method. Vendor-neutral; no telemetry vendor is selected. |
| `ci-pipeline` | Organize quality gates around the checks the project actually has. | Ad hoc CI templates. The Skill does not ship a pipeline. | Method. A local simulation and a remote pipeline run are different evidence and must be labeled separately. |
| `react-performance` | React and Next.js rules for request waterfalls and bundle cost, used only when the task is React. | `performance-review`, which stays the general measurement method. | Method, conditional on the React version in the task. Before-and-after measurements are required; a list of opinions is not acceptance. |
| `react-composition` | Component composition, shared state, and boolean-prop sprawl. | Rewrites done for their own sake. | Method. React 19-only advice applies only when the task names React 19. |

These are not new Roles. An implementer, architect, reviewer, or verifier loads
the relevant Skill. One Skill does not get one Role.

## Engineering methods

Eight Skills added in 2.4.0. Seven are methods (some include offline example checks), one ships a local
converter, and none of them contacts a service. They are original methods that
cite public specifications; no upstream Skill text is copied.

| Skill | Decides | Worked example you can check | Limit |
| --- | --- | --- | --- |
| `skill-authoring-evaluation` | Whether a Skill's description triggers correctly, names a counterexample, and states an observable outcome. | The worked example scores a weak and a strong description against `database-design`. | Scores the text. It is not an agent experiment and reports none. |
| `design-system` | Shared tokens (primitive, semantic, component) and component contracts across screens. | The worked example declares CSS custom properties and states the muted-on-surface ratio as `4.48:1` in prose. The same value is produced by the `frontend-visual-design` `contrast-ratio.mjs` command. | Tool-neutral. It does not replace `frontend-visual-design`, which owns one screen's visual spec. |
| `domain-modeling` | Entities, value objects, aggregates, and which invariant each owns. | The worked example rejects a reservation model that lets two stays write the same room-night. | Stops before storage. Schema and migrations stay with `database-design`. |
| `migration-upgrade` | The expand, dual-run, switch, and contract order for a dependency, framework, or API upgrade. | The worked example moves an HTTP body under `data` across four separate deploys, detected by an `Accept-Version` header. | Does not plan a schema backfill; that stays with `database-design`. |
| `mcp-server-development` | An MCP tool surface: names, schemas, error channel, and transport. | The worked example shows a valid `tools/call`, a `-32602` protocol error for an unknown tool, and a tool error for an out-of-range value, pinned to protocol revision `2025-11-25`. | Ships no server scaffold. Its checks validate fixture files and do not start a server. |
| `technical-diagrams` | Hand-written SVG and Mermaid figures: real text, readable sizes, contrast tokens, and a description. | The worked example is a sequence diagram plus `examples/version-header.svg`, checked by reading the source. | Reading source is not rendering. No figure is claimed to have been drawn on screen. |
| `localization` | Glossary, placeholder and ICU message protection, expansion, and right-to-left text. | The worked example rewrites a concatenated count into one ICU `plural` message with the same placeholders in every locale. | Prepares source copy. It calls no translation service and invents no translations. |

`subtitle-production` is listed under [Audio, video, and document methods](#audio-video-and-document-methods) so the inventory counts each later Skill once.

The local commands and their results are in the
[tutorial](professional-capability-tutorial.md#6-run-the-240-local-tools).

## Local asset methods

Four Skills plus the `media-producer` Role. They produce files a site keeps:
icons, logos, favicons, manifests, and compressed images. They do not publish
those files anywhere.

| Skill | Produces | Depends on | Limit |
| --- | --- | --- | --- |
| `icon-assets` | An icon choice with its source and license recorded per icon set. | Node for local tooling. Querying the public Iconify index needs a network and no key. | Not offline. Each icon set keeps its own license. |
| `svg-logo-design` | An SVG logo and an export check. | Local SVG tooling only. | A method and an export. No hosted logo service is selected. |
| `web-assets` | Favicon, web manifest, and social-image sizes from a local master. | Node for the manifest script. The image bytes come from a reviewed master, shrunk with `png-resize.mjs`. | Raster sizes only. It does not generate artwork, and it cannot produce the 512 entry by shrinking a 512px master. SVG rasterizing needs an external tool the package does not ship. |
| `image-compression` | A compressed image plus the measured ratio, with transparency preserved, and a smaller PNG exported from a master. | Node. `png-compressor.mjs` is lossless; `png-resize.mjs` shrinks an 8-bit non-interlaced RGB or RGBA PNG. | No ratio is guaranteed. A resize request that is not smaller fails, and an RGB `tRNS` color key is expanded to real alpha before averaging. Other ancillary chunks are rejected by name rather than dropped. |

`icon-assets` is the one asset Skill that is online by default. The other three
are local. None of them is a paid API. The compression and resize commands have
been run offline against generated fixtures, which checks structure and decoded
pixels, not how the result looks. The
[asset acceptance rows](professional-capability-tutorial.md#asset-acceptance)
list the checks to record for an actual output, including the ones not run.

## Image methods

Four Skills. Planning a picture and generating a picture are different steps.
The planning step is a method and needs no key. The generation step is a real
online call, and **it has not been verified**.

| Skill | Plans | Generates only when |
| --- | --- | --- |
| `image-generation` | Prompt, aspect ratio, and acceptance checks for one selected backend, plus `scripts/image-info.mjs`, which reads a PNG, JPEG, or WebP header. | A user has approved one provider, a budget, and what may be uploaded. The header check is local and never decodes pixels. |
| `infographic-design` | Layout, reading order, and the claims the picture must carry. | That same approved backend is used. |
| `editorial-illustration` | Cover and article-illustration direction. | That same backend is used. |
| `visual-slide-deck` | A sequence of slides as images. | That same backend is used. The result is an image deck, not an editable Office document. |

Connect at most one image backend. This package does not pre-select among
OpenAI, Google, OpenRouter, or any other vendor, and naming one as an example
below is not a selection. No image call is authorized by installing the
package.

## Audio, video, and document methods

Seven Skills. Local rendering and online generation stay separate, including
when one deliverable could use either.

| Skill | What it is | Local or online | Status |
| --- | --- | --- | --- |
| `code-video-production` | A code-explainer video planned as frames and rendered locally, with `scripts/composition-check.mjs` checking the timeline before any render. | Local render. Optional networked assets or speech are a separate, approved step. | Method plus one local check. The preferred authoring method is HyperFrames. The composition check reads HTML and prints a frame map; it never renders, and no HyperFrames render has been run for this release. |
| `generated-video` | A video requested from an online video provider. | Online. Requires a key, a network, and an approved budget. | Real online, not verified. Pexo is an example connector, not a selected vendor. OpenMontage is not included; see Licenses. |
| `speech-production` | Speech synthesis for a named piece of text. | Online. | Real online, not verified. ElevenLabs is an example connector, not a selected vendor. |
| `audio-transcription` | Transcript and timestamps for a supplied recording. | Online. | Real online, not verified. Same example connector, still not a selection. |
| `media-transcoding` | Cut, remux, or transcode with a local FFmpeg, then compare the two probes with `scripts/probe-compare.mjs`. | Local. `ffmpeg` and `ffprobe` on the execution host. | Method plus one local check. The comparison reads ffprobe JSON the caller captured; it never runs ffprobe itself. Encoder and build licenses of the installed FFmpeg are checked separately. |
| `document-production` | Editable documents, slides, spreadsheets, and PDF from a bounded block source, authored against libraries whose licenses allow it. | Local libraries, chosen per format. | Method plus local scripts. This is not a copy of the Anthropic docx, pptx, pdf, or xlsx Skills; those are not included. |
| `subtitle-production` | SRT and WebVTT conversion with timing checks. | Node only. | Implemented local tool. Text cues only; no styling, positioning, or burn-in. |

`media-producer` carries the asset, image, audio-video, and subtitle Skills.
`document-specialist` carries document production and the image slide deck.
Neither Role may upload, publish, or start a paid call without an explicit
approval of the provider, the budget, and the upload scope for that task.

## The four Roles added in 2.3.0

Sixteen Roles in all: the original twelve, plus these four. A Role is an
identity and a boundary. It does not raise permissions, and it does not load
every Skill in its area.

| Role | Category | Use when | Default Skills | Optional Skills | Never |
| --- | --- | --- | --- | --- | --- |
| `ui-designer` | product | A page or component needs a visual spec, a component-state matrix, or a design review. | `product-design`, `frontend-visual-design` | `accessibility-audit`, `icon-assets`, `design-system`, `localization` | Does not gather requirements and does not implement product UI. Writes prototype code only on paths the task names. |
| `browser-test-engineer` | quality | The task needs browser regression evidence, an accessibility audit, or a trace of a defect. | `browser-e2e`, `integration-verification` | `accessibility-audit`, `systematic-debugging` | Does not implement the product under test and does not replace `release-verifier`. The person who implemented a page does not also accept it. |
| `media-producer` | media | The task produces icons, logos, site assets, illustrations, storyboards, subtitles, or audio-video masters, with a source and license list. | None by default; the task picks one to three. | The asset, image, audio-video, `subtitle-production`, and `technical-diagrams` Skills relevant to that task. | Does not upload, publish, or spend money without explicit approval. Does not edit product source. |
| `document-specialist` | product | The task produces an editable document, slide deck, spreadsheet, or PDF, and checks that it round-trips. | `document-production` | `visual-slide-deck`, `editorial-illustration` | Does not present an image deck as editable objects, and does not copy a proprietary document Skill. |

The other twelve Roles are unchanged in identity. `software-architect` also
loads `domain-modeling`, `migration-upgrade`, `mcp-server-development`, and
`technical-diagrams` when the task needs them, and `software-implementer` loads
`migration-upgrade`, `mcp-server-development`, `localization`, and
`skill-authoring-evaluation`. React, PostgreSQL, observability, and CI still do
not get Roles of their own.

`roles/catalog.json` is the authority for optional-Skill attachments in the
installed revision.

Model routes, deliverable routes, and risk routes are package data in
`routing/`. This guide does not duplicate them, because a copied table goes
stale the moment the package changes.

## The six enhancement groups

| Group | Concrete change | Boundary |
| --- | --- | --- |
| Frontend and product | Shared design tokens, measured contrast, and a product handoff naming token references, state matrices, copy, and observable acceptance. | A contrast ratio alone does not validate an entire page. |
| Browser and accessibility | Two keyboard-driven fixture journeys, a seeded-defect check, and an audit table for focus, labels, errors, contrast, and zoom. | Local sample coverage, not WCAG certification or a test of the user's app. |
| Documents | Heading, paragraph, ordered list, and real tables in Markdown/DOCX/XLSX; the old title/bullet source remains supported. | PPTX/PDF reject tables; no merged cells, charts, macros, or arbitrary templates. |
| Icons and web assets | Per-size master/export/license records and bounded PNG exports at the manifest's smaller sizes. | Use a simplified small-icon master for 16/32 and a large master for 180/192; copy the reviewed 512 master for its own entry. |
| Images | PNG/JPEG/WebP headers, infographic value-to-mark checks, illustration object/source records, and slide readability thresholds. | At 1920px slide width, body text is at least 28px with 4.5:1 contrast; header checks cannot verify labels, truth, or visual readability. |
| Code video and transcoding | Composition frame maps and comparison of saved ffprobe JSON. | Neither command renders or transcodes; those operations require separately available tools. |

## Claims and evidence

| Claim in this release | Evidence you can check | Evidence this release does not have |
| --- | --- | --- |
| The package verifies its own structure offline. | `scripts/verify-package.ps1` exits 0 with `FAIL=0` on the revision you installed. | A passing suite says nothing about a generated image, video, or document. |
| Methods are delivered as Skill files. | The Skill file exists at `skills/<id>/SKILL.md` and its hash matches `skills/README.md`. | Loading a Skill is not a test of the method's output. |
| Local tools run offline. | The tutorial runs contrast, PNG resize, image headers, subtitle conversion, the composition frame map, probe comparison, PNG compression, the web manifest, Markdown generation, dependency checks, and offline provider fixtures. | A frame map is not a rendered video, a probe comparison is not a transcode, a header check is not a decoded image, and fixture success is not provider or generation-quality evidence. |
| Office and PDF blocks round-trip. | The tutorial reopens docx, xlsx, pptx, and pdf and compares text. | Programmatic read-back is not visual review. Table overflow, font substitution, and PDF pagination were not checked, and PPTX and PDF reject a `table` block. |
| Online connectors exist as examples. | The tutorial names OpenAI for images, Pexo for video, and ElevenLabs for speech and transcription, each as an example. | No call was made. No provider was selected. No generation quality was measured. |

Local Windows checks during content review ran the two Chromium fixture
journeys (Python 3.14.6, Chromium revision 1234) and FFmpeg 8.1 generation,
probe, and null-decode of synthetic media. These are bounded local results,
not cross-platform validation. HyperFrames rendering, Office/PDF visual
review, and all real provider calls remain unverified. Image-header checks
also do not establish complete image decoding or visual quality.

## Licenses and sources

Provenance is per Skill. `skills/README.md` records the original sixteen’s
pinned upstream and MIT notice, plus public references for the later original
methods. A reference does not mean upstream Skill text was copied.

- **This project keeps its own MIT license** at the repository root. MIT covers
  this project's original text: the coordinator Skill, the scripts, the
  routing, and the public docs.
- **Third-party material keeps the license it arrived with.** An Apache-2.0
  Skill stays Apache-2.0, with its notices preserved beside it. The project
  MIT license does not relicense it.
- **The original sixteen** are package-maintained MIT adaptations of
  [orca-professional-skills](https://github.com/guanwenpeng2001-bot/orca-professional-skills)
  at commit `d9a174c7143bfb4c76ed042f457fb7785c35cea3`, enriched in this
  package. Their upstream MIT notice stays in `skills/LICENSE`. Current hashes
  track the adapted text, not byte-identical upstream copies.
- **Everything after the original sixteen is an original method.** The
  twenty-two added in 2.3.0 and the eight added in 2.4.0 were written in this
  project. They cite public specifications and documentation — WCAG 2.2, the
  PNG specification, WebVTT, the MCP specification, PostgreSQL, OpenTelemetry,
  React's public API guidance — and copy none of that text into a Skill. No
  Skill directory ships a `LICENSE.txt`, and `skills/README.md` records each of
  them as `Original`. They are not upstream adaptations.
- **Two upstreams are deliberately not copied.** The Anthropic docx, pptx, pdf,
  and xlsx Skills are proprietary and are not included; `document-production`
  is written independently against libraries whose licenses allow it.
  OpenMontage is AGPL-3.0 and is not included; `media-transcoding` is written
  from FFmpeg's own documentation, and the license of the installed FFmpeg
  build and its encoders is checked separately.
- **Assets carry their own licenses.** An icon set, a font, and a stock image
  are not covered by the tool that fetched them. `icon-assets` requires a
  source and a license per icon set.

Public references supply technical facts; these original methods do not import
another product’s orchestration instructions.

## Related

- [Installation](installation.md) for the offline package check.
- [Professional capability tutorial](professional-capability-tutorial.md) for a
  walkthrough of local tools and dependency helpers.
- [Extending](extending.md) for the registration rules the counts come from.
- [Professional Skills](professional-skills.md) for the complete inventory.
