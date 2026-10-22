# Installation

The delivery package is installed as a single directory under the user's skills root (on Windows, `%USERPROFILE%\.agents\skills\orca-project-delivery`).

Do not overwrite existing Orca-provided Skills such as:

- `orchestration`
- `orca-cli`
- `orca-per-workspace-env`

This package adds `orca-project-delivery` only. The 3.0.0 package contains 46 professional Skills, 16 Roles and 4 workflows. All 46 bundled professional Skills ship **inside** the package under `skills/<skill-id>/SKILL.md`; there is no separate sibling install or copy step. Bundled provenance is recorded in `skills/README.md`. Already-installed third-party Skills may additionally be registered through explicit version 2 project configuration; see the [external Skill walkthrough](../docs/external-skills.md). No automatic installation or scanning occurs, and originals remain untouched.

Use the global `orca-project-delivery` Skill from the coordinator control worktree. The Skill initializes or reuses project-local `AGENTS.md` and `.dev-work/`.

Deliver professional Skills to Claude Code workers with `explicit-path`: include each selected Skill's exact readable `SKILL.md` path in the Task (bundled paths under `skills/`, or explicitly registered external paths). If the Worker cannot reliably read that path, use `inline-extract` and record the source path, included headings, and omitted sections. A Skill name alone does not prove it was loaded; require evidence of the path read or method applied.

The original sixteen are maintained MIT adaptations; the later thirty are original methods with public references; the upstream license notice is retained in `skills/README.md`. For native Role/Skill registration, dependency declarations, execution-host configuration and offline examples, read [docs/extending.md](../docs/extending.md).

Bootstrap creates only missing `.env.example` and `project-config.example.json`, preserves existing examples, and locally excludes `/.env` through clone-shared Git `info/exclude`. It never copies coordinator values to workers or creates a populated `.env`. Keep `.dev-work/` in the control tree.

Use `scripts/verify-package.ps1 -MetadataOnly` for a quick structural check after extension; run the full suite before acceptance. Counts follow the catalogs and manifest rather than a fixed extension limit.

For prerequisites, verification (`scripts/verify-package.ps1`, require exit 0 and `SUMMARY PASS=<observed> FAIL=0`), upgrade, uninstall, and troubleshooting, read `docs/installation.md`.
