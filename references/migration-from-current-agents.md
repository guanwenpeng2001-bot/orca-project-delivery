# Migration from the Existing Monolithic AGENTS File

Move content by responsibility:

| Existing content | New destination |
| --- | --- |
| Project decision ownership | `AGENTS.md` |
| Naming, YAGNI, minimal implementation | `AGENTS.md` |
| One writer per branch | `AGENTS.md` and branch adapter |
| Coordinator business workflow | `orca-project-delivery/SKILL.md` and workflows |
| Fixed reconnaissance lanes | Remove; use dynamic reconnaissance |
| Read-only workers in coordinator worktree | Remove; every Task gets a worktree |
| `.pi/` | Rename to `.dev-work/` |
| Orca commands | Current global `orchestration` / `orca-cli` Skills |
| Role-to-Agent/model table | Agent profiles and Role routing |
| Kimi/Grok quota exception | Fallback policy / run-level override |
| One-run terminal exception | Run decision record, not project policy |

## Legacy process data

If `.pi/` exists:

1. Do not overwrite it.
2. Move or copy it to `.dev-work/archive/legacy-pi/`.
3. Classify known reports under a run where possible.
4. Keep unclassified content untouched until reviewed.
