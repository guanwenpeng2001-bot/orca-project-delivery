# Bundled professional Skills

These 38 professional Skills ship inside `orca-project-delivery` so workers resolve them from the package only (no global sibling fallback).

## Provenance

The original 16 delivery Skills were imported as a baseline and then adapted in this package. The 22 capability Skills added in version 2.3.0 are original methods written for this package. They cite public specifications or documentation below; they are not copies of upstream Skill collections, and no upstream Skill license is restated as a license for those original methods.

| Field | Value |
| --- | --- |
| Original baseline repository | https://github.com/guanwenpeng2001-bot/orca-professional-skills |
| Original baseline commit | `d9a174c7143bfb4c76ed042f457fb7785c35cea3` |
| Baseline import date | 2026-10-09 |
| Baseline license | MIT — see `LICENSE` in this directory; it covers the original 16-Skill baseline, not third-party references |
| Capability methods added | 2026-10-09, version 2.3.0, original package content |

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

No optional connector is selected as the user's production provider by being present here. `CAPABILITY_ONLINE_PROVIDERS_ENABLED=false` in the example project configuration keeps live calls unauthorized.

## SHA256 integrity (current content)

The hashes below cover the current contents of each file. Recompute this table when content changes. There is intentionally only one hash table.

| Path | SHA256 |
| --- | --- |
| `accessibility-audit/SKILL.md` | 4B38C416EC0C3C6C9BD4E3B73CE80EDF2E9F3418FE87CC8B55D519B691E43C7D |
| `api-design/SKILL.md` | CC121A2C0164E8F3FA267ACB726E5709F2EA05C510C20F48DA7F2513F3FE9FF0 |
| `audio-transcription/SKILL.md` | 65D7FB77B33533E8AFB8E4914A04E6523F8487D5BA0DDCDB18A85402C94AFFCF |
| `browser-e2e/SKILL.md` | 950C64ACD2014F8A8191D52AA54E61BDF1ABDAAF4A6B8FB228181C01C41DFBC3 |
| `ci-pipeline/SKILL.md` | B6E152B760BCC03627850BAABA77146FB1AC307DB2AF2E6FCE8DF340B3C7B43B |
| `code-review/SKILL.md` | 411AD3ADB1419E3F7FA585123DEECFCB77738310D99A5F1B7464E2301BB461B2 |
| `code-video-production/SKILL.md` | 741FA3504C67FE8A983D47BC17F40BF2F9C0D9AABEAD3E3A27687DCAEC4C9580 |
| `codebase-reconnaissance/SKILL.md` | 75BDA935A69B4A12726A380E007B1E4540E3B54A49AA4E01B72B9027699EC49D |
| `database-design/SKILL.md` | 8CD6D8EDF675EC39F43B09C2AD2D8444BE5B0FD6EC6B59293061D6F044D639A8 |
| `document-production/SKILL.md` | D159ECF568C5BE193E5D5826C3939DEAE90FA9339ED7D0C7666D809998CF62DD |
| `editorial-illustration/SKILL.md` | 738BA86482C46101B7DF8D60A2004B417994F338399D88067A809C074D1636C3 |
| `frontend-visual-design/SKILL.md` | E9409A88F08486D015F5B111B870B08D5C6D1B25950FA931D2D3C949787A36C3 |
| `generated-video/SKILL.md` | 2723A03803FB06325D1391AFB1803CBB23B41FA42A91F6DF832523DF6E0E9F00 |
| `icon-assets/SKILL.md` | B0E0C8DEAF242C09F6EB92113A5DD5A8B50565ED344EB16EADBCE00DD9252641 |
| `image-compression/SKILL.md` | 69CEC5D93AAC6B6C58F4094462BDEEF40AE8B9E480AAF6ED3BA9D1CA446197C9 |
| `image-generation/SKILL.md` | 836A5F020ABC05CD4A844131B7129352FAA5F5EFC0E4883AC7D3018943B6629F |
| `implementation-planning/SKILL.md` | 1CAADB38ED965DC48A419466AF5B41DE94FC698E6662E4602B50701D22F87EC5 |
| `infographic-design/SKILL.md` | AC192A2E76ABBB625D037E5CBE7FF2A191C71E0D9986694102165FD118838AE4 |
| `integration-verification/SKILL.md` | 27020DA2BFA07A9D9EEB5199A1DB7C3999C49DC7F82DC78961CA992A5EF5E986 |
| `media-transcoding/SKILL.md` | 608E889D6073C67292F6A6FAB7EEC3D845C05AB1A8C30DC8B2E5F83C40BBCC28 |
| `merge-conflict-resolution/SKILL.md` | 077CC1E2E46378DB83C0B649375E982DB68DE757D903FE124DB2A5182B7CC514 |
| `observability/SKILL.md` | 5A086A43E39D4446BAEB07A83117717DE8EE355AD6BB2878BD1F8250E5D0DB21 |
| `performance-review/SKILL.md` | B870ABC4C5EE0951B63544EF0AEC0AF19EF00ADA3B9E2164CA6BA61A4B9C2309 |
| `postgres-practices/SKILL.md` | 24AA0C22AE1B146E6C65E35F881637AEC2E4A8EC490E44DEBB8D44E92C5A6570 |
| `product-design/SKILL.md` | 7D12D6D7488CB4392C40336706BE4D601552370E0199954EE2BC58A6DB55743C |
| `product-discovery/SKILL.md` | DA109B54CA1A9B1A176A229228BE04FA8D19AC2607753C254DB4566C712301C2 |
| `react-composition/SKILL.md` | FC06B200F21FDA984765C9F3508AD0D116F87D8213382CF64FE27E655F1C5EE2 |
| `react-performance/SKILL.md` | 1332B6A9442351EC62692E4B393F7A5270885ACB00F445813D9504E6F2C1740C |
| `requirements-analysis/SKILL.md` | D3A48C51A5A2836A9A891400CC39F3EB64056AAAFC22ECEDA074C49B154456A1 |
| `security-review/SKILL.md` | E65D3C830C6E3080666E67822421D4905940BA82A34C0E805ADB27E998F47232 |
| `solution-architecture/SKILL.md` | 8D92271780A73975ABCA70DFEF51EDADB3758E7316079A8061BB2FD384FFCF5D |
| `speech-production/SKILL.md` | 24D4C8C2FCA4CAA3B8FEFFCFF54B28CB5D3C6E182E6C87B1E9EA459288F4BC1A |
| `svg-logo-design/SKILL.md` | C35A379A9E6D74CF6F633C20006157B05630511C1F0EE4A87C29F8AC227724B6 |
| `systematic-debugging/SKILL.md` | 0F2D0FA14977C62592E7C1BB04BBD6EF59E5B2400BBD3E2CFA427E79AB1494FF |
| `technical-research/SKILL.md` | C787DB619895BBE89C188829C008445668C080A005676B27274BE7E40FFEFC4F |
| `test-driven-development/SKILL.md` | 1DD7FFB87EB72302788C9700D552FCC2C3C1664F070F5A06092656D01161539D |
| `visual-slide-deck/SKILL.md` | 1715531F45CD1E4495A9CCD17251D91F1B0C2C08815974382A7846157E1D0083 |
| `web-assets/SKILL.md` | 1D4BA90F0D257EA8E3C31B27652678D9DE8BCB03207575211C30C818220D9B42 |
| `LICENSE` | 7129B74272330BD7F3E542F64FB9047ABFE78F8204A444267137379CCC8158D0 |
