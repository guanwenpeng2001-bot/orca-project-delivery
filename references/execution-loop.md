# Execution Loop

Read this reference before executing steps 6–12 of the [Execution loop](../SKILL.md#execution-loop) or [Review and integration](../SKILL.md#review-and-integration). The [Required invariants](../SKILL.md#required-invariants) govern every step; this reference preserves the operational obligations behind the entry's summaries.

## Dispatch and wait

6. Dispatch all independent ready Tasks before waiting, and keep ready work parallel; ready means its real dependencies settled successfully — a source dependency counts only after its own review and integration, never on `worker_done` alone — write scope disjoint from in-flight Tasks, and a usable baseline and Agent. Record Agent identity and fill assignment runtime evidence from the first `launch.effective` receipt, including `mode`/`surface`; unknown unrequested internal model/effort does not block dispatch. name background (`structured`) workers as such in user-facing reports, and treat a control-worktree placement as invalid — re-dispatch with an explicit `--worktree`.
7. Wait using `check --wait`; process every question/escalation, confirm worker_done belongs to the active Dispatch, decide the terminal's next owner, then acknowledge. After each confirmed settle, immediately re-evaluate readiness and dispatch newly ready Tasks (rolling dispatch) without waiting for unrelated in-flight Tasks.
8. After three consecutive empty waits, enumerate using `worker-list` and act on `projection.nextAction`; use bounded `worker-read` inspection where needed.
9. After matching `worker_done` to the active Task/Dispatch, advance the assignment to `review`; for a source Task, immediately dispatch review under **Independent review** and **Current verification**, alongside other implementation.
10. Record review verdicts in the run records; on CHANGES_REQUIRED dispatch fixes to the original implementer session and re-review to the original reviewer session under **Review and integration**. An unreadable or missing review report is UNVERIFIABLE, never approval.
11. After approval, confirm the source HEAD still equals the approved commit and both worktrees are clean, then integrate serially and run the full verification suite at the integrated HEAD before satisfying source dependencies. Apply **Artifact exclusion**; base later Tasks on updated delivery, then reclaim eligible worktrees.
12. At the **Current verification** barrier, dispatch release-verifier for full verification on latest delivery in a clean independent worktree; only its passing result authorizes READY. Write reports, summarize decisions, settle workers and release the coordinator.

## Settlement and recovery boundaries

A nonzero start receipt alone does not prove a failed attempt: inspect `failedStage` and `residualResources` using `references/failure-taxonomy.md`.
`outcome_unknown`, `turn_start_unobserved`, timeouts and unverifiable liveness do not authorize stop, abandon, retry or release.
User decisions use decision gates suspending only dependent Tasks; independent work proceeds. Resolve gates after the user decides.
Release is post-settlement cleanup. Record `retained` or `user_owned` decisions; explicitly resolve terminal ownership before removing its worktree.
Rolling dispatch changes no stage; only artificial batch waits between independent Tasks are removed.

## Review and integration

Apply **Independent review**, **Control separation**, and **Current verification** at the execution-loop steps. Review verdicts are `APPROVED`, `CHANGES_REQUIRED`, or `UNVERIFIABLE`; record the observed target SHA and clean status as one plain line per `templates/review-report.md` — an observation for traceability, not a binding block.
Narrow review input to the Task objective, acceptance criteria, exact `base..branch` diff bound to SHAs, and relevant contract clauses (`briefProfile: review`, `taskKind: read-only`, applicable `agentsSections`); do not require re-reading the whole package. Reviewers inspect affected context as needed.
Scale review effort to the run scale and the delta; verification exists to catch real defects, not to re-prove the process. A review on a lightweight run reads the diff and maps it to the acceptance criteria — it does not re-run verification batteries that already passed. Before dispatching any review, the coordinator runs the mechanical checks itself (credential scans, excluded-path sweeps, version-residue sweeps, file-set comparisons, HEAD/status observations) and attaches the results through `reviewInput.coordinatorEvidence` in the task definition, printed into the brief as evidence the reviewer audits rather than re-derives. The reviewer's budget goes to judgment, not re-execution.
Keep original implementer and reviewer terminals explicitly retained and unreleased until the final review verdict. After CHANGES_REQUIRED, create a fix Task for the original implementer and a re-review Task for the original reviewer: use `worker-start --terminal <settled worker terminal>` with `--worktree <that terminal's worktree>` for each. This resumes the same writer sequentially, never a second writer. If a terminal is gone or reuse fails, record the reason before a cold session; apply runtime recovery and the writer-replacement gate where applicable. See [Session reuse](worker-handoff.md#fix-returns-to-original-implementer-session) for admission and evidence.
Workers run only Task-relevant verify suites and affected tests (`scripts/verify-package.ps1 -Suites '<name>'`), recording coverage and skips; explicit Task-required checks still apply. Run the full suite at post-merge integration and again at final verification in a clean independent worktree from latest `delivery_branch`.
After approval, the coordinator confirms the source branch HEAD still equals the approved commit and both source and delivery worktrees are clean; drift requires re-review. The coordinator performs Git merge in the delivery worktree; Orca has no merge primitive.
Integrate serially in dependency order. Conflicts require abort, an isolated resolution Task, independent re-review and a fresh merge attempt; never repair unreviewed source in delivery. Run the full verification suite at each integrated HEAD before later Tasks base on it.
Remove task worktrees and safe-to-delete branches only after integration or explicit abandonment and terminal ownership resolution.

Bare repository paths in this reference are relative to the package root; Markdown links are relative to this file.
