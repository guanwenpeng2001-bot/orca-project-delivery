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

A repair-round assignment that was replaced without independent integration may use `status: superseded`. Optional schema fields `supersededBy` and `supersedes` are nonempty logical task keys, not Runtime IDs; omit them when unused. For a formal superseded assignment, `supersededBy` is mandatory at evidence validation: it must identify exactly one different formal assignment in this run, in `review`, `completed`, `integrating` or `integrated`, with the same delivery branch and valid phase-appropriate evidence. At `sourceRegistered`, `review` and `preMerge`, successor evidence must be `reviewed` or `integrated`: reviewed evidence receives review-level checks, without live preMerge Git assertions on an unselected successor; integrated evidence always receives integrated-history audit checks. At `postMerge`, `audit` and `final`, integrated successor evidence is required. Missing, ambiguous, self-referencing, cyclic, cross-run or not-entered successors fail in every phase. These successor checks apply even under single-Task selection; an optional `supersedes` backlink is descriptive and never grants exemption. Point directly to the successor logical task, not through a chain of superseded rounds. Retain the replaced assignment and any existing evidence; only its own evidence-file/integrated obligation is waived, and existing evidence remains subject to run-wide checks.

## Dispatch assignment evidence

On every dispatch, write `runs/<run>/assignments/<task>.json`, even when an assembled Markdown brief exists:

- `runtime.requested`: literal agent/model/effort sent to Orca;
- `runtime.effective`: only values from the first `launch.effective` receipt; unknown fields are null;
- `runtime.verification.status`: `verified`, `mismatch`, or `unverified`, with evidence;
- `runtime.mode` (`mode`, `preferred`, `reason`) and the terminal `surface`, so a background session is recorded as background;
- permission mode, Skill delivery, Task/Dispatch, branch/worktree/report paths and top-level `fallbackReason`.

`scripts/dispatch-task.ps1` writes this record from the coordinator-captured `worker-start` receipt and refuses a receipt whose worktree effect is the coordinator control worktree or contradicts the task definition.

`artifacts.briefPath` records the absolute assembled-brief path and `artifacts.briefSha256` records the lowercase SHA-256 of its raw bytes at dispatch recording; both are echoed in the dispatch output. This ledger proves which brief bytes were recorded at dispatch, not that the worker received or read them. A receipt claim requires dispatch-bound worker-side evidence, such as the worker's recorded first read; its authenticity has the same recorder-honesty limit as `source.workerDone` below. Mechanical delivery acknowledgement belongs to Orca and is outside this package.

Unknown profile fields are null. Matching requested/effective profiles are `verified` only when effective `model` or `effort` is non-null; profiles with no usable route value are `unverified`, with a note distinct from missing profile blocks. Differences remain `mismatch`, and an equal alias-fallback model with null effort remains verifiable.

Parameter acceptance does not prove effectiveness; reconcile mismatches before treating the requested route as verified.

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

`source.workerDone` IDs must match `^msg_[0-9a-f]{12}$`, `^task_[0-9a-f]{12}$` and `^ctx_[0-9a-f]{12}$`, respectively. These constraints check format only. The existence, content and Task/Dispatch association of `messageId` cannot be mechanically verified by this local validator: it is the recorder's honesty declaration, with credibility no higher than the recorder. A fabricated but correctly formatted ID can pass; the coordinator must consult Runtime when recording real messages. Template placeholders are intentionally invalid and must be replaced with observed IDs.

Assignment status permits `planned`, `starting`, `active`, `review`, `completed`, `integrating`, `integrated`, `superseded`, `failed`, `abandoned`, `unverifiable`; these are local workflow records, not additional Runtime lifecycle authority.

Per-task states are only `source-registered`, `reviewed`, `integrated`. Pre-merge is a checkpoint within reviewed; final belongs to the run record. Phase names are not lifecycle states. A draft record can satisfy schema without satisfying its requested phase.

## Selector and coverage semantics

`-EvidencePath` and `-Run` are mutually exclusive. With neither, the validator reads `.dev-work/active-run.json`; without an active run it returns NOT_APPLICABLE. `-Phase` defaults to audit.

Both modes inspect all run assignments, first validating the superseded exemption above: a non-superseded formal assignment has a nonblank `branch.mergeTarget`; it owes evidence if its status is one of `review, completed, integrating, integrated`, **or if its recorded work branch has actually reached `mergeTarget`** — work that landed owes a record whatever the status label says. When no path is declared, the fallback is `runs/<run>/evidence/git/<taskKey>.json`. Required files must exist, pass schema/run/path/commit validation and match assignment subject kind/taskKey. During phase final, every formal assignment in those four statuses, or whose work landed, must point to integrated evidence. The landed test resolves `branch.work` and `branch.mergeTarget` in Git; a reclaimed work branch or an unresolvable `mergeTarget` counts as not-landed, so historical runs stay readable and `unverifiable`/`failed`/`abandoned` remain usable for work that genuinely never reached delivery. The script does not validate the whole assignment schema or query Runtime; keep `validate-run.ps1` as the separate structural gate.

| Selector | Actual scope and appropriate use |
| --- | --- |
| `-EvidencePath <evidence-json>` | Selects that Task for phase checks. `Test-Assignments` still checks required peer evidence existence, schema, run directory, commit existence and task identity (and final-state obligations in phase final). Its `CoverageTaskKey` guard requires membership in the selected entries only for the selected taskKey, so an existing valid peer is not rejected merely for being unselected. Peer review/integration phase checks and unrelated unreferenced evidence are not scanned, except that a superseded assignment's successor always receives the phase-appropriate review or integrated-history checks above. Use for rolling sourceRegistered/review/preMerge/postMerge checkpoints. |
| `-Run <run>` (or active-run selection) | Recursively loads every JSON under `evidence/git`, then checks assignment evidence membership across that complete set. Non-final phases run Task checks on every Task; audit additionally validates each run record if present. Final requires exactly one run record and validates its complete integrated coverage. Prefer this mode for run-wide audit/final; mixed-state runs may fail a uniform review/preMerge/postMerge request. |
| `-EvidencePath <run-final-json>` | Only final/audit are allowed. Loads the whole run evidence set, checks all assignment memberships and validates the selected record as the unique canonical run-final, including every integrated Task. |

A Task selected with `-Phase final` follows historical Task checks and the assignment final-state checks; it does not require or validate a run-final. It cannot establish run completion. Audit does not require a run-final when none exists; if one exists it must meet the run-final contract. Whole-run final also audits every integrated input, while nonintegrated Tasks outside assignment final obligations are not promoted to integrated automatically.

## Phase obligations

Always gather and write first, validate second, act only on PASS for the relevant scope. Read JSON `status`, not just process exit. A validation failure is UNVERIFIABLE, never approval.

At a rolling checkpoint, invoke `scripts/validate-git-evidence.ps1 -ProjectRoot <control-tree> -EvidencePath <evidence-json> -Phase sourceRegistered`, where `<evidence-json>` is `.dev-work/runs/<run>/evidence/git/<task-key>.json` relative to ProjectRoot, or its absolute path. Record the next phase's fields before invoking `review`, `preMerge`, or `postMerge`. After all intended integrations, use `-Run <run> -Phase final`; use `-Run <run> -Phase audit` for historical evidence. See the selector rules above before substituting a file selector.

| `-Phase` | Coordinator writes before validation | Validator checks |
| --- | --- | --- |
| `sourceRegistered` | After matching active worker_done, register `source` and state source-registered, including message/Task/Dispatch identity and observed reportedCommit | Schema, run/path/assignment scope and recorded commit existence; no live source HEAD equality, clean-tree or review requirement beyond schema. It does not itself enforce source-registered state or compare source fields to Runtime. |
| `review` | Append independent reviews, record actual target/baseline SHA and dirty observation, set reviewed; preserve earlier reviews | State reviewed/integrated; reviews present; reviewer Task ID and Dispatch ID both differ from source worker's; report file exists; baseline is ancestor of target; formal target differs from baseline; APPROVED target is clean. A valid CHANGES_REQUIRED/UNVERIFIABLE record may PASS review validation, so PASS is not an approval verdict. |
| `preMerge` | After latest review APPROVED, write integration admission and baselineBefore in reviewed state | Review rules, binding to the last review's key/SHA/branch, approved SHA = admission sourceHeadSha, recorded clean flags true; current source branch HEAD equals approval, registered source worktree clean at that SHA, registered delivery worktree clean at baselineBefore, delivery branch HEAD equals baselineBefore. A formal superseded fold may point to a reviewed successor; its review checks pass before integration, while audit/final still require integrated successor evidence. Read-only Tasks have no merge gate; after review checks they must have no integration. |
| `postMerge` | Capture successful admitted merge plus observations and actual verification at headAfter; complete integration and set integrated | Review/admission bindings; integrated state for source Tasks; current delivery HEAD/worktree at headAfter and clean; outcome, ancestry, merge-process and checks rules below. Read-only Tasks return after review checks and rejecting integration. |
| `final` | After all intended integrations, obtain release-verifier results from latest delivery in a clean independent worktree; write unique run-final | In run-final scope: unique canonical file, verified + READY, nonempty exact integrated coverage/inputs, empty uncovered set, intended assignment obligations, integrated-history validity/ancestry to final target, checks at target; target equals current delivery HEAD and verification tree is clean at that SHA in the same repository. Independent placement is a workflow duty; the script checks repository/HEAD/cleanliness, not worker identity. |
| `audit` | Preserve historical observations; select the run to audit the set | Schema/commits plus state-appropriate Task rules, review/admission/result checks as applicable and any existing run-final's coverage/checks. No current source/delivery HEAD equality or live worktree-cleanliness tests. Historical records can remain valid after branches advance or task worktrees are removed; objects and referenced reports/evidence must remain available. |

For audit/final Task checks, source-registered records return after base validation; reviewed records without integration stop after review checks. Reviewed records with integration also validate approval/admission bindings, but only integrated records undergo result checks. The source worktree path is recorded for provenance; live preMerge locates the branch worktree via `git worktree list`.

## Integration results and checks

All integrated records require latest APPROVED review binding, clean admission flags, `headAfter.branch == baselineBefore.branch`, `reviewedSourcePresent: true`, and both baselineBefore and approved target as ancestors of headAfter. Historical headAfter is not required to equal today's delivery HEAD. The final target must descend from each historical headAfter.

`mergeEvidence` must record exitCode 0, conflictFree true, and the single non-interactive merge of the reviewed branch that actually ran. The command must be one `git merge` of exactly `<sourceBranch>`, carrying a message flag (`--no-edit`, `-m`, `--message`, `-F` or `--file`); options such as `--no-ff` are accepted, because forcing a merge commit is how a conflict-free three-way merge produces the parents `advanced-clean-merge` requires. Source branch must match `^[A-Za-z0-9][A-Za-z0-9._/-]*$`; compound or chained commands, a second ref, an abort, a non-merge command, or an invocation with no message flag (which would block on an editor) are rejected. Record the actual merge, not an invented successful command. This is trusted local process evidence, not a replay or proof against arbitrary hooks/concurrent writes.

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

Archive the **full** post-merge and final verification output in the evidence log; the coordinator reads only the `SUMMARY`/JSON result lines from it. A log that keeps the summary line alone (observed regression: 300 KB of output collapsed to 252 B) cannot be audited later and does not carry the force of the run it recorded.

## Final coverage and exit semantics

Run-final validation requires exactly one run-kind record at the canonical filename; no duplicate integrated taskKeys. `coverage.integratedTaskKeys` and `inputs.integratedEvidencePaths` must each be nonempty, cover every integrated Task exactly once and nothing else, and `coverage.uncoveredTaskKeys` must be empty. Each input must resolve to that run's integrated Task evidence, and each historical headAfter branch must equal final target.branch. Planned/in_progress/blocked or NOT_READY/UNVERIFIABLE records are useful drafts, but fail final/audit acceptance of a run-final. An empty-coverage run-final fails; do not manufacture an empty READY for a report-only run.

Output is JSON `{status, phase, errors, reason}`:

- `PASS`, exit 0: selected scope passed its applicable constraints; this is neither automatic review approval nor proof of an unselected final gate.
- `NOT_APPLICABLE`, exit 0: no active run, or run selection found no evidence entries and no assignment obligations produced errors; reason explains which. It is not PASS or READY. An explicitly missing run directory/file fails instead.
- `FAIL`, exit 1: schema/JSON/Git errors, unavailable commits/reports, invalid bindings, live drift/dirty trees, incomplete coverage or other violated constraints; `errors[]` explains. Rebuild or correct evidence and rerun; until resolved, do not merge or claim READY.

New runs and new Tasks must follow this workflow on adoption. Assignment `evidence` remains optional for old data, and `validate-run.ps1` does not invoke this validator by default. Old runs remain readable/archiveable without rewriting history; continuing a source merge requires rebuilding its evidence and passing all current checkpoints. Missing evidence for a formal assignment already in review/completed/integrating/integrated, or whose recorded work branch has landed in the delivery branch, fails rather than becoming NOT_APPLICABLE. A status label is not a waiver: relabelling a landed integration `unverifiable`, `failed` or `abandoned` does not release its evidence obligation, and those statuses stay usable only for work that genuinely never reached delivery. No scheduler, second lifecycle database, or Runtime command table is introduced.
