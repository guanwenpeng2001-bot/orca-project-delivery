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

## SHA256 integrity (current content)

The hashes below cover the current contents of each file. Recompute this table when content changes. There is intentionally only one hash table.

| Path | SHA256 |
| --- | --- |
| `accessibility-audit/SKILL.md` | D7908E8C8EC5FD04CDB31D7CF72D0C23A545DB2555923387BA3DE45B133D5292 |
| `api-design/SKILL.md` | CC121A2C0164E8F3FA267ACB726E5709F2EA05C510C20F48DA7F2513F3FE9FF0 |
| `audio-transcription/SKILL.md` | 65D7FB77B33533E8AFB8E4914A04E6523F8487D5BA0DDCDB18A85402C94AFFCF |
| `browser-e2e/SKILL.md` | 8CF9BBADBF7376CD79DD4BA24EA34123399722D18ECEE020563DE2BD98F5101E |
| `ci-pipeline/SKILL.md` | B6E152B760BCC03627850BAABA77146FB1AC307DB2AF2E6FCE8DF340B3C7B43B |
| `code-review/SKILL.md` | 4A376A6B687DCD10DB4E8914FE302B5C9CD8318B0715A8BC25C89F58B3BBEB49 |
| `code-video-production/SKILL.md` | 5AC5B4CFCB4097682EEFBD27FA35363FFE82E4CD8E446C626004E2A3EF77D17D |
| `codebase-reconnaissance/SKILL.md` | 75BDA935A69B4A12726A380E007B1E4540E3B54A49AA4E01B72B9027699EC49D |
| `database-design/SKILL.md` | 8CD6D8EDF675EC39F43B09C2AD2D8444BE5B0FD6EC6B59293061D6F044D639A8 |
| `design-system/SKILL.md` | 581CC1B684869829CAC420B5243D2CEDC6F06DBC0E7FBD1FB7BF47A755EE9A35 |
| `document-production/SKILL.md` | D016FAC3653AE52C713B1FB2995A665392140B9898CF5F4BE36AD22EFA19E13C |
| `domain-modeling/SKILL.md` | 08C5BC8AF3EBF2179B5A36DF75F96971D550C0591E4E57328F47CB3725EFCB66 |
| `editorial-illustration/SKILL.md` | 3218EC4EB362654E99B8996FF650EC5BDC8CBCEDCA66BF1077975BD727F737BD |
| `frontend-visual-design/SKILL.md` | 05AC0BA593FF2D7BDDB007F00360B62110D5CC2CDE9CC3B41D6F603B49BFCFFB |
| `generated-video/SKILL.md` | 2723A03803FB06325D1391AFB1803CBB23B41FA42A91F6DF832523DF6E0E9F00 |
| `icon-assets/SKILL.md` | 5800C5577A95CACA768D2DBAE45723FAB7C2B7A973D9666EE47E90FEDEEF3D1F |
| `image-compression/SKILL.md` | FD9F53B8A6AD9F0460729A3D2F4795D479D912B3385C92901331BE13743EA579 |
| `image-generation/SKILL.md` | ED1FC252C52164EEABF8BC5FBEABA4AD6025D9D1ACEA5BEB2E081DB1A37D3E01 |
| `implementation-planning/SKILL.md` | 1CAADB38ED965DC48A419466AF5B41DE94FC698E6662E4602B50701D22F87EC5 |
| `infographic-design/SKILL.md` | 0297CB288EBDD63D2531437C416BEB52928A525499053A5396E1655511F3FEBB |
| `integration-verification/SKILL.md` | 42C3B7485F9B077E55DE2DE08551DAC694CF9433DD455321AE941875BED6EAD3 |
| `localization/SKILL.md` | 813222FD76CFE2699421F6D40631C6F80F0A55FE4436B959EB35C30591198E0C |
| `mcp-server-development/SKILL.md` | 5EBFFCED80FE354D664265AB165756FAD416C1AB7BE8DFFB53B0CB37F0D655BE |
| `media-transcoding/SKILL.md` | 49CD1155F30D98AC37C9B68E167CE81B34EC89A0A6C895E991F13A70E5930C1C |
| `merge-conflict-resolution/SKILL.md` | 077CC1E2E46378DB83C0B649375E982DB68DE757D903FE124DB2A5182B7CC514 |
| `migration-upgrade/SKILL.md` | C87A5EAF3B25DC38890E49D40E1890805933C4E41F058754AAEC7663B16B7B31 |
| `observability/SKILL.md` | 5A086A43E39D4446BAEB07A83117717DE8EE355AD6BB2878BD1F8250E5D0DB21 |
| `performance-review/SKILL.md` | B870ABC4C5EE0951B63544EF0AEC0AF19EF00ADA3B9E2164CA6BA61A4B9C2309 |
| `postgres-practices/SKILL.md` | 24AA0C22AE1B146E6C65E35F881637AEC2E4A8EC490E44DEBB8D44E92C5A6570 |
| `product-design/SKILL.md` | 3091DEA51C6316B70F7CF00780D74E09A8B3A1143E1B1BFED3217FCD0648F922 |
| `product-discovery/SKILL.md` | DA109B54CA1A9B1A176A229228BE04FA8D19AC2607753C254DB4566C712301C2 |
| `react-composition/SKILL.md` | FC06B200F21FDA984765C9F3508AD0D116F87D8213382CF64FE27E655F1C5EE2 |
| `react-performance/SKILL.md` | 1332B6A9442351EC62692E4B393F7A5270885ACB00F445813D9504E6F2C1740C |
| `requirements-analysis/SKILL.md` | D3A48C51A5A2836A9A891400CC39F3EB64056AAAFC22ECEDA074C49B154456A1 |
| `security-review/SKILL.md` | E65D3C830C6E3080666E67822421D4905940BA82A34C0E805ADB27E998F47232 |
| `skill-authoring-evaluation/SKILL.md` | C0099CCC95C3FD014BFE019C82BD3E2D6E649BF6FAC3941F1195EDE2991CD030 |
| `solution-architecture/SKILL.md` | 8D92271780A73975ABCA70DFEF51EDADB3758E7316079A8061BB2FD384FFCF5D |
| `speech-production/SKILL.md` | 24D4C8C2FCA4CAA3B8FEFFCFF54B28CB5D3C6E182E6C87B1E9EA459288F4BC1A |
| `subtitle-production/SKILL.md` | EA072168E0E65265F99533FCF32693C3C431D8FC55D58F0E8E3AF7B6C1FB668E |
| `svg-logo-design/SKILL.md` | C35A379A9E6D74CF6F633C20006157B05630511C1F0EE4A87C29F8AC227724B6 |
| `systematic-debugging/SKILL.md` | 0F2D0FA14977C62592E7C1BB04BBD6EF59E5B2400BBD3E2CFA427E79AB1494FF |
| `technical-diagrams/SKILL.md` | 4376E5C8D3CE79A221C6C69DA50D042C30C8434FFA154844B99E116D28FD468A |
| `technical-research/SKILL.md` | C787DB619895BBE89C188829C008445668C080A005676B27274BE7E40FFEFC4F |
| `test-driven-development/SKILL.md` | A4CB2265F6C767568412BCFBF72CC54FE38FFFFBFCA6C7A9CE10067C03B46A25 |
| `visual-slide-deck/SKILL.md` | FF8FB922A62D8F7936827837A0CB02AA0AC3134A9595C3156FB56A6A383E8F47 |
| `web-assets/SKILL.md` | BED0F498CC8D38013F1042330A7B2AD77A893B517402377F5A3F5A81B30BE0B3 |
| `LICENSE` | 7129B74272330BD7F3E542F64FB9047ABFE78F8204A444267137379CCC8158D0 |
