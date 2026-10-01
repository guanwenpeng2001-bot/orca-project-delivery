# Changelog

All notable changes to `orca-project-delivery`. The package is deployed in place from
`%USERPROFILE%\.agents\skills\orca-project-delivery`; `orca skills update` does not overwrite it
(`sourceKind: home`, absent from `~/.agents/.skill-lock.json`).

## Unreleased — 1.1.0

Evidence base: in-place remediation driven by the 2026-10-02 audit on Orca 1.4.218 / PowerShell
7.6.6 / Windows, including one real read-only orchestration run (`run_048c16f28004`:
bootstrap → run-create → create-run → assemble-task → worker-start → check → worker_done →
settle → release → validate → probe → release-coordinator).

Plan and finding IDs: `orca-project-delivery-remediation-plan.md` (F1–F20).
Decisions taken: D-A antigravity model id corrected and the probe now verifies it for real;
D-B an unattended-execution policy is stated in `templates/AGENTS.md`; D-C cross-provider
fallback requires recorded user authorization; D-D the real source-delivery end-to-end run
happens after this batch is merged.

### W0 — Baseline and traceability

- Package placed under Git: baseline commit captures the installed 82-file v1.0.0 state.
- `.gitattributes` pins `-text`, so the tree stays LF and byte-stable across checkouts.

### W1 — Blocking fixes

- **F1** every script that shells out to git now drops an orphaned `GIT_CONFIG_COUNT` (a host that
  injects the count while stripping variable names containing `KEY` made every git call fail with
  `fatal: missing config key GIT_CONFIG_KEY_0`) and reports git's real error instead of hiding it
  behind `2>$null`.
- **F2** new failure class `turn_start_unobserved` (taxonomy, fallback policy, runtime adapter,
  `SKILL.md` execution loop): a non-zero `worker-start` receipt is unobserved, not failed — inspect,
  submit the already-accepted task in the same terminal, never re-dispatch.
- **F3** `antigravity` profile model corrected to `gemini-3.8-flash-high`, and the probe now decides
  `verified` from real evidence (`agy models`, `agy --help`, agent config) for both the model and the
  effort; `grok-4.7-xhigh` no longer claims a verified effort it cannot evidence.
- The "unverifiable" rule is now single and explicit: not auto-routable, still manually selectable,
  never recorded as effective without a launch receipt (`routing/agent-selection.json`,
  `adapters/model-selection.md`).

### W2 — Correctness

- **F5** `validate-run.ps1` gained a recursive schema validator (nested `required`, `items`,
  `enum`, `const`, `minLength`, `uniqueItems`, `additionalProperties: false`) with JSON-path error
  messages.
- **F6/F7** the delivery-branch default is `main` → `master` → current branch with its source
  recorded, in `SKILL.md`, `adapters/branch-worktree.md` and `templates/AGENTS.md`; bootstrap
  refuses a control worktree whose current branch is the resolved delivery branch unless
  `-AllowControlEqualsDelivery` is passed deliberately.
- **F8** the `worker_done` example in `references/worker-contract.md` now carries the required
  `--subject`.
- **F13** `assemble-task.ps1` demotes embedded role/contract headings by two levels, renders role
  front matter as a fenced `yaml` block, and preserves path casing in its JSON output.

### W3 — Safety and metadata

- **F9** `templates/AGENTS.md` states the unattended-execution policy so `project-policy` resolves
  deterministically; `permission-presets.json` and `adapters/permission-selection.md` record that
  `worker-start` has no permission flag and that permission comes from the Agent configuration and
  the user's Orca settings.
- **F10** cross-provider fallback requires authorization recorded as `allowCrossProviderFallback`
  (new optional run-state field, default off); otherwise the Task suspends for a user decision.
- **F11** bounded in-place retries must confirm the previous attempt is not still writing.
- **F12** `registry.json` no longer contradicts `skill-loading.json` on Claude skill delivery, and
  carries host/version anchors instead of an unattributed snapshot.

### W4 — Robustness, consistency, Orca primitives

- **F14** probe hardening: pipes drained before waiting, `detected` decided by execution result,
  no `command` for undetected agents, portable home-directory resolution.
- **F15** `references/installation.md` no longer hard-codes an absolute user path.
- **F16** `release-coordinator.ps1` scopes its reclaimable-worker query to the active Run and
  documents that a released worker terminal can legitimately stay `retained`/`user_owned`; removing
  a task worktree orphans its terminal, so close it explicitly.
- **F17** `SKILL.md` now says `.dev-work/` is initialized by the bootstrap script and that
  `templates/dev-work/` are schema-validated references.
- **F19** Orca primitives now referenced by the workflow: decision gates for user decisions,
  `worker-read` for bounded inspection, the wait → enumerate (`worker-list` `nextAction`) escalation
  ladder, and explicit dependency creation for Task ordering.
- **F20** `Omni\hind\.dev-work\` leftover resolved by a deliberate decision (recorded below).

## 1.0.0 — baseline

- 82 files as installed on 2026-10-02. The pre-fix 77-file copy is kept at
  `%USERPROFILE%\.agents\skill-backups\orca-project-delivery-1.0.0-20261002-062822`.
