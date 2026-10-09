# FAQ and troubleshooting

**English** | [简体中文](zh-CN/faq.md)

## General

**What exactly does this package give me?**
A coordinator Skill (`SKILL.md`) plus the routing tables, role contracts,
schemas, templates, and PowerShell scripts needed to run software delivery
with Claude Code workers: intake, dynamic reconnaissance, planning, a task
graph, isolated implementation, independent review, evidence-gated
integration into one delivery branch, and final verification.

**Do I need Orca and Claude Code, or just Claude Code?**
Both. Workers are Claude Code agents, and the Orca Runtime owns the
Run/Task/Dispatch/Worker lifecycle. This package supplies the delivery
workflow on top; it is not a standalone orchestrator.

**Can a worker load this Skill?**
No. It is coordinator-only. A worker carrying a dispatch preamble executes
its assigned Task, Role, Skills, and contracts — unless its Task explicitly
authorizes nested coordination.

**Does it run on Linux or macOS?**
It has only been exercised on Windows with PowerShell 7+. The scripts are
PowerShell, and nothing on other platforms is tested or supported.

**How do I update the package?**
Pull the latest revision and re-run `scripts/verify-package.ps1` — see
[installation.md](installation.md#upgrade). Per-project `.dev-work/` state is
schema-validated, and old runs stay readable.

## Professional capabilities

**Does 2.4.0 generate images, video, speech, or documents?**
It ships local PNG, subtitle, manifest, Markdown, and Office/PDF tools as well
as methods and gated provider connectors. Bounded local Chromium and FFmpeg
checks ran on Windows. No real provider call, HyperFrames render, or Office
visual review is claimed. See the [capability guide](professional-capabilities.md)
for the evidence and limits; loading a Skill alone runs nothing.

**Are OpenAI, Pexo, and ElevenLabs the chosen providers?**
No. They are example connectors, named so the configuration shape is concrete.
Selecting a provider, a budget, and an upload scope is a per-task user
decision. Installing the package does not authorize a call.

**Why does the package claim 46 Skills when my catalog shows 16?**
A complete 2.4.0 install contains 46 Skills and 16 Roles. A catalog showing
16 Skills belongs to a version that does not match this release, even if newer
documentation is present. Install the complete matching release; the
[tutorial](professional-capability-tutorial.md) checks the version, catalog
counts, and manifest before running new commands.

**Can I copy the Anthropic document Skills or OpenMontage in?**
No. The docx, pptx, pdf, and xlsx Skills are proprietary and are not included.
OpenMontage is AGPL-3.0 and is not included. `document-production` and
`media-transcoding` are written independently. See the
[license section](professional-capabilities.md#licenses-and-sources).

## Extensions and configuration

**Can I add a Skill or Role, or edit a bundled method?**
Yes. Use native catalogs, matching files, current hashes and manifest counts; a new Role also needs a model route. The original sixteen are maintained MIT adaptations; the later thirty are original methods with public references. Follow [Extending](extending.md) and run both metadata and full verification.

**Why does a configured API still show unavailable, or fail later?**
`configured` only describes file presence. An empty process value overrides a nonempty file value and blocks the child. API checks never authenticate or access the network; a passing presence check says nothing about a real service's response.

**Does the helper load all my `.env` into every worker?**
No. It reads the explicit execution-host root, adds only selected declared file variables to an authorized child, and preserves the parent. Existing process variables remain inherited, even undeclared ones. No coordinator `.env` copy or generic `.dev-work` override loader exists. JSON config is opt-in and non-secret only. Child programs can print values; their output is not redacted.

**Can the executable live outside ProjectRoot?**
Yes, when authorized by the user/Task. The confinement rule applies to config paths. Prefer a real executable/interpreter plus a PowerShell argument array; Windows batch launchers are not guaranteed by direct process execution.

## Operating a run

**A `worker-start` receipt says `outcome_unknown` / `turn_start_unobserved`.
Did the dispatch fail?**
This is *unobserved*, not proof of failure or successful submission. Inspect
the receipt, authoritative worker projection, and bounded terminal output
first. Only when the task was accepted but remains unsubmitted in the
composer should you submit it in the **same** terminal (a bare Enter), using
the installed runtime guidance. Never re-dispatch, stop, or abandon merely
because the turn start was unobserved.

**The worker is silent, a wait came back empty, or liveness is
`unverifiable`. Is the worker dead?**
No. Absence is a checkpoint, not a verdict. Silence, timeouts, and
unverifiable observations prove neither failure, quota exhaustion, nor
process exit. Keep waiting or inspect within a bounded window; only an
observed exit, an authoritative settlement, or equivalent positive evidence
ends the wait. No stop, abandon, retry, release, or model downgrade follows
from absence alone.

**`worker-list` shows a terminal as `retained` or `user_owned` after
release. Is that a leak?**
No. Worker release is post-settlement cleanup, not cancellation. On hosts
whose new-tab mode is a terminal, the runtime can legitimately answer
`retained` / `user_takeover` / `user_owned` and keep the terminal alive. The
completion accounting still holds when the reclaimable list is empty. Decide
explicitly between reuse, retain, and close — and close a terminal explicitly
when you remove its worktree, or you leave a dead pane behind.

**A historical run fails `-Phase final` now, but it passed when it was
recorded. Why?**
The live phases assert moment equations — the delivery HEAD equals the
recorded target, the trees are clean — that hold only at validation time.
Once the delivery branch advances, the old run-final target no longer equals
its current HEAD, so run-scoped `final` legitimately FAILs without implying
the original integration was wrong. Use `-Phase audit` for historical
evidence. Current acceptance requires fresh verification and the canonical
run-final record at the current target. A Task selected alone with `final`
uses historical Task checks and cannot establish run completion; branch
advancement alone does not invalidate that Task's historical evidence.

**A review returned `UNVERIFIABLE`. Is that a failed review?**
It is neither approval nor failure — it is an explicit statement that the
reviewer could not verify something. Keep the evidence unclear-marked;
re-run, gather the missing evidence, or mark the acceptance unverifiable.
Never describe unverifiable acceptance as READY.

**The first `worker-start` receipt's effective model differs from what I
requested. Do I downgrade?**
Not automatically. Record `mismatch`, do not infer quota or model
unavailability, and apply the model-tier rule from
`routing/model-routing.json` — or, if the user pinned the choice, suspend the
Task and ask. Requested values are never treated as effective.

**A worker reports it cannot read its Skill path.**
That is a `skill_unavailable` condition: repair the path, or switch to a
recorded `inline-extract` (include the required sections and record the
source path and hash). A Skill name alone is not loading evidence.

**Two coordinators might be running in the same worktree. What do I do?**
Read `.dev-work/coordinator-lock.json` and probe the recorded handle. `live`
means refuse; `dead` means archive and take over; `unknown` means refuse —
absence is not proof the holder is gone. Never delete the lock file and
never use a global orchestration reset to dissolve one worktree's
uncertainty.

**The delivery merge conflicts. Can I resolve it myself in the delivery
worktree?**
No. Abort the merge, create an isolated resolution Task (merge-resolver
role), review its result independently, update the review/admission to that
result, and retry the gate. Unreviewed changes are never repaired directly
in the delivery branch.

**`verify-package.ps1` prints FAIL lines on my fresh clone.**
Read the first FAIL line: a missing bundled Skill points at
`metadata/skill-paths` or `metadata/bundled-skill-integrity`; encoding failures identify invalid UTF-8, a BOM, or CR
bytes; content failures identify a disallowed reference. A FAIL can reflect
a missing dependency, environment problem, or package defect, and does not
by itself prove the checkout was modified — see
[installation.md](installation.md#troubleshooting-installation-failures).
