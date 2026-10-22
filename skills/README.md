# Bundled professional Skills

These 46 professional Skills ship inside `orca-project-delivery` so workers resolve them from the package only (no global sibling fallback).

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

No optional connector is selected as the user's production provider by being present here. `CAPABILITY_ONLINE_PROVIDERS_ENABLED=false` in the example project configuration keeps live calls unauthorized.
