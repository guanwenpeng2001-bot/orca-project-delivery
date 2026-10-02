# Changelog

All notable changes to `orca-project-delivery`. The package is deployed in place from
`%USERPROFILE%\.agents\skills\orca-project-delivery`; `orca skills update` does not overwrite it
(`sourceKind: home`, absent from `~/.agents/.skill-lock.json`).

## 1.1.1

Follow-up batch after 1.1.0. Evidence: the claude-first routing change plus a real four-tier claude
delivery chain (`run_588c9434cc6c`) that ran reconnaissance, planning, implementation, independent
review, a fix, a re-review and the integration — one claude tier per stage.

### Claude priority in routing

- All 21 roles list their claude profile first and `codex-gpt-6-astra-medium` second; the remaining
  entries keep their previous relative order and duplicate claude entries were removed.
  `routing/agent-selection.json` and its mirror `agents/role-compatibility.json` stay identical.
- The four claude profiles move to `autoRouteAfterProbe: true` so they may legally sit first.
- Tiers are named for the effort they use: `claude-fable-max`, `claude-opus-max`,
  `claude-sonnet-high` (the level is chosen per dispatch, `low`..`max`) and `claude-haiku-default`.
  The `claude-haiku-max` rename was reverted because Orca's per-model option catalog rejects every
  effort value for `haiku`. `claude-haiku-default` is `qualityTier: standard` so the three
  reconnaissance roles' floor is met.

### Probe: claude CLI contract and Orca's option catalog

- A claude branch verifies the CLI contract: `--model` is advertised, `--effort` is advertised, and
  the declared effort is one the CLI enumerates (read from an unknown-value probe that contacts no
  backend). The alias-to-backend mapping remains host configuration and is not probed.
- Profiles whose `modelControl` is `orca-launch-preferences` are additionally checked against
  Orca's own per-model option catalog through a sentinel repo id that cannot exist, so the check can
  never launch a worker. The verdict is recorded as `orcaOptionVerdict`, and a combination Orca
  rejects makes the profile unverified.

### Verification harness

- New `routing/claude-first`: every role's `preferredProfiles[0]` must be an existing claude profile
  with `autoRouteAfterProbe: true`; a failure names the role and the actual first entry.
- New `metadata/routing-role-coverage`: the role key sets of both routing mirrors must match
  `roles/catalog.json` in both directions. Before this, deleting a role from both mirrors left the
  suite green.
- `verify-package.ps1` now runs 22 checks.

### Defects found by independent review and closed

- `verify-package.ps1`: malformed route entries (number, null, boolean, string) keep the role-level
  `<missing>` / `<not-an-array>` diagnostics instead of raising a host-language exception.
- `validate-run.ps1`: the same class of malformed input now reports a role-level error instead of
  raising a host-language exception.

## 1.1.0

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
- **F5 (follow-on discovery, same fix)** schema validation had never reported *anything*:
  `$errors = @()` is an `Object[]`, and binding it to a
  `[System.Collections.ArrayList]` parameter copies it by value, so every error raised inside the
  validator was discarded when the function returned. The accumulator is now a real `ArrayList`
  with `[void]$errors.Add(...)` at each call site. Without this, a recursive validator would still
  have been silent.
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

### Verification evidence (offline, reproducible)

Observed by the coordinator and by an independent verifier on Orca 1.4.218 / PowerShell 7.6.6 /
Windows. Every row is a real command run against the shipped files.

| Check | Command (abridged) | Observed |
| --- | --- | --- |
| Scripts parse / encoding | `[Parser]::ParseFile` on all 7 scripts; byte scan | 0 parse errors; no BOM; 0 CR; LF only |
| Host git env (F1) | `$env:GIT_CONFIG_COUNT=2` with no `GIT_CONFIG_KEY_0`, then bootstrap / create-run / reconcile-state / release-coordinator | all exit 0; a bare `git` in the same shell fails with `missing config key GIT_CONFIG_KEY_0` |
| Topology guard (F7) | bootstrap in a temp repo whose current branch is the delivery branch | exit 1 with the conflict named; `AGENTS.md` and `.dev-work` absent (zero writes); exit 0 on a control branch |
| Recursive schema (F5) | validate-run against crafted documents | missing `artifacts.evidencePath`, missing `branch.worktree`, unknown `skills` key, duplicate `completedStages`, invalid `workflow` enum → `ok:false` with JSON paths; compliant documents → `ok:true` |
| Probe verdicts (F3) | probe-agent-capabilities on a temp project | antigravity `verified=true` (`agy models` + `agy --help`); grok `verified=false` (effort not advertised); codex/kimi unchanged `verified=true` |
| Probe hardening (F14) | A/B on a CLI whose output exceeds 4 KB | pre-fix `grok --help` (7686 chars) → `timedOut` with 0 chars; post-fix → exit 0, 7511 chars; broken `opencode` → `detected=false` plus a warning |
| Assignment rendering (F13) | assemble-task in a temp project | role H1→`###` and role H2→`####` nested under `## Primary Role`; front matter in a ```yaml fence; 0 literal placeholders; AGENTS.md still last |
| Metadata coherence | routing vs role-compatibility, referenced profiles, `autoRouteAfterProbe` ordering, role/skill paths, manifest counts | equal / all present / 0 violations; manifest and VERSION both 1.1.0 |
| Registry keys (F12) | key census of `agents/registry.json` | 43 `skillDelivery` keys for 43 agents, no duplicate keys, Claude entries `explicit-path` |

### Post-verification fixes (independent verifier findings)

An independent verifier (V2/V3/V4/V9 plus adversarial probes) confirmed those cases PASS and found
five further defects; all are fixed here.

- **V-A** a repository whose default branch is neither `main` nor `master` could not be bootstrapped,
  and the refusal advised creating a control branch that was already checked out. The delivery branch
  is now resolved as explicit `-DeliveryBranch` → `origin/HEAD` → `init.defaultBranch` → `main` →
  `master` → the current branch, with the source recorded; `bootstrap-project.ps1` accepts
  `-DeliveryBranch`; and the refusal names the resolved branch, its source, and that flag. The guard
  still writes nothing.
- **V-B** a lock with `status = released` still blocked bootstrap, and the refusal advised a command
  that provably could not clear it. A released lock is now archived and taken over (new additive
  `lockLiveness` value `released`), while an `active` lock keeps the live/dead/unknown behavior.
- **V-C** `create-run.ps1 -RunSlug` accepted path traversal (`..\..\escaped-run` wrote a run tree
  outside `.dev-work`, and enough `..` escaped the project root). The slug must now match
  `^[A-Za-z0-9][A-Za-z0-9._-]*$` and the resolved run directory must stay inside
  `<gitRoot>\.dev-work\runs\`; both checks run before any write.
- **V-D** the liveness table in `references/coordinator-lock.md` described the `dead` row as "the
  handle is absent"; an absent handle is `unknown`, a recorded handle whose probe fails is `dead`.
- **V-E** `-Force` archived only the four state files. `reconciliation.json` is archived too, and the
  warning now reports how many other files were deliberately preserved.
- **V-F (accepted, deliberately unchanged)** `assemble-task.ps1` embeds `AGENTS.md` verbatim, so its
  own H1 is not demoted in the assembled prompt. Preserving project policy text byte-for-byte
  outranks heading cosmetics.
- **V-G (found while running V12)** the package never told an implementation worker to *commit* its
  work: `templates/task-spec.md` and `references/worker-contract.md` forbade merging but said nothing
  about committing, and a task that also forbade `git commit` produced a correct deliverable that the
  coordinator had to commit. Both documents now say the worker commits on its task branch before
  reporting and still never merges.
- **V-H (found while running V12)** `reconcile-state.ps1` compares `runs/<run>/assignments/*.json`
  with Git, but nothing told the coordinator to write those files — a run whose Tasks only had
  assembled `.md` briefs reconciled to an empty list. `SKILL.md` now requires recording the
  machine-readable assignment for every Task that has a branch and a report path.

Re-verified by the coordinator after the fixes: a `develop`-only repository refuses bootstrap with
zero writes and succeeds with `-DeliveryBranch develop`; the traversal slug exits 1 and writes
nothing; a released lock is archived (`lockLiveness: released`) and a fresh `active` lock is written.

### Real dispatch evidence (V10 / V11 / V12)

Run `run_1eacc8861006`, delivery branch `main` of the package repository itself
(`C:\Users\Administrator\.agents\skills\orca-project-delivery`, registered with Orca for this
exercise), coordinator control worktree `orca-project-delivery\opd-control`.

- **V10/V11 — the `turn_start_unobserved` recovery works, three out of three.** Three
  `worker-start` calls returned `state: outcome_unknown` / `stage: turn_start_unobserved` (codex had
  accepted the task but no turn start was observed). Each was handled exactly as the taxonomy now
  prescribes: `worker-show` to confirm the composer still held `[Pasted Content N chars]`, then a
  bare Enter into the **same** terminal — the agent started within 12–15 s. No re-dispatch, no
  abandon, no second writer. One transient `Stream disconnected before completion` recovered by
  itself and triggered no degradation.
- **V12 — the full source-delivery chain.** Implementation Task `task_5f2954a7c712`
  (codex `gpt-6-astra` medium) produced `scripts/verify-package.ps1` on `task-verify-package`;
  the independent review Task `task_718dbb0bc90c` (codex `gpt-6-astra` high) returned **APPROVED**
  after six real runs; the coordinator merged it into `main` (`a19221e`).
- **The final verification found a real integration defect.** Running the merged harness in the
  installed package exited 1: its `runtime/delivery-branch-refusal-zero-writes` check asserted the
  old bootstrap sentence, which the V-A fix had improved. Fix Task `task_cd6a258d12f0`
  (codex medium) replaced the sentence coupling with independent, case-insensitive topic checks
  (`control branch` and `delivery branch`) and kept the zero-write and hash-snapshot assertions;
  the coordinator reviewed the one-commit diff and merged it (`11676c9`).
- **Final verification `task_505914caa9c6` — READY**, run by a different Agent
  (**antigravity `gemini-3.8-flash-high` high**, the profile repaired by this remediation) in a fresh
  worktree from the merged `main`: harness 20/20 PASS exit 0, VERSION/manifest/file counts equal,
  `git diff c129d9f..HEAD` free of process artifacts, and a mutated copy still exits 1.
- All three codex dispatches and the antigravity dispatch reported
  `launch.requested == launch.effective`. `worker-list --terminal-state reclaimable` returned none
  at close.

Process lesson recorded for the coordinator: a worker Task Definition must name the deliverable
**inside the task worktree**. One fix Task named the installed path instead, and the worker wrote the
installed copy out of band; the coordinator reverted it with `git checkout --` so Git stayed the
single source of truth.

## 1.0.0 — baseline

- 82 files as installed on 2026-10-02. The pre-fix 77-file copy is kept at
  `%USERPROFILE%\.agents\skill-backups\orca-project-delivery-1.0.0-20261002-062822`.
