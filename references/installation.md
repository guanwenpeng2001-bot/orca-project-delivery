# Installation

The delivery package is installed as a single directory under the user's skills root (on Windows, `%USERPROFILE%\.agents\skills\orca-project-delivery`).

Do not overwrite existing Orca-provided Skills such as:

- `orchestration`
- `orca-cli`
- `orca-per-workspace-env`

This package adds `orca-project-delivery` only. All 16 professional Skills ship **inside** the package under `skills/<skill-id>/SKILL.md`; there is no separate sibling install or copy step. Upstream provenance is recorded in `skills/README.md`.

Use the global `orca-project-delivery` Skill from the coordinator control worktree. The Skill initializes or reuses project-local `AGENTS.md` and `.dev-work/`.

Deliver professional Skills to Claude Code workers with `explicit-path`: include each selected Skill's exact readable `SKILL.md` path in the Task (paths under this package's `skills/` directory). If the Worker cannot reliably read that path, use `inline-extract` and record the source path, hash/version, included headings, and omitted sections. A Skill name alone does not prove it was loaded; require evidence of the path read or method applied.

For prerequisites, verification (`scripts/verify-package.ps1`, expect `SUMMARY PASS=59 FAIL=0`), upgrade, uninstall, and troubleshooting, read `docs/installation.md`.
