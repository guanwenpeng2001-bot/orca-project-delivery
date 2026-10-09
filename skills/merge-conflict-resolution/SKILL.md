---
name: merge-conflict-resolution
description: Resolve Git merge conflicts using branch intent, common base, commit history, interfaces, and tests. Use when integrating reviewed work into the delivery branch.
---

# Merge Conflict Resolution

## Core principle

A conflict marker means two changes overlapped, not that one of them is wrong. Resolve by understanding what each side was trying to accomplish and preserving both intents; taking one side wholesale silently discards work that was already reviewed.

## Decision criteria

Find the common ancestor and read both changes against it before touching anything. The ancestor shows you what each side actually added or removed, which the two end states alone cannot.

Classify each conflict, because the class determines the resolution:

| Class | What happened | Resolution |
| --- | --- | --- |
| Adjacent additions | Both sides added different things in the same region | Keep both |
| Same-concept edit | Both sides changed one behavior | Combine so both intents survive; where they contradict, escalate |
| Rename or move | One side moved or renamed what the other edited | Apply the edit at the new location |
| Generated artifact | The conflict is in generated or lock-type output | Regenerate from the merged sources rather than hand-merging |
| Genuine disagreement | The two sides encode contradictory decisions | Stop and escalate; this is not resolvable from the code |

Never resolve a disagreement about product behavior, requirements, or architecture by picking a side. Those are decisions for the people who own them. Escalate with both intents stated and a recommendation if you have one.

Prove the merge. A merge that compiles can still drop a behavior. Run the tests for both sides' changes and confirm each side's intended behavior is present in the result, not just that the conflict markers are gone.

Use the history. The commit messages, the associated review, and the task that produced each side explain intent that the code alone may not.

### Reading a conflict properly

A conflict marker shows the two end states, which is not enough. Diff each side against the common ancestor so you can see what each side added, removed, and moved. Two sides that both rewrote a block may have changed different things within it, and the marker will not tell you that; the ancestor will. Tools that show the base alongside both sides make this direct.

Follow a rename through. When one side moves or renames a symbol the other side edited, the edit has to land on the symbol's new name and at every caller. The conflict tooling handles the moved file; it does not update the callers. Grep for the old name after resolving.

Treat generated output differently from source. Lock files, generated clients, and compiled assets should be regenerated from the merged inputs rather than merged by hand, because a hand-merged generated file can be internally inconsistent in ways no review will catch. Confirm which files are generated before spending time on their conflicts.

### After the markers are gone

Clearing the markers is the start of verification, not the end. Build, run both sides' tests, and specifically check that each side's intended behavior still exists in the merged result. A behavior that one side added and the resolution accidentally dropped will not announce itself; you have to look for it. Record the resolution — what was kept, what was combined, what was escalated — so the reviewer of the merge can see the reasoning rather than re-deriving it.

### Keeping both intents, and checking the aftermath

For an edit where both sides changed the same behavior, recover each side's purpose from its commits and review, then write a merged result that satisfies both. When both cannot be satisfied because they assume contradictory states, stop: that is a genuine disagreement and belongs to whoever owns the decision, with both intents described so they can choose. Do not invent a middle ground neither side asked for.

After resolving, check the callers and the tests of the merged code, not only the lines that conflicted. The conflicted file can be internally consistent while a caller still uses the old shape or a test still asserts the behavior from before the merge.

## Workflow

1. Identify the common ancestor and both sides' changes.
2. Read the commits, the associated tasks, and any interface agreements to learn each side's intent.
3. Classify every conflict using the table above.
4. Resolve the mechanical classes, preserving both intents.
5. Escalate the genuine disagreements instead of choosing.
6. Run both sides' tests and confirm the merged behavior, then record what was done.

## Worked example

A delivery branch adds a `discount` field to an order response while a feature branch renames `total` to `grand_total` in the same struct.

Against the ancestor: one side added a field, the other renamed one. These are different concepts that happen to touch the same lines, so both intents survive — the merged struct carries `grand_total` and `discount`. Taking either side whole would lose a reviewed change.

A second hunk changes the same validation rule in contradictory ways: one side rejects zero quantities, the other explicitly permits them for free samples. That is a genuine disagreement about domain behavior. It is escalated with both intents described, not resolved by preference.

After resolving the first hunk, the order tests from both branches are run. The delivery branch's test for the discount field fails because it still references `total`, which confirms the rename must be followed through to callers — a real consequence the merge would otherwise have missed.

## Failure signals

- One side is taken for the whole file to "get it done."
- Conflict markers are cleared but neither side's tests are run afterward.
- A generated file is hand-edited to look plausible.
- A contradiction in business behavior is settled by the person doing the merge.
- Changes are discarded because their purpose was not obvious at a glance.
- The resolution is not described anywhere, so reviewers cannot see what was decided.

## Evaluation scenario

Given a merge where one branch adds validation and another refactors the same function, the result should classify each hunk, keep both the validation and the refactor where they are compatible, escalate any hunk where the two branches want contradictory behavior, and show tests from both branches passing on the result. It fails the method if an entire side is chosen without per-hunk analysis, or if the merge is declared done with conflict markers gone but no test evidence.

## Output

- Conflict inventory with classification per hunk
- Intent of each side
- Resolution per hunk
- Items escalated and to whom
- Test evidence for the merged result
- Residual risk

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
