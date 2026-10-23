# Professional capability tutorial

**English** | [简体中文](zh-CN/professional-capability-tutorial.md)

Use the [installed external Skill walkthrough](external-skills.md) for version 2 project registration, mixed bindings, resolved requirement selectors and original sibling resources. No separate installation is required for bundled Skills.

This tutorial targets the complete **3.1.0 package: 69 Skills, 18 Roles, and 5
workflows**. It exercises local tools, offline provider fixtures, and scoped
dependency injection using a temporary project and synthetic values. No actual
provider or paid call is made; offline simulation does not verify generation
quality.

Run the PowerShell blocks in order in a PowerShell 7 session from the package
root, with Node.js 22.15+ (the baseline documented by the bundled Skills) and Python 3.10+ available
for the examples that use them.
Install the complete matching 3.1.0 release first. A version that does not
match lacks the scripts these commands use. The guard rejects an incomplete or mismatched installation.

## 1. Confirm what you installed

From the package directory:

```powershell
Get-Content -Raw .\VERSION
Get-Content -Raw .\PACKAGE-MANIFEST.json
```

Read four fields:

| Field | What it tells you |
| --- | --- |
| `VERSION` | The package revision. 3.1.0 is the current release. |
| `deliverables.professionalSkills` | How many Skills the package claims. The 3.1.0 release claims 69. |
| `deliverables.roles` | How many Roles the package claims. The 3.1.0 release claims 18. |
| `workflows/` | How many workflow definitions ship. The 3.1.0 release ships 5. |

Then confirm the claim against the catalogs rather than against this tutorial:

```powershell
$skills = (Get-Content -Raw .\routing\skill-catalog.json | ConvertFrom-Json).skills.Count
$roles = (Get-Content -Raw .\roles\catalog.json | ConvertFrom-Json).roles.Count
"catalog skills: $skills"
"catalog roles: $roles"
```

Require both the release target and internal consistency; an older 16/12
catalog that matches its own manifest still cannot run these examples.

```powershell
$manifest = Get-Content -Raw ./PACKAGE-MANIFEST.json | ConvertFrom-Json
$version = (Get-Content -Raw ./VERSION).Trim()
$workflows = (Get-ChildItem ./workflows -Filter *.md).Count
"catalog workflows: $workflows"
if ($version -ne '3.1.0' -or $manifest.version -ne $version -or
    $skills -ne 69 -or $roles -ne 18 -or $workflows -ne 5 -or
    $manifest.deliverables.professionalSkills -ne $skills -or
    $manifest.deliverables.roles -ne $roles -or
    $manifest.deliverables.workflows -ne $workflows) {
  throw 'Install the complete matching 3.1.0 package before continuing.'
}
"GUARD_PASSED skills=$skills roles=$roles version=$version"
```

## 2. Verify the package offline

```powershell
pwsh -NoProfile -File .\scripts\verify-package.ps1
```

Acceptance is exit code 0 and a final line containing `FAIL=0`. The `PASS`
count is not a constant: it describes the revision you are running, so quote
the line you observed rather than a remembered number.

This is an **offline verification** of package structure: parsing, encoding,
routing, and catalog counts, plus offline behavior tests. When local Python
Playwright and Chromium are present, its optional browser test launches that
local browser; otherwise it records a named skip. Document read-back requires
`-DocumentPython` pointing to an interpreter with the pinned libraries. The
suite makes no provider call and does not establish generation quality.

## 3. See the capabilities

Read [Professional capabilities](professional-capabilities.md). For each new
Skill, note which of the four labels it carries:

- **Method** — software, local assets other than icon lookup, image planning,
  code video, transcoding, documents.
- **Implemented local tool** — the dependency helpers exercised in the next
  section, plus the CLIs a Skill names once the package declares them.
- **Offline verification** — the suite you just ran.
- **Real online, not verified** — image generation, generated video, speech,
  transcription, and the Iconify lookup inside `icon-assets`.

No label upgrade is implied by installing the package.

## 4. Run the dependency helpers offline

The helpers answer one question: given a project root, a Role, and the Skill
IDs a task selected, which declared CLI and environment names are present, and
which file values would reach a child process. They do not choose Skills for
you, they do not read a coordinator's `.env`, and they do not contact a
network.

Their parameters, as implemented in this revision:

| Script | Required | Optional |
| --- | --- | --- |
| `scripts/check-requirements.ps1` | `-ProjectRoot <string>`, `-Role <id>` | `-Skills <string[]>`, `-ConfigPath <string>` |
| `scripts/invoke-with-requirements.ps1` | `-ProjectRoot <string>`, `-Role <id>`, `-Executable <string>` | `-Skills <string[]>`, `-ConfigPath <string>`, `-Arguments <string[]>` |

`-ProjectRoot` is the execution host's project directory, passed explicitly.
There is no default. Scope is selected by the caller: pass exactly the
required Skill IDs plus the conditional ones this task activates, and nothing
is injected for a Skill you did not pass.

Run the following inside a PowerShell 7 session, so `@(...)` binds as an
array. The values are fake. Nothing here is a credential, and nothing is sent
anywhere.

```powershell
$package = (Resolve-Path '.').Path
$project = Join-Path ([IO.Path]::GetTempPath()) ('orca-capability-demo-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $project | Out-Null
@'
EXAMPLE_EXPORT_MODE=fixture
'@ | Set-Content -LiteralPath "$project/.env" -Encoding utf8
```

Check a Role that ships in every revision, with one of its real Skills and no
configuration file:

```powershell
& "$package/scripts/check-requirements.ps1" -ProjectRoot $project -Role software-implementer -Skills @('integration-verification')
$checkExit = $LASTEXITCODE
```

Expected: exit 0, JSON with `ok: true`. The original sixteen declare no CLI,
env, or API requirements, so the check passes on an empty project. That
result shows the helper runs; it does not show that a new Skill's
requirements are satisfied, because no new Skill was selected.

Remove the temporary project when you are done:

```powershell
Remove-Item -Recurse -Force $project
```

## 5. Run the local capability examples

These commands run in the package root and write only to a fresh temporary
directory. They use the stable scripts and flags shipped since 2.3.0. No
provider is contacted.

```powershell
$work = Join-Path ([IO.Path]::GetTempPath()) ('orca-local-capability-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
node ./skills/image-compression/scripts/png-compressor.mjs --sample "$work/sample.png"
node ./skills/image-compression/scripts/png-compressor.mjs --input "$work/sample.png" --output "$work/compressed.png"
$pngExit = $LASTEXITCODE
node ./skills/web-assets/scripts/web-asset-manifest.mjs --name Harbor --color '#123456' --output "$work/manifest.json"
$manifestExit = $LASTEXITCODE
node ./skills/document-production/scripts/markdown-document.mjs --input ./tests/fixtures/capability/document-input.json --output "$work/notes.md"
$markdownExit = $LASTEXITCODE
```

Expected exits are all `0`. Compression prints JSON with `status: "compressed"`
and byte counts. A lossless candidate that is not smaller prints
`status: "no-gain"` and creates no output file. The manifest names Harbor,
records `#123456`, and lists the five icon sizes. Markdown contains the title
and bullet from the fixture. Keep `$work` until all examples below finish, then remove it.

The Office/PDF generator is:

```powershell
python -I ./skills/document-production/scripts/office-document.py --input ./tests/fixtures/capability/document-input.json --format docx --output "$work/notes.docx"
```

Replace `docx` and `.docx` with `pptx`, `xlsx`, or `pdf` as needed. Success
prints JSON with `reopened: true`. A missing library prints
`missing-dependency` and exits `2`; document or input failure exits `1`.
Install the exact versions pinned in
`skills/document-production/scripts/requirements.txt` only in an environment
you choose. Non-ASCII PDF text also requires `--font` pointing at a licensed
TrueType font that covers its glyphs. Programmatic generation and read-back of
docx, pptx, xlsx, and pdf were verified in an isolated environment. Target
application layout, fonts, visual appearance, and any real provider call were
not verified.

### Asset acceptance

These are acceptance criteria for a task's actual output, not claims that every check has passed. Record the command, exit code, artifact path, and observed result for each applicable row; mark checks not run explicitly.

| Skill | Check | Acceptance |
| --- | --- | --- |
| `icon-assets` | Open the chosen SVG; review its source and icon-set license record. | Correct icon and viewBox, no clipping at target size, source and license recorded. A network lookup requires separate execution approval. |
| `svg-logo-design` | Parse the SVG and open it at the intended small and large sizes. | Valid SVG, readable shape, no clipping or unexpected external references; visual review is separate from parsing. |
| `web-assets` | Reopen exported files, read dimensions, and resolve the manifest's icon paths. | Requested dimensions/formats, preserved transparency where required, all manifest files exist. |
| `image-compression` | Validate input/output PNG structure and compare decoded pixels, alpha, and byte lengths. | Valid chunks/CRCs and identical lossless pixel content; record actual savings or explicit no-gain. Invalid input must fail without a new output. |

The same scripts also accept bounded blocks beyond the title and bullets. A
`heading`, a `paragraph`, an ordered `list`, and a `table` render in Markdown,
and the `table` is a real table in docx and xlsx. pptx and pdf have no table
and reject a `table` block by name instead of dropping it. Cell text stays
literal, so a cell containing `=SUM(A1:A2)` is stored as text and never
evaluated. Write this source to `$work/blocks.json`:

```powershell
@'
{"title":"Berth notes","blocks":[
  {"type":"heading","text":"Berth plan"},
  {"type":"paragraph","text":"One fact per paragraph."},
  {"type":"list","ordered":true,"items":["Sound the depth","Record the draft"]},
  {"type":"table","columns":["Berth","Draft m"],"rows":[["North","12.4"]]}
]}
'@ | Set-Content -LiteralPath "$work/blocks.json" -Encoding utf8
node ./skills/document-production/scripts/markdown-document.mjs --input "$work/blocks.json" --output "$work/blocks.md"
```

The Markdown contains the heading, the paragraph, a numbered list, and a table
whose cells hold `North` and `12.4`. The same input with `--format docx` and
`--format xlsx` reopens with `reopened: true`. `--format pptx` and
`--format pdf` exit `1` and name the rejected `table` block. A newline inside a
cell is kept by docx and xlsx, flattened to a space by Markdown, and rejected
by pptx. Nothing here checks whether a table overflows its page or how a font
substitutes in a target viewer; read-back is not visual acceptance.

With the pinned libraries present, expected exits are `0, 0, 1, 1`:

```powershell
python -I ./skills/document-production/scripts/office-document.py --input "$work/blocks.json" --format docx --output "$work/blocks.docx"
python -I ./skills/document-production/scripts/office-document.py --input "$work/blocks.json" --format xlsx --output "$work/blocks.xlsx"
python -I ./skills/document-production/scripts/office-document.py --input "$work/blocks.json" --format pptx --output "$work/blocks.pptx"
python -I ./skills/document-production/scripts/office-document.py --input "$work/blocks.json" --format pdf --output "$work/blocks.pdf"
```

## 6. Run the 2.4.0 local tools

These commands were introduced in 2.4.0 and remain available in 3.1.0. The file-processing commands run offline and write only under `$work`.
They require Node.js 22.15+; the optional browser test also needs Python
Playwright and a local Chromium. No command contacts a provider.

Contrast of black on white is 21:1, which passes both the 4.5:1 text threshold
and the 3:1 boundary threshold. Gray `#777777` on white does not reach 4.5:1,
so the second command exits `2`:

```powershell
node ./skills/frontend-visual-design/scripts/contrast-ratio.mjs --foreground "#000000" --background "#FFFFFF"
node ./skills/frontend-visual-design/scripts/contrast-ratio.mjs --foreground "#777777" --background "#FFFFFF" --threshold 4.5
```

The first prints JSON with `ratioRounded: 21` and `meets.text: true`. A color
that is not `#RGB` or `#RRGGBB` exits `1` with the reason on stderr.

The subtitle converter turns the bundled SRT fixture into WebVTT and back. The
cue count is the same in both directions, and a timestamp with trailing text
exits `1` without touching an existing output file:

```powershell
node ./skills/subtitle-production/scripts/subtitle-convert.mjs --input ./tests/fixtures/capability/subtitle-media-sample.srt --output "$work/sample.vtt" --to vtt
node ./skills/subtitle-production/scripts/subtitle-convert.mjs --input "$work/sample.vtt" --output "$work/sample-back.srt" --to srt
```

Both print JSON with `cues` and `warnings`. The converter handles text cues
only. It does not style, position, or burn subtitles into video, and WebVTT
hours above 99 cannot round-trip into SRT, which exits `1`.

The composition check reads the bundled sample and prints its frame map. It
never renders, so it needs neither HyperFrames nor a browser:

```powershell
node ./skills/code-video-production/scripts/composition-check.mjs --input ./tests/fixtures/capability/subtitle-media-sample.html --fps 30
```

The output reports `frames: 300`. Overlapping clips on one track exit `1`. A
frame map is not a rendered video; no HyperFrames render is claimed here.

The probe comparison reads two saved ffprobe JSON documents and never runs
ffprobe itself. The bundled pair matches at 640x360; a duration outside the
tolerance exits `1`:

```powershell
node ./skills/media-transcoding/scripts/probe-compare.mjs --source ./tests/fixtures/capability/subtitle-media-source-probe.json --output ./tests/fixtures/capability/subtitle-media-output-probe.json --width 640 --height 360
```

Matching probes print `matched: true`. Comparing probes is not a transcode, and
the encoder and build license of any installed FFmpeg are checked separately.

`png-resize.mjs` shrinks an 8-bit non-interlaced RGB or RGBA PNG and refuses a
request that is not smaller. `image-info.mjs` reads a PNG, JPEG, or WebP header
and reports format, width, height, alpha, and color type without decoding
pixels. Both need an image you supply; the package ships no binary fixtures.
Build a master with the compressor's own sample flag, then shrink it:

```powershell
node ./skills/image-compression/scripts/png-compressor.mjs --sample "$work/master.png"
node ./skills/image-compression/scripts/png-resize.mjs --input "$work/master.png" --output "$work/icon-32.png" --width 32 --height 32
node ./skills/image-generation/scripts/image-info.mjs --input "$work/icon-32.png"
```

The resize prints `status: "resized"` with the requested dimensions. The header
check prints `format: "png"`. Asking to resize to the master's own size exits
`1` with `not smaller`, and a truncated header exits `1`. Header data is not a
decoded image: a file can pass `image-info.mjs` and still be corrupt.

The browser sample has two journeys: saving a tide reading and refusing a blank
time. The regression suite checks both and detects an intentionally seeded
defect. It uses Python Playwright with an existing Chromium under the Windows
`LOCALAPPDATA/ms-playwright` directory. Missing prerequisites skip only the
relevant tests, with a named reason; a runner call reports an error, not a pass.

```powershell
node --test ./tests/design-browser.test.mjs
```

The optional browser portion was exercised locally on Windows with Python
3.14.6 and Chromium revision 1234. This does not establish cross-platform
support or accessibility of another application. To inspect the fixture
manually, run `node ./skills/browser-e2e/scripts/serve-fixture.mjs` in a separate
terminal, open its printed loopback URL, and stop that server when finished.
Serving a page is not running the journeys.

The engineering methods also ship offline fixture checks:

```powershell
node --test ./skills/mcp-server-development/examples/protocol-shapes.test.mjs ./skills/technical-diagrams/examples/diagram-semantics.test.mjs ./skills/localization/examples/message-consistency.test.mjs
```

These assert MCP request/error shapes, SVG source semantics, and locale
keys/placeholders. They start no MCP server, render no diagram, and call no
translation service. The authoring rubric, domain model, migration sequence,
and design tokens have worked examples in their respective Skill files;
applying those methods requires reviewing the task’s actual artifacts.

PNG resizing checks CRCs and bounds decompression to the declared image,
with a source limit of 4096 × 4096 pixels in total. Both axes must shrink;
palette, gray, 16-bit and interlaced sources are rejected. RGB `tRNS` becomes
alpha before box averaging; color-management and other unsupported chunks
(such as `gAMA`, `sRGB`, `iCCP`, `pHYs`, `bKGD`, `zTXt`, `iTXt`) are rejected
by name before replacing a destination. This is resampling, not lossless compression.

Subtitle conversion rejects overlap, reversed duration, cue settings, voice
spans, STYLE/REGION and invalid UTF-8. Dropped cue identifiers and NOTE blocks
appear in warnings; an empty source reports zero cues with a warning. The
100000-hour ceiling is tool policy, not a WebVTT specification ceiling.

Composition input is a bounded HTML attribute grammar, not arbitrary
HyperFrames: one root, numeric timing, integer track indices, whole-frame
durations, and integer or rational fps. In-track gaps, cross-track overlap and
clip overruns warn; uncovered composition end fails. Probe comparison checks
the first video stream and audio presence, not every stream or decoded quality;
its default duration tolerance is one output frame and fps tolerance is 0.001.

## 7. Run offline provider fixtures

Fixture mode uses `--request` and `--fixture` and a built-in synthetic key. It
never reads a real provider key and reports `networkCalled: false`. Do not add
`--online`; combining it with `--fixture` is rejected. These examples do not
measure generation quality.

```powershell
node ./skills/image-generation/scripts/openai-image-request.mjs --request ./tests/fixtures/capability/openai-image-request.json --fixture ./tests/fixtures/capability/openai-image-success.json --output "$work/image.png"
$imageSuccess = $LASTEXITCODE
node ./skills/image-generation/scripts/openai-image-request.mjs --request ./tests/fixtures/capability/openai-image-request.json --fixture ./tests/fixtures/capability/openai-image-failure.json --output "$work/failed-image.png"
$imageFailure = $LASTEXITCODE
node ./skills/generated-video/scripts/pexo-video-request.mjs --request ./tests/fixtures/capability/pexo-video-request.json --fixture ./tests/fixtures/capability/pexo-video-submitted.json
$videoAck = $LASTEXITCODE
node ./skills/generated-video/scripts/pexo-video-request.mjs --request ./tests/fixtures/capability/pexo-video-request.json --fixture ./tests/fixtures/capability/pexo-video-timeout.json
$videoTimeout = $LASTEXITCODE
node ./skills/speech-production/scripts/elevenlabs-speech-request.mjs --request ./tests/fixtures/capability/elevenlabs-speech-request.json --fixture ./tests/fixtures/capability/elevenlabs-speech-success.json --output "$work/speech.mp3"
$speechSuccess = $LASTEXITCODE
node ./skills/audio-transcription/scripts/elevenlabs-transcription-request.mjs --request ./tests/fixtures/capability/elevenlabs-transcription-request.json --fixture ./tests/fixtures/capability/elevenlabs-transcription-failure.json --audio "$work/speech.mp3" --output "$work/transcript.json"
$transcriptionFailure = $LASTEXITCODE
$previousOnlineGate = $env:CAPABILITY_ONLINE_PROVIDERS_ENABLED
try {
  $env:CAPABILITY_ONLINE_PROVIDERS_ENABLED = 'false'
  node ./skills/image-generation/scripts/openai-image-request.mjs --online --request ./tests/fixtures/capability/openai-image-request.json --output "$work/online.png"
  $disabledOnline = $LASTEXITCODE
} finally {
  $env:CAPABILITY_ONLINE_PROVIDERS_ENABLED = $previousOnlineGate
}
```

Expected codes are `0`, `3`, `0`, `4`, `0`, `3`, and `2`, in that order. Image
and speech success save files. Image and transcription fixtures model HTTP
failure. The Pexo success fixture is only an SSE submission acknowledgement;
timeout exits `4`. The final command temporarily disables the online gate and exits `2` with
`online-disabled`, then restores the prior gate value without printing it.

## 8. Real execution requires explicit opt-in

The provider scripts default to offline mode. `--request <JSON path>`,
`--output <path>`, and `--fixture <JSON path>` exercise local request/response
handling without contacting a provider. Fixtures and injected transports do
not verify credentials, billing, provider availability, or generation quality.
No actual paid call was made during this documentation work.

Real execution requires **both** `--online` and
`CAPABILITY_ONLINE_PROVIDERS_ENABLED=true`, plus the selected provider's
required configuration. An environment flag is a technical gate, not approval:
a user must first approve the provider, budget, and upload scope for the task.
This section describes that path; it does not run it.

| Connector | Script under `skills/` | Real-execution details |
| --- | --- | --- |
| OpenAI image example | `image-generation/scripts/openai-image-request.mjs` | `OPENAI_IMAGE_MODEL` overrides the request's `model`. |
| Pexo video example | `generated-video/scripts/pexo-video-request.mjs` | `--action submit\|status\|download`; status uses `project_id`, download also uses `asset_id`. Submission acknowledgment is not a finished video. Follow the returned `nextAction`; do not automatically approve billing or resubmit. |
| ElevenLabs speech example | `speech-production/scripts/elevenlabs-speech-request.mjs` | Save the returned audio and verify it separately before claiming usable speech. |
| ElevenLabs transcription example | `audio-transcription/scripts/elevenlabs-transcription-request.mjs` | `--audio <path>` supplies the file for multipart `file`/`model_id`. Uploading a recording requires approval. |

The scripts accept `--timeout-ms` (default `60000`). Read JSON stdout's
`networkCalled` and saved-success `output`; a pending response instead requires
following its `nextAction`. Never interpret an acknowledgment alone as a saved
media artifact.

| Exit | Meaning |
| --- | --- |
| `0` | Successful result or submission acknowledgment; inspect the response. |
| `1` | Invalid input or filesystem failure. |
| `2` | Online execution disabled or required configuration missing. |
| `3` | Provider/response failure. |
| `4` | Timeout. |
| `5` | Pending or further action required. |

## 9. When something fails

| What you see | What it means |
| --- | --- |
| Manifest count differs from the catalog count | The package revision is inconsistent. Stop; do not average the two numbers. |
| `verify-package.ps1` prints any `FAIL` line | The install is not accepted, whatever the `PASS` count. See [Installation](installation.md). |
| `check-requirements.ps1` exits 1 with an unknown Role or Skill | That ID is not in this revision's catalogs. Either this version does not match the documented release, or the ID is misspelled. |
| `configured: true` but `availableForChild: false` | An empty process value is masking the file. Do not print the value. |
| A provider call fails | Out of scope here. Presence was never evidence of a working provider. |

## Related

- [Professional capabilities](professional-capabilities.md) for the per-Skill contract.
- [Installation](installation.md) for prerequisites and the full suite.
- [Extending](extending.md) for the registration and configuration rules these helpers implement.
