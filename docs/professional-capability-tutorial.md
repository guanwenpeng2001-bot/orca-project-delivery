# Professional capability tutorial

**English** | [简体中文](zh-CN/professional-capability-tutorial.md)

This tutorial targets the complete **2.3.0 package: 38 Skills and 16 Roles**.
It exercises local tools, offline provider fixtures, and scoped dependency
injection using a temporary project and synthetic values. No actual provider
or paid call is made; offline simulation does not verify generation quality.

Run the PowerShell blocks in order in a PowerShell 7 session from the package
root, with Node.js and Python available for the examples that use them. A
documentation-only checkout on the older 2.2.0 runtime lacks the new scripts;
relative links and commands here refer to the combined 2.3.0 tree.

## 1. Confirm what you installed

From the package directory:

```powershell
Get-Content -Raw .\VERSION
Get-Content -Raw .\PACKAGE-MANIFEST.json
```

Read three fields:

| Field | What it tells you |
| --- | --- |
| `VERSION` | The package revision. 2.3.0 is the capability release. |
| `deliverables.professionalSkills` | How many Skills the package claims. The capability release claims 38. |
| `deliverables.roles` | How many Roles the package claims. The capability release claims 16. |

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
if ($version -ne '2.3.0' -or $manifest.version -ne $version -or
    $skills -ne 38 -or $roles -ne 16 -or
    $manifest.deliverables.professionalSkills -ne $skills -or
    $manifest.deliverables.roles -ne $roles) {
  throw 'Install the complete matching 2.3.0 package before continuing.'
}
```

## 2. Verify the package offline

```powershell
pwsh -NoProfile -File .\scripts\verify-package.ps1
```

Acceptance is exit code 0 and a final line containing `FAIL=0`. The `PASS`
count is not a constant: it describes the revision you are running, so quote
the line you observed rather than a remembered number.

This is an **offline verification** of package structure: parsing, encoding,
routing, catalog counts, and current Skill hashes. It does not launch a
browser, a database, an encoder, or a model. A passing run is not evidence
about generated output.

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

## 5. Run local capability examples

These commands run in the complete 2.3.0 package root and write only to a fresh
temporary directory. They use the stable scripts and flags verified against the
capability runtime checkout. No provider is contacted.

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
and bullet from the fixture. Remove `$work` when finished.

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
TrueType font that covers its glyphs. This tutorial environment lacked those
libraries, so Office/PDF generation was not executed here.

### Asset acceptance

These are acceptance criteria for a task's actual output, not claims that every check has passed. Record the command, exit code, artifact path, and observed result for each applicable row; mark checks not run explicitly.

| Skill | Check | Acceptance |
| --- | --- | --- |
| `icon-assets` | Open the chosen SVG; review its source and icon-set license record. | Correct icon and viewBox, no clipping at target size, source and license recorded. A network lookup requires separate execution approval. |
| `svg-logo-design` | Parse the SVG and open it at the intended small and large sizes. | Valid SVG, readable shape, no clipping or unexpected external references; visual review is separate from parsing. |
| `web-assets` | Reopen exported files, read dimensions, and resolve the manifest's icon paths. | Requested dimensions/formats, preserved transparency where required, all manifest files exist. |
| `image-compression` | Validate input/output PNG structure and compare decoded pixels, alpha, and byte lengths. | Valid chunks/CRCs and identical lossless pixel content; record actual savings or explicit no-gain. Invalid input must fail without a new output. |

## 6. Run offline provider fixtures

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
node ./skills/image-generation/scripts/openai-image-request.mjs --online --request ./tests/fixtures/capability/openai-image-request.json --output "$work/online.png"
$disabledOnline = $LASTEXITCODE
```

Expected codes are `0`, `3`, `0`, `4`, `0`, `3`, and `2`, in that order. Image
and speech success save files. Image and transcription fixtures model HTTP
failure. The Pexo success fixture is only an SSE submission acknowledgement;
timeout exits `4`. The final command exits `2` with `online-disabled` unless
real execution is separately enabled.

## 7. Real execution requires explicit opt-in

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

## 8. When something fails

| What you see | What it means |
| --- | --- |
| Manifest count differs from the catalog count | The package revision is inconsistent. Stop; do not average the two numbers. |
| `verify-package.ps1` prints any `FAIL` line | The install is not accepted, whatever the `PASS` count. See [Installation](installation.md). |
| `check-requirements.ps1` exits 1 with an unknown Role or Skill | That ID is not in this revision's catalogs. Either the capability package is not merged, or the ID is misspelled. |
| `configured: true` but `availableForChild: false` | An empty process value is masking the file. Do not print the value. |
| A provider call fails | Out of scope here. Presence was never evidence of a working provider. |

## Related

- [Professional capabilities](professional-capabilities.md) for the per-Skill contract.
- [Installation](installation.md) for prerequisites and the full suite.
- [Extending](extending.md) for the registration and configuration rules these helpers implement.
