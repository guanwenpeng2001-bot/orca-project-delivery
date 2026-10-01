# Assignment: <task title>

<!-- Heading map. `SKILL.md` "Worker input order" is normative (10 sections); this template
     keeps finer-grained headings for readability. Granularity may differ, order may not.
       Task Objective                    -> section 1
       Primary Role                      -> section 2
       Required Skills                   -> section 3
       Conditional Skills                -> section 3
       Inputs and Dependencies           -> section 4
       Allowed Scope                     -> section 5
       Forbidden Scope                   -> section 5
       Branch and Worktree Contract      -> section 6
       Process Artifact Contract         -> section 7
       Acceptance Criteria               -> section 8
       Verification                      -> section 8
       Orca Worker Contract              -> section 9
       Applicable Project Rules AGENTS.md-> section 10 (always last)
-->

## Task Objective

<One observable outcome.>

## Primary Role

- Role: `<role-id>`
- Role source: `<absolute-or-readable-path>`

## Required Skills

Read before starting:

- `<skill-name>` — `<SKILL.md path>`

## Conditional Skills

- `<skill-name>` — use only when `<condition>`

## Inputs and Dependencies

- `<input or artifact>`
- `<prerequisite branch/commit/report>`

## Allowed Scope

- `<path or subsystem>`

## Forbidden Scope

- `<path, operation, external side effect>`

## Branch and Worktree Contract

- Delivery branch: `<delivery-branch>`
- Base branch: `<base-branch>`
- Work branch: `<work-branch>`
- Worktree: `<path>`
- Merge target: `<delivery-branch or none>`
- You must not merge the branch yourself.

## Process Artifact Contract

- Shared process root: `<coordinator-worktree>\.dev-work`
- Assigned report path: `<absolute unique report path>`
- Evidence path: `<absolute unique evidence path>`
- Do not modify global run-state, branch-map, task-map, or other Task reports.
- If the sandbox cannot write the shared path, return the full report for coordinator storage.

## Acceptance Criteria

- [ ] `<observable criterion>`

## Verification

Run:

```text
<commands or manual checks>
```

Record exact commands, relevant output, environment, skipped checks, and anomalies.

## Orca Worker Contract

- Use lifecycle identity exactly from the injected Orca preamble.
- Execute only this Task.
- Check coordinator messages at natural checkpoints and before completion.
- Ask only when the decision cannot be made under project policy.
- Escalate true blockers.
- Send exactly one explicit completion outcome.
- Stop after completion; do not start new work or create sub-workers unless authorized.

---

# Applicable Project Rules — AGENTS.md

<Append applicable AGENTS.md content here, last.>
