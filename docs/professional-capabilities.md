# Professional capabilities

**English** | [简体中文](zh-CN/professional-capabilities.md)

Version 2.3.0 adds professional methods for software delivery, local visual
assets, image planning, and audio, video, and document production. Together
with the original sixteen, the package carries **38 professional Skills** and
**16 Roles**. This guide explains what each new capability is for, what it does
not do, and how far its claims have actually been checked.

Counts, catalog registration, and the executable dependency surface belong to
the parallel capability package. Until that package lands, treat the IDs below
as the approved capability contract, and confirm registration by reading
`routing/skill-catalog.json`, `roles/catalog.json`, and `PACKAGE-MANIFEST.json`
in the revision you installed. Do not treat a sentence in this guide as proof
that a file exists.

## How to read a capability

Every new capability is one of four things. The labels are not interchangeable.

| Label | What it means | What it does not mean |
| --- | --- | --- |
| **Method** | A `SKILL.md` that tells a worker how to decide, check, and report. | It does not execute anything by itself, and loading it is not a test result. |
| **Implemented local tool** | A command the package actually ships and that this revision's scripts can run, such as the existing dependency helpers. | It does not mean a browser, database, encoder, or model ran. |
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
method can run with no new credential.

| Skill | Adds | Does not replace | Execution status |
| --- | --- | --- | --- |
| `frontend-visual-design` | Typography, color, and visual hierarchy for a page or component, with checks for hierarchy, error states, keyboard path, and 200% zoom. | `product-design`, which still owns flows, information architecture, and interaction states. | Method. A page check needs the project's own runtime and a browser; this release has not run that check. |
| `browser-e2e` | Selector strategy, trace capture, and fixture handling for browser regression. | `integration-verification`, which stays the general acceptance method. | Method. Execution expects the project's existing Node and Playwright. No Python helper is added. No browser run is claimed here. |
| `accessibility-audit` | Turns an accessibility requirement into evidence: focus order, labels, error association, contrast. | `product-design`, which states the requirement at design time. | Method. An automated scan is not a WCAG conformance claim. |
| `postgres-practices` | PostgreSQL-specific rules: indexes, `EXPLAIN`, row-level security. | `database-design`, which stays the general modeling and migration method. | Method. Measurement needs an isolated test database. No shared or production database is part of the method. |
| `observability` | Decide the runtime question first, then place metrics, logs, and traces. | `systematic-debugging`, which starts from a defect rather than from instrumentation design. | Method. Vendor-neutral; no telemetry vendor is selected. |
| `ci-pipeline` | Organize quality gates around the checks the project actually has. | Ad hoc CI templates. The Skill does not ship a pipeline. | Method. A local simulation and a remote pipeline run are different evidence and must be labeled separately. |
| `react-performance` | React and Next.js rules for request waterfalls and bundle cost, used only when the task is React. | `performance-review`, which stays the general measurement method. | Method, conditional on the React version in the task. Before-and-after measurements are required; a list of opinions is not acceptance. |
| `react-composition` | Component composition, shared state, and boolean-prop sprawl. | Rewrites done for their own sake. | Method. React 19-only advice applies only when the task names React 19. |

These are not new Roles. An implementer, architect, reviewer, or verifier loads
the relevant Skill. One Skill does not get one Role.

## Local asset methods

Four Skills plus the `media-producer` Role. They produce files a site keeps:
icons, logos, favicons, manifests, and compressed images. They do not publish
those files anywhere.

| Skill | Produces | Depends on | Limit |
| --- | --- | --- | --- |
| `icon-assets` | An icon choice with its source and license recorded per icon set. | Node for local tooling. Querying the public Iconify index needs a network and no key. | Not offline. Each icon set keeps its own license. |
| `svg-logo-design` | An SVG logo and an export check. | Local SVG tooling only. | A method and an export. No hosted logo service is selected. |
| `web-assets` | Favicon, web manifest, and social-image sizes from a local master. | Python with Pillow in the project environment. | Raster sizes only. It does not generate artwork. |
| `image-compression` | A compressed image plus the measured ratio, with transparency preserved. | A local encoder such as `cwebp` or ImageMagick, chosen by the implementation, not by this guide. | No ratio is guaranteed. A failure on Windows is a failure, not a skip. |

`icon-assets` is the one asset Skill that is online by default. The other three
are local. None of them is a paid API, and none of them has a measured output
in this release: the acceptance rows in the tutorial are the checks to run, not
checks that have passed.

## Image methods

Four Skills. Planning a picture and generating a picture are different steps.
The planning step is a method and needs no key. The generation step is a real
online call, and **it has not been verified**.

| Skill | Plans | Generates only when |
| --- | --- | --- |
| `image-generation` | Prompt, aspect ratio, and acceptance checks for one selected backend. | A user has approved one provider, a budget, and what may be uploaded. |
| `infographic-design` | Layout, reading order, and the claims the picture must carry. | That same approved backend is used. |
| `editorial-illustration` | Cover and article-illustration direction. | That same backend is used. |
| `visual-slide-deck` | A sequence of slides as images. | That same backend is used. The result is an image deck, not an editable Office document. |

Connect at most one image backend. This package does not pre-select among
OpenAI, Google, OpenRouter, or any other vendor, and naming one as an example
below is not a selection. No image call is authorized by installing the
package.

## Audio, video, and document methods

Six Skills. Local rendering and online generation stay separate, including when
one deliverable could use either.

| Skill | What it is | Local or online | Status |
| --- | --- | --- | --- |
| `code-video-production` | A code-explainer video planned as frames and rendered locally. | Local render. Optional networked assets or speech are a separate, approved step. | Method. The preferred authoring method is HyperFrames. Remotion and video-shotcraft are alternatives that were not selected. No render has been run for this release. |
| `generated-video` | A video requested from an online video provider. | Online. Requires a key, a network, and an approved budget. | Real online, not verified. Pexo is an example connector, not a selected vendor. OpenMontage is not included; see Licenses. |
| `speech-production` | Speech synthesis for a named piece of text. | Online. | Real online, not verified. ElevenLabs is an example connector, not a selected vendor. |
| `audio-transcription` | Transcript and timestamps for a supplied recording. | Online. | Real online, not verified. Same example connector, still not a selection. |
| `media-transcoding` | Cut, remux, or transcode with a local FFmpeg. | Local. `ffmpeg` and `ffprobe` on the execution host. | Method. Encoder and build licenses of the installed FFmpeg are checked separately. No transcode has been run for this release. |
| `document-production` | Editable documents, slides, spreadsheets, and PDF, authored against libraries whose licenses allow it. | Local libraries, chosen per format. | Method. This is not a copy of the Anthropic docx, pptx, pdf, or xlsx Skills; those are not included. |

`media-producer` carries the asset, image, and audio-video Skills.
`document-specialist` carries document production and the image slide deck.
Neither Role may upload, publish, or start a paid call without an explicit
approval of the provider, the budget, and the upload scope for that task.

## The four new Roles

Sixteen Roles in all: the original twelve, plus these four. A Role is an
identity and a boundary. It does not raise permissions, and it does not load
every Skill in its area.

| Role | Category | Use when | Default Skills | Optional Skills | Never |
| --- | --- | --- | --- | --- | --- |
| `ui-designer` | product | A page or component needs a visual spec, a component-state matrix, or a design review. | `product-design`, `frontend-visual-design` | `accessibility-audit`, and `icon-assets` once that Skill is registered. | Does not gather requirements and does not implement product UI. Writes prototype code only on paths the task names. |
| `browser-test-engineer` | quality | The task needs browser regression evidence, an accessibility audit, or a trace of a defect. | `browser-e2e`, `integration-verification` | `accessibility-audit`, `systematic-debugging` | Does not implement the product under test and does not replace `release-verifier`. The person who implemented a page does not also accept it. |
| `media-producer` | media | The task produces icons, logos, site assets, illustrations, storyboards, or audio-video masters, with a source and license list. | None by default; the task picks one to three. | The asset, image, and audio-video Skills relevant to that task. | Does not upload, publish, or spend money without explicit approval. Does not edit product source. |
| `document-specialist` | product | The task produces an editable document, slide deck, spreadsheet, or PDF, and checks that it round-trips. | `document-production` | `visual-slide-deck` | Does not present an image deck as editable objects, and does not copy a proprietary document Skill. |

The other twelve Roles are unchanged. React, PostgreSQL, observability, and CI
do not get Roles of their own; they are Skills loaded by the implementer,
architect, reviewer, or verifier whose task needs them.

Model routes, deliverable routes, and risk routes are package data in
`routing/`. This guide does not duplicate them, because a copied table goes
stale the moment the package changes.

## Claims and evidence

| Claim in this release | Evidence you can check | Evidence this release does not have |
| --- | --- | --- |
| The package verifies its own structure offline. | `scripts/verify-package.ps1` exits 0 with `FAIL=0` on the revision you installed. | A passing suite says nothing about a generated image, video, or document. |
| Methods are delivered as Skill files. | The Skill file exists at `skills/<id>/SKILL.md` and its hash matches `skills/README.md`. | Loading a Skill is not a test of the method's output. |
| Dependency helpers run locally. | The tutorial's offline walk uses `check-requirements.ps1` and `invoke-with-requirements.ps1` with fake values and no network. | Their parameters for the new Skills are not asserted here until the capability package defines them. |
| Online connectors exist as examples. | The tutorial names OpenAI for images, Pexo for video, and ElevenLabs for speech and transcription, each as an example. | No call was made. No provider was selected. No generation quality was measured. |

## Licenses and sources

Provenance is per Skill, not one blanket upstream. The authoritative table is
`skills/README.md` in the capability package: one row per Skill with its
upstream repository, pinned commit, license, and the license file copied into
the package. This guide states the rules those rows have to satisfy.

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
- **New adaptations** each carry their own `LICENSE.txt` and a pinned upstream
  commit. Software methods adapt, among others, Anthropic frontend-design
  (Apache-2.0), ECC e2e-testing (MIT), wshobson accessibility patterns (MIT),
  Supabase PostgreSQL practices (MIT), and Addy Osmani observability and CI
  methods (MIT). Asset and image methods adapt MIT-licensed upstreams. The
  pinned commits belong in `skills/README.md`, not here, so this guide cannot
  drift from the import.
- **Two upstreams are deliberately not copied.** The Anthropic docx, pptx, pdf,
  and xlsx Skills are proprietary and are not included; `document-production`
  is written independently against libraries whose licenses allow it.
  OpenMontage is AGPL-3.0 and is not included; `media-transcoding` is written
  from FFmpeg's own documentation, and the license of the installed FFmpeg
  build and its encoders is checked separately.
- **React methods are conditional.** The Vercel react-best-practices and
  composition-patterns upstreams declare MIT but did not ship a root `LICENSE`
  text at research time. They are included only once the capability package
  records an authorization text at a pinned commit, or replaced by an
  independent write-up that copies no upstream wording. Until that record
  exists, do not describe them as cleared.
- **Assets carry their own licenses.** An icon set, a font, and a stock image
  are not covered by the tool that fetched them. `icon-assets` requires a
  source and a license per icon set.

No new Skill copies an upstream instruction that launches a different agent
product. Adaptation keeps the method and drops that part.

## Related

- [Installation](installation.md) for the offline package check.
- [Professional capability tutorial](professional-capability-tutorial.md) for a
  run that uses only the dependency helpers.
- [Extending](extending.md) for the registration rules the counts come from.
- [Professional Skills](professional-skills.md) for the original sixteen.
