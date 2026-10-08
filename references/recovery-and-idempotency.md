# Recovery and Idempotency

Principle-level guidance for the recovery situations this package keeps
revisiting: a lifecycle mutation whose outcome is unknown, duplicate or late
completions, an invisible worker, re-dispatch after a proven failure, writer
replacement, Task cancellation, and an unknown coordinator lock.

This reference freezes **no** command lines, parameter lists, or receipt
shapes. The Orca runtime is the authority; this file only constrains how the
package classifies a situation and which actions are safe.

## Authority order

1. The recovery / next-action guidance carried by the mutation receipt itself.
2. Current `--help` output of the orchestration CLI and the installed global
   `orchestration` Skill, including its recovery-and-cleanup reference.
3. The scenario principles in this file.

When runtime guidance and this file disagree, follow the runtime, then revise
this file. Where this file expects a runtime behaviour that current evidence
has not confirmed, treat it as *not yet evidenced* — never assert that the
runtime lacks the capability.

## Scenario principles

### Dispatch mutation outcome unknown

A start or settle request returned no usable receipt, or the response was lost.

**Principle.** Treat the mutation as *possibly applied*. Confirm the state of
the affected Task, Dispatch, and terminal through runtime queries and the
receipt's own recovery guidance before deciding anything. "My query found
nothing" is not "nothing happened" — a different caller identity, run scope,
or an unpropagated write can hide an applied mutation from the first query.

**Prohibited.** Do not replay the mutation blindly. Do not guess transcript,
session, or terminal identifiers to shortcut the search. Do not start a second
worker while the first attempt's state is unresolved.

### Duplicate or late `worker_done`

The same completion arrives twice, or a completion from an earlier attempt
arrives after a newer attempt is active.

**Principle.** Settle exactly once, matched precisely against the active Task
and Dispatch. A completion that matches no active Dispatch — duplicate,
replayed, or from a superseded attempt — settles nothing and is accounted as
such. Process already-delivered messages first-in-first-out and only then
acknowledge.

**Prohibited.** Do not let a late completion overwrite the current attempt's
outcome. Do not count a replayed message as a new failure — it would feed the
failure circuit breaker twice. Do not open a replacement Dispatch to
"duplicate-proof" the Task.

### Worker invisible / liveness unverifiable

`missing_status`, `unverifiable` liveness, an empty wait, or a silent
terminal.

**Principle.** Absence is a checkpoint, not a verdict. Keep waiting, or
inspect within a bounded window, and distinguish what each positive signal
ends: proven liveness ends the *invisibility* — the worker is alive, so
keep waiting — while only observed exit, a final transcript whose last
agent turn sent no `worker_done`, or an authoritative settlement ends the
*wait*.

**Prohibited.** No stop, abandon, retry, release, or model downgrade from
absence alone. Do not treat a timeout as process exit. Do not classify
silence as quota exhaustion or capacity failure.

### Re-dispatch after a proven failure

The failure has positive evidence: an accepted `failed` completion, a proven
exit, or an explicit runtime failure receipt.

**Principle.** Re-dispatch only the proven-failed attempt, in the original
Task context, with explicit placement, and respect the runtime circuit
breaker: once one Task's consecutive failures trip the breaker, the Task is
failed and the next decision is suspension or re-planning — not another
attempt. When the failed worker is a writer on a task branch, this section
governs only the retry of the attempt — the replacement writer must still
pass the writer-replacement gate below.

**Prohibited.** Do not re-dispatch from unproven failure (`unknown`,
`missing_status`, timeout). Do not route around the breaker with a new Run, a
renamed Task, or an unrelated Dispatch. Do not let a retry inherit placement
silently.

### Writer replacement (hardened gate)

The failed or silent worker is a **writer** on a task branch.

**Principle.** Two decisions must not be conflated. Retrying one proven
`failed` or `stopped` attempt is a runtime decision: when a mutation
receipt or an authoritative projection proves that state, its own
next-action guidance authorizes the retry. Whether a **new writer** may
take over the same task branch is a separate decision, and this package
deliberately holds it to a stricter local convention, in the same spirit as
the coordinator-lock convention in `references/coordinator-lock.md`:
`failed`, silence, and timeout each fail to prove that the original writer
has stopped — an accepted `failed` settles the attempt while the writer's
terminal and process can still be live. A replacement writer may start only
after both:

1. the original writer is confirmed stopped, fenced, isolated, or has
   completed an explicit handoff, **and** its Dispatch (and Task, if the
   Task itself is being replaced rather than retried) has settled; and
2. the task worktree's Git state — branch, HEAD, commits, status, diff,
   untracked files — is captured in a handoff record under
   `.dev-work/runs/<run>/handoffs/`.

Admission terms: *stopped* is a positively proven exit; *fenced* is the
runtime's fenced consumer generation (`consumer_fenced` in
`references/failure-taxonomy.md`); *isolated* means the original writer is
provably unable to write the task branch even though its exit is
unobserved, for example its terminal or process has been taken over or cut
off from the worktree; an *explicit handoff* is the original writer's own
recorded handoff. A proven `stopped` attempt already carries the stop-side
evidence; a proven `failed` attempt does not, and that gap is the
intentional difference between this package-local gate and the runtime's
own proven-state guidance.

The replacement then takes over sequentially: it reads the original Task,
Role, Skills, project rules, prior reports and handoff, and the current Git
state before writing anything.

**Prohibited.** Never run a second concurrent writer on one task branch. Do
not derive a writer from `failed`, silence, or timeout alone. Do not skip
the handoff capture because the branch "looks clean". See
`references/worker-handoff.md` for the capture and takeover procedure.

### Task cancellation

A Task must be cancelled — obsolete, superseded, or user-directed.

**Principle.** Settle the worker first, then record the cancellation through
the runtime authority. A cancelled Task counts as failed for dependency
purposes: dependents stay blocked until a replacement completes the
underlying work or the graph is re-planned.

**Prohibited.** Do not treat a cancelled dependency as satisfied. Do not
cancel by deleting the worktree, closing the terminal, or dissolving the run
state.

### Unknown coordinator lock

Bootstrap encounters a coordinator lock it can prove neither live nor dead.

**Principle.** The lock is a local convention and `unknown` is a refusal
state. Take over only after the holder is confirmed gone, or through the
documented forced-takeover path that archives the prior lock.

**Prohibited.** Do not delete the lock file. Do not read lock absence as
holder death. Do not use global reset to dissolve one worktree's uncertainty.
See `references/coordinator-lock.md`.

## Runtime authority index

- Mutation receipts — each carries its own recovery / next-action guidance;
  follow it verbatim before applying any principle here.
- Current `--help` output of the orchestration CLI — the live verb and
  parameter surface.
- The installed global `orchestration` Skill — lifecycle contract, worker
  obligations, and its recovery-and-cleanup reference for post-failure,
  unknown-attempt, retention, and release decisions.
- `references/failure-taxonomy.md` — package-local failure classification and
  its evidence requirements.
- `references/worker-handoff.md` — the handoff capture and replacement
  procedure the writer gate above defers to.
- `references/coordinator-lock.md` — lock record, liveness states, and
  takeover rules.
