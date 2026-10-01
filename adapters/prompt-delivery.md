# Worker Prompt Assembly

## Required section order

`SKILL.md` ("Worker input order") is normative. Ten sections, in this order:

1. Task Objective
2. Primary Role
3. Required and conditional Skills
4. Inputs and dependencies
5. Allowed and forbidden scope
6. Branch and worktree contract
7. `.dev-work` report contract
8. Acceptance criteria and tests
9. Orca Worker Contract
10. Applicable `AGENTS.md` content

`AGENTS.md` is appended last.

A Task spec may split section 5 into two headings (Allowed scope / Forbidden scope) and
section 8 into two (Acceptance criteria / Verification). That changes granularity only —
never the order. `templates/task-spec.md` carries the heading-to-section map.

## Existing AGENTS behavior

- If no project `AGENTS.md` exists, bootstrap from the template.
- If one exists, preserve it exactly.
- Do not silently migrate or overwrite user policy.
- When nested `AGENTS.md` files apply, append from general to specific; the closest applicable policy is last.
- The coordinator may include only applicable sections for a very large file, but must name the source file and included headings.

## Role delivery

Inline the selected Role contract or provide a verified readable path. A Worker receives exactly one Primary Role.

## Skill delivery

Use `agents/skill-loading.json` and `adapters/skill-delivery.md`.

## Report paths

Every Task receives one exclusive report path under the coordinator's `.dev-work/runs/<run>/`.

If cross-worktree writing is denied, the Worker returns the full report to the coordinator, who stores it.

## No hidden requirements

Exact values, paths, acceptance conditions, and prohibited operations belong in the Task Contract. Do not rely on coordinator conversation history.
