# Installation

The delivery contains the canonical Skill tree in the user's `.agents` directory, under `skills`.

On Windows, copy or merge it into:

```text
%USERPROFILE%\.agents\skills\
```

Do not overwrite existing Orca-provided Skills such as:

- `orchestration`
- `orca-cli`
- `orca-per-workspace-env`

The package adds `orca-project-delivery` and professional Skills only.

Use the global `orca-project-delivery` Skill from the coordinator control worktree. The Skill initializes or reuses project-local `AGENTS.md` and `.dev-work/`.

Deliver professional Skills to Claude Code workers with `explicit-path`: include each selected Skill's exact readable `SKILL.md` path in the Task. If the Worker cannot reliably read that path, use `inline-extract` and record the source path, hash/version, included headings, and omitted sections. A Skill name alone does not prove it was loaded; require evidence of the path read or method applied.
