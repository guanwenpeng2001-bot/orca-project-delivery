# Installation

The delivery contains `.agents/skills/` as the canonical Skill tree.

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

Claude Code does not natively use `.agents/skills` as its documented global root. Use Orca's managed Skill placement/alias behavior rather than manually duplicating the library where supported.
