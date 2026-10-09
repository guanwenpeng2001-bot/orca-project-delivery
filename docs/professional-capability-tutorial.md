# Professional capability tutorial

**English** | [简体中文](zh-CN/professional-capability-tutorial.md)

This tutorial installs nothing new and calls no provider. It does three things:
it reads the capability contract, it proves the package verifies offline, and
it runs the existing dependency helpers against a temporary project with fake
values. That is the part of 2.3.0 that is executable today.

What this tutorial deliberately does not do:

- It does not render a video, generate an image, synthesize speech, or
  transcribe audio. Those are real online or local-execution steps, and none
  of them has been run for this release.
- It does not add the 22 new Skills or 4 new Roles to a catalog. Registration
  belongs to the capability package; this tutorial only consumes a package
  that already contains it.
- It does not invent command flags. The commands below are the helpers as they
  exist in this revision. A walkthrough for the new Skills arrives only after
  their interface is part of the package, and is checked against that package
  before it is published.

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

The two counts must equal the manifest fields. If they do not, the package is
internally inconsistent and the rest of this tutorial does not apply; stop and
report the mismatch instead of continuing.

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

### What changes when a new Skill declares a requirement

Once the capability package declares `requires` for a Skill, the same two
commands apply without new flags. Select the Skill explicitly and the helper
checks only what that Skill declares:

```powershell
& "$package/scripts/check-requirements.ps1" -ProjectRoot $project -Role media-producer -Skills @('image-compression')
```

Read the result as four separate facts, not one verdict:

| Field | Meaning |
| --- | --- |
| `configured` | A nonempty value exists in a file. |
| `availableInProcess` | A nonempty value exists in the current process. |
| `availableForChild` | The value that would reach a child. An empty process value overrides a nonempty file. |
| `networkVerified` | Always `false` for an API check. Presence is not authentication, credit, or reachability. |

Do not run that example until `media-producer` and `image-compression` are in
the catalogs of the package you are running. Against this revision the helper
rejects it with `Unknown role selector.` and exits 1, which is the correct
result; an unknown Skill ID fails the same way with `Unknown skill selector.`

## 5. Know what was not run

| Step | Label | Run in this tutorial |
| --- | --- | --- |
| Read `VERSION`, the manifest, and the catalogs | Method | Yes |
| `verify-package.ps1` | Offline verification | Yes |
| `check-requirements.ps1` on `software-implementer` | Implemented local tool | Yes |
| Browser, PostgreSQL, FFmpeg, HyperFrames, document libraries | Implemented local tool, where the package declares them | No. Not claimed. |
| OpenAI image, Pexo video, ElevenLabs speech or transcription | Real online, not verified | No. These are example connectors, not selected providers. |

An example connector shows the shape of a future configuration: a secret env
name such as `OPENAI_API_KEY`, `PEXO_API_KEY`, or `ELEVENLABS_API_KEY`, an
`authEnv` pointing at it, and an API check that returns `networkVerified:
false`. The names are placeholders taken from the upstream each example names.
No key is supplied, no endpoint is called, and choosing among providers remains
a user decision made per task, with a budget and an upload scope.

## 6. When something fails

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
