# Evidence Binding

This reference describes `schemas/evidence.schema.json` and the shipped `scripts/validate-git-evidence.ps1`. Git supplies commit/worktree facts; Orca supplies lifecycle authority. The coordinator checks active Task/Dispatch ownership, gathers observations, writes the evidence, then invokes the read-only validator. The validator never writes JSON, runs tests, merges, or queries Orca; PASS cannot authenticate a worker message or prove a recorded command really ran.

## Storage and ownership

Only the coordinator writes accepted evidence under the control tree's `.dev-work/runs/<run>/evidence/git/`. Workers write only their assigned report/evidence paths. Use `templates/dev-work/git-evidence.json` for each Task and `templates/dev-work/run-final-verification.json` for the single run record; replace every placeholder with an observed value.

- Task evidence: `runs/<run>/evidence/git/<task-key>.json`, normally referenced by assignment `evidence.gitEvidencePath`.
- Final evidence: exactly `runs/<run>/evidence/git/run-final-verification.json`; no per-task final files.
- `-ProjectRoot` is the coordinator control worktree (default: current directory), where `.dev-work` physically exists. The script may be invoked by absolute path from the installed package or a reviewed package worktree. Live source/delivery trees are located through Git; the control HEAD is not delivery evidence.
- Relative `-EvidencePath` resolves against ProjectRoot. Assignment `evidence.gitEvidencePath` and review `reportPath` resolve against `.dev-work`. Run-final `inputs.integratedEvidencePaths` resolve against the run directory. Absolute paths are accepted; loaded evidence must still reside under that run's `evidence/git/` directory.
- `run` is the local run slug, not the Orca Run ID; it must match `^[A-Za-z0-9][A-Za-z0-9._-]*$` and the existing run directory. Loaded records must agree on it. If run-state exists, integration and final target branches must match its `deliveryBranch`.

Read-only Tasks must explicitly declare `branch.mergeTarget: null` in their assignments. Recognition requires a matching `taskKey`, a `branch` object containing the key, and an actual JSON null value. An absent assignment/key, empty string, or string `"null"` does not grant the read-only review exception. Formal assignments use the delivery branch string. This declaration is required even though read-only work normally produces no source commit or integration.

## Record fields

The schema is version 1 and uses `additionalProperties: false` throughout the evidence objects; do not add lifecycle or arbitrary report fields. All SHAs are 40 lowercase hexadecimal characters and must resolve to existing local commits. Times use UTC `YYYY-MM-DDTHH:mm:ss[.fraction]Z`. Nonempty text fields, enum values and required members are schema-checked; `checks[].observed` may be empty for clean status.

| Record | Fields and constraints |
| --- | --- |
| Task | `schemaVersion: 1`, `run`, `subject: {kind: "task", taskKey}`, `state`, `source`; `reviews` required for reviewed/integrated, `integration` required for integrated |
| `source` | `branch`, `worktree`, `reportedCommit` (SHA or null), `workerDone: {messageId, taskId, dispatchId}`; `source.reportedCommit` is a worker observation, not an approval or a live HEAD guarantee |
| `reviews[]` | Nonempty when present; each entry has `reviewTaskKey`, `reviewer: {taskId, dispatchId}`, `verdict` (APPROVED / CHANGES_REQUIRED / UNVERIFIABLE), `reportPath`, `target: {branch, commitSha, dirty}`, `baseline: {branch, commitSha}`, `recordedAt` |
| `integration` admission | `sourceBranch`, `review: {reviewTaskKey, targetCommitSha}`, `admission: {sourceHeadSha, sourceWorktreeClean, deliveryWorktreeClean, checkedAt}`, `baselineBefore: {branch, commitSha}`; prepare these while state remains reviewed |
| `integration` result | Integrated state additionally requires `headAfter: {branch, commitSha}`, `reviewedSourcePresent`, `outcome`, `mergeEvidence: {command, exitCode, conflictFree}`, `resolution` (object or null), `checks[]`, `recordedAt`; `explanation` is optional in schema but required and nonblank for unchanged |
| `resolution` object | `resolverTaskKey`, `resultCommitSha`, `review: {reviewTaskKey, targetCommitSha}`; only advanced-with-resolution may carry a nonnull object |
| Run-final | `schemaVersion: 1`, `run`, `subject: {kind: "run"}`, `target: {branch, commitSha}`, `worktree`, `status` (planned / in_progress / verified / blocked), `coverage: {integratedTaskKeys, uncoveredTaskKeys}`, `inputs: {integratedEvidencePaths}`, `checks[]`, `verdict` (READY / NOT_READY / UNVERIFIABLE), `recordedAt` |
| `checks[]` | Nonempty array; each entry has `kind` (observation / verification), actual `command`, integer `exitCode`, `observed`, `at`, `commitSha`; coverage/input arrays contain unique nonempty strings |

Per-task states are only `source-registered`, `reviewed`, `integrated`. Pre-merge is a checkpoint within reviewed; final belongs to the run record. Phase names are not lifecycle states. A draft record can satisfy schema without satisfying its requested phase.

## Selector and coverage semantics

`-EvidencePath` and `-Run` are mutually exclusive. With neither, the validator reads `.dev-work/active-run.json`; without an active run it returns NOT_APPLICABLE. `-Phase` defaults to audit.

Both modes inspect all run assignments: a formal assignment has a nonblank `branch.mergeTarget`; it owes evidence if its status is one of `review, completed, integrating, integrated` or it declares a truthy `evidence.gitEvidencePath`. When no path is declared, the fallback is `runs/<run>/evidence/git/<taskKey>.json`. Required files must exist, pass schema/run/path/commit validation and match assignment subject kind/taskKey. During phase final, every formal assignment in those four statuses must point to integrated evidence. The script does not validate the whole assignment schema or query Runtime; keep `validate-run.ps1` as the separate structural gate.

| Selector | Actual scope and appropriate use |
| --- | --- |
| `-EvidencePath <task-json>` | Selects that Task for phase checks. `Test-Assignments` still checks required peer evidence existence, schema, run directory, commit existence and task identity (and final-state obligations in phase final). Its `CoverageTaskKey` guard requires membership in the selected entries only for the selected taskKey, so an existing valid peer is not rejected merely for being unselected. Peer review/integration phase checks and unrelated unreferenced evidence are not scanned. Use for rolling sourceRegistered/review/preMerge/postMerge checkpoints. |
| `-Run <run>` (or active-run selection) | Recursively loads every JSON under `evidence/git`, then checks assignment evidence membership across that complete set. Non-final phases run Task checks on every Task; audit additionally validates each run record if present. Final requires exactly one run record and validates its complete integrated coverage. Prefer this mode for run-wide audit/final; mixed-state runs may fail a uniform review/preMerge/postMerge request. |
| `-EvidencePath <run-final-json>` | Only final/audit are allowed. Loads the whole run evidence set, checks all assignment memberships and validates the selected record as the unique canonical run-final, including every integrated Task. |

A Task selected with `-Phase final` follows historical Task checks and the assignment final-state checks; it does not require or validate a run-final. It cannot establish run completion. Audit does not require a run-final when none exists; if one exists it must meet the run-final contract. Whole-run final also audits every integrated input, while nonintegrated Tasks outside assignment final obligations are not promoted to integrated automatically.

## Phase obligations

Always gather and write first, validate second, act only on PASS for the relevant scope. Read JSON `status`, not just process exit.

| `-Phase` | Coordinator writes before validation | Validator checks |
| --- | --- | --- |
| `sourceRegistered` | After matching active worker_done, register `source` and state source-registered, including message/Task/Dispatch identity and observed reportedCommit | Schema, run/path/assignment scope and recorded commit existence; no live source HEAD equality, clean-tree or review requirement beyond schema. It does not itself enforce source-registered state or compare source fields to Runtime. |
| `review` | Append independent reviews, record actual target/baseline SHA and dirty observation, set reviewed; preserve earlier reviews | State reviewed/integrated; reviews present; reviewer Task ID and Dispatch ID both differ from source worker's; report file exists; baseline is ancestor of target; formal target differs from baseline; APPROVED target is clean. A valid CHANGES_REQUIRED/UNVERIFIABLE record may PASS review validation, so PASS is not an approval verdict. |
| `preMerge` | After latest review APPROVED, write integration admission and baselineBefore in reviewed state | Review rules, binding to the last review's key/SHA/branch, approved SHA = admission sourceHeadSha, recorded clean flags true; current source branch HEAD equals approval, registered source worktree clean at that SHA, registered delivery worktree clean at baselineBefore, delivery branch HEAD equals baselineBefore. Read-only Tasks have no merge gate; after review checks they must have no integration. |
| `postMerge` | Capture successful admitted merge plus observations and actual verification at headAfter; complete integration and set integrated | Review/admission bindings; integrated state for source Tasks; current delivery HEAD/worktree at headAfter and clean; outcome, ancestry, merge-process and checks rules below. Read-only Tasks return after review checks and rejecting integration. |
| `final` | After all intended integrations, obtain release-verifier results from latest delivery in a clean independent worktree; write unique run-final | In run-final scope: unique canonical file, verified + READY, nonempty exact integrated coverage/inputs, empty uncovered set, intended assignment obligations, integrated-history validity/ancestry to final target, checks at target; target equals current delivery HEAD and verification tree is clean at that SHA in the same repository. Independent placement is a workflow duty; the script checks repository/HEAD/cleanliness, not worker identity. |
| `audit` | Preserve historical observations; select the run to audit the set | Schema/commits plus state-appropriate Task rules, review/admission/result checks as applicable and any existing run-final's coverage/checks. No current source/delivery HEAD equality or live worktree-cleanliness tests. Historical records can remain valid after branches advance or task worktrees are removed; objects and referenced reports/evidence must remain available. |

For audit/final Task checks, source-registered records return after base validation; reviewed records without integration stop after review checks. Reviewed records with integration also validate approval/admission bindings, but only integrated records undergo result checks. The source worktree path is recorded for provenance; live preMerge locates the branch worktree via `git worktree list`.

## Integration results and checks

All integrated records require latest APPROVED review binding, clean admission flags, `headAfter.branch == baselineBefore.branch`, `reviewedSourcePresent: true`, and both baselineBefore and approved target as ancestors of headAfter. Historical headAfter is not required to equal today's delivery HEAD. The final target must descend from each historical headAfter.

`mergeEvidence` must record exitCode 0, conflictFree true, and exactly `git merge --no-edit <sourceBranch>`. Source branch must match `^[A-Za-z0-9][A-Za-z0-9._/-]*$`; compound commands, interactive merge strings or manual-repair commands are rejected. Record the actual single merge, not an invented successful command. This is trusted local process evidence, not a replay or proof against arbitrary hooks/concurrent writes.

| `outcome` | Required result |
| --- | --- |
| `unchanged` | headAfter equals baselineBefore, approved target is already included, and explanation is nonblank; all ordinary review/merge/check rules still apply |
| `advanced-fast-forward` | headAfter equals approved target and differs from baselineBefore |
| `advanced-clean-merge` | headAfter differs from both; exactly two parents in order: baselineBefore first, approved target second. A normal conflict-free three-way merge is valid. |
| `advanced-with-resolution` | headAfter advances; nonnull resolution binds resultCommitSha to the same review key/target as integration.review, and result is ancestor of headAfter. The final admitted merge is still conflict-free. |
| `rejected` | Schema permits recording rejection, but integrated/covered records reject this outcome; it cannot justify completion |

On conflict or required source rewriting: abort the attempted delivery merge, preserve observations, create an isolated fix/resolution Task, independently review its result, then update the latest review/admission to that result and retry the gate. The coordinator must establish resolver Task provenance; the script checks the resolution SHA/review relationship, not the resolver's Runtime identity. Never resolve unreviewed changes directly in delivery or retain a dirty delivery tree.

For integration checks, record these exact successful observation strings with matching `observed` and `commitSha`:

| Observation command | `observed` | `commitSha` |
| --- | --- | --- |
| `git rev-parse <sourceBranch>` | Approved target SHA | Approved target SHA |
| `git rev-parse <deliveryBranch>` before merge | baselineBefore SHA | baselineBefore SHA |
| `git status --short` in source tree before merge | Empty string | Approved target SHA |
| `git status --short` in delivery tree before merge | Empty string | baselineBefore SHA |
| `git rev-parse <deliveryBranch>` after merge | headAfter SHA | headAfter SHA |
| `git status --short` in delivery tree after merge | Empty string | headAfter SHA |

Every check must exit 0. At least one `kind: verification` entry must have nonblank observed output and commitSha equal to headAfter, and every verification entry must bind that same SHA. Choose and actually run the applicable tests/gates; the validator does not judge their adequacy. Merge process evidence cannot substitute for checks. Run-final uses the two delivery rev-parse/clean-status observations at target.commitSha and actual verification entries at that same SHA, under identical successful-check rules.

## Final coverage and exit semantics

Run-final validation requires exactly one run-kind record at the canonical filename; no duplicate integrated taskKeys. `coverage.integratedTaskKeys` and `inputs.integratedEvidencePaths` must each be nonempty, cover every integrated Task exactly once and nothing else, and `coverage.uncoveredTaskKeys` must be empty. Each input must resolve to that run's integrated Task evidence, and each historical headAfter branch must equal final target.branch. Planned/in_progress/blocked or NOT_READY/UNVERIFIABLE records are useful drafts, but fail final/audit acceptance of a run-final. An empty-coverage run-final fails; do not manufacture an empty READY for a report-only run.

Output is JSON `{status, phase, errors, reason}`:

- `PASS`, exit 0: selected scope passed its applicable constraints; this is neither automatic review approval nor proof of an unselected final gate.
- `NOT_APPLICABLE`, exit 0: no active run, or run selection found no evidence entries and no assignment obligations produced errors; reason explains which. It is not PASS or READY. An explicitly missing run directory/file fails instead.
- `FAIL`, exit 1: schema/JSON/Git errors, unavailable commits/reports, invalid bindings, live drift/dirty trees, incomplete coverage or other violated constraints; `errors[]` explains. Rebuild or correct evidence and rerun; until resolved, do not merge or claim READY.

New runs and new Tasks must follow this workflow on adoption. Assignment `evidence` remains optional for old data, and `validate-run.ps1` does not invoke this validator by default. Old runs remain readable/archiveable without rewriting history; continuing a source merge requires rebuilding its evidence and passing all current checkpoints. Missing evidence for a formal assignment already in review/completed/integrating/integrated fails rather than becoming NOT_APPLICABLE. No scheduler, second lifecycle database, or Runtime command table is introduced.
