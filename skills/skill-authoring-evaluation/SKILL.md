---
name: skill-authoring-evaluation
description: Evaluate a method Skill for triggering, counterexamples, and observable task quality. Use when reviewing or authoring a SKILL.md before registration.
---

# Skill Authoring Evaluation

## Core principle

A method Skill is judged by the decision it changes, not by the headings it contains. Headings being present is necessary and never sufficient: the same eight headings can carry a method or carry filler.

## Decision criteria

Read the frontmatter first. `name` must equal the directory id, and `description` must say both what the method does and when to use it. A description that only names the topic gives a loader nothing to match against.

Score three layers separately. A high score on one does not repair a low score on another.

| Layer | Passes when | Fails when |
| --- | --- | --- |
| Triggering | The description distinguishes this method from the neighboring Skill a worker might load instead | The description fits several Skills equally, or omits the situation that should load it |
| Counterexamples | At least one concrete case names an input that looks related but must not load this Skill, and says which Skill owns it | Every example is a positive case, so over-triggering is invisible |
| Task outcome | The evaluation scenario names an observable result a reviewer can check without running an unrun experiment | The scenario says the result "should be good" or "should follow the method" |

The structural floor is the eight sections this package already uses, in order: Core principle, Decision criteria, Workflow, Worked example, Failure signals, Evaluation scenario, then Output and Boundary. Missing a section fails the floor. Having all of them decides nothing about quality.

Keep the worked example inside the Skill directory. It must show a realistic input, the decision, and the expected result. An example that restates the criteria in different words teaches nothing.

Registration stays with the package catalog, the source table, and `templates/skill-authoring.md`. This method reviews the Skill text. It does not edit the catalog, and it does not replace the package verifier.

### Comparison rubric

Score each layer 0, 1, or 2. Quote the line that earned the score. Do not infer quality from tone.

| Score | Triggering | Counterexamples | Task outcome |
| --- | --- | --- | --- |
| 0 | No use condition, or the condition also matches a neighbor | No negative case | No observable check |
| 1 | Use condition exists but overlaps a named neighbor without saying so | A negative case exists but names no owning Skill | A check exists but needs a human impression |
| 2 | Use condition names the neighbor it excludes | A negative case names the input and the Skill that owns it | A reviewer can mark the result pass or fail from the text alone |

A Skill is ready to propose for registration only at 2 on every layer plus a passing structural floor. Anything else is a revision, with the failing layer named. This rubric scores the text. It is not an agent experiment and must not be reported as one.

## Workflow

1. Check `name`, `description`, and the eight-section floor. Stop and report the floor failure before scoring prose.
2. List the neighboring Skills a worker could confuse with this one.
3. Score triggering: underline the phrase that includes the right work and the phrase that excludes the neighbor.
4. Score counterexamples: find the case that should not load this Skill and confirm it names the owner.
5. Score task outcome: confirm the evaluation scenario can be marked pass or fail from its own text.
6. Report the three scores, the quoted evidence, and the single change that would raise the lowest score.

## Worked example

Compare two descriptions for a Skill about database schema changes. The neighbor is `database-design`, which already owns schema, migrations, and rollback.

Weak description: "Helps with data and models."

| Layer | Score | Evidence |
| --- | --- | --- |
| Triggering | 0 | "data and models" also matches `database-design` and `domain-modeling` |
| Counterexamples | 0 | No case says when not to load it |
| Task outcome | 0 | No scenario |

Strong description: "Design data models, constraints, migrations, transactions, indexes, query patterns, retention, and rollback. Use for schema or persistence changes."

Its counterexample, written into the Skill, is: "Choosing entities and invariants before a store exists belongs to `domain-modeling`; this Skill starts once a store and a migration are in scope." Its evaluation scenario names a column split under continuous writes and fails the answer if the destructive step comes before the new path is verified.

| Layer | Score | Evidence |
| --- | --- | --- |
| Triggering | 2 | "schema or persistence changes" excludes modeling that has no store yet |
| Counterexamples | 2 | The negative case names `domain-modeling` as the owner |
| Task outcome | 2 | The destructive-step ordering is pass or fail without a judgment call |

The weak text can have every heading present and still scores 0. Headings did not change the scores.

## Failure signals

- The review praises "complete structure" and never quotes a decision the Skill changes.
- Triggering is scored from the title alone.
- The only examples are successful uses of the method.
- The evaluation scenario requires running an agent and judging the prose afterward.
- A score of 2 is given for a layer with no quoted line.
- The review edits the catalog or the source table while claiming to evaluate.

## Evaluation scenario

Given one Skill whose description is "Helps with data and models" and one whose description names schema and persistence changes, excludes `domain-modeling`, and states a pass-fail ordering check, the result should score the first 0 on all three layers and the second 2 on all three, with a quoted line for each score. It fails the method if both pass because both files contain the eight headings, or if the scores are reported as the outcome of an agent run.

## Output

- Structural floor result
- Neighbor Skills considered
- Three scores with quoted evidence
- The revision that raises the lowest score, or a registration proposal when every score is 2

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. It does not register a Skill, does not copy upstream Skill text, and does not treat an unrun agent comparison as evidence. Product direction, scope, and irreversible choices stay with the user.
