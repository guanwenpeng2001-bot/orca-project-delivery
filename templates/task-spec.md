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

## Review input

Use when `briefProfile` is `review`:

- Base SHA: `<40-char commit or merge-base>`
- Branch: `<review target branch>`
- Diff command: `<exact git diff command for the reviewer>`
- Delta paths (optional `deltaPaths`, for a re-review): `<paths changed since the reviewed revision>`

Review briefs include: Task Objective, Review input, Allowed Scope, Forbidden Scope, Branch and Worktree Contract, Process Artifact Contract, Acceptance Criteria, Verification, Orca Worker Contract, Orca Assignment Identity, and applicable `AGENTS.md` sections (last). Review input replaces Inputs and Dependencies; `reviewIncludes` may opt into `role`, `skills`, or `requirements` to include Primary Role, Required/Conditional Skills, or Declared Requirements respectively.

The task definition defaults to `taskKind: "source"`, `briefProfile: "standard"`, and `agentsSections: []`; omitting these fields preserves the same output. Set `taskKind` to `read-only` to omit the source commit clause. Set `agentsSections` to heading numbers or titles (for example `["5", "交付纪律"]`) to embed those sections and their descendants verbatim, in source order, at the end; unmatched selectors are errors. A review profile requires `reviewInput` with `baseSha`, `branch`, and `diffCommand`; an optional `deltaPaths` array names the paths changed since the reviewed revision and is printed into the brief. Bound role Skill lists are deduplicated when read-only, review, or a nonempty section selection is active; legacy/default briefs retain their existing bytes.

Assembling also checks every `scripts/<name>.ps1` command named in `acceptance` and `tests`: the script must exist in the package and each `-Parameter` after it must be declared by that script (common parameters count only for `[CmdletBinding()]` scripts). An unknown script or parameter fails assembly and writes no brief, so a hallucinated command can never reach a worker.

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
- Source/deliverable Tasks: commit your work within the authorized scope on the work branch before reporting; the coordinator reviews and merges it.
- Read-only Tasks: produce no commits and write only the assigned report path.
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

Record exact commands, relevant output, environment, skipped checks, and anomalies. Standard and read-only briefs add a `Minimum relevant suites` clause (task-named suites plus tests the change touches; runnable as `scripts/verify-package.ps1 -Suites '<name>'`; full gates stay at post-merge and final). Review briefs add `Re-verification scaled by the delta` and, when `reviewInput.deltaPaths` is present, list those paths above the clause.

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
