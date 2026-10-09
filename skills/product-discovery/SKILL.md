---
name: product-discovery
description: Turn a vague product request into a validated problem, users, outcomes, scope, non-goals, assumptions, and acceptance direction. Use before requirements when product intent is unclear.
---

# Product Discovery

## Core principle

Separate the problem from the proposed solution, and separate what is known from what is assumed. Most vague requests arrive as a solution; the work is to recover the underlying problem before committing to build anything.

## Decision criteria

Sort every statement into one of three buckets. Evidence is something observed: a quoted user complaint, a measured drop-off, a support volume. An assumption is something believed but not yet supported. A solution idea is a proposed feature. Evidence can justify a decision; assumptions must be tested or explicitly accepted; solution ideas are not requirements and should not be written as if they were.

For each assumption, write what would convince you it is wrong. An assumption with no imaginable counterevidence cannot be tested and should be flagged as a belief the user must choose to adopt, not a fact.

Define scope by the smallest version that produces learning. Compare approaches by what each would prove and what it costs, not by which is most impressive. Prefer the one that settles the riskiest assumption soonest.

Pair every success signal with a guardrail. A success signal says the change worked; a guardrail says what must not get worse while it does. A change that lifts the target metric by harming retention has not succeeded, so name both.

Write non-goals explicitly. Anything obvious that the work might be expected to include, but will not, belongs on the list so it does not creep back in.

Direction choices — who the user is, what outcome matters, what is out of scope — belong to the user. Present them as decisions with options and a recommendation, not as settled conclusions.

### Writing it so the user can correct it

Write the problem statement, the assumptions, and the proposed scope in plain language and hand them back before designing anything. The point of discovery is to be corrected cheaply. Phrase assumptions as statements the user can disagree with, not as background woven into the prose where a disagreement would go unnoticed. End with the specific decisions needed, each with its options and a recommendation, so the user is choosing rather than being asked to invent the options.

### Whose problem, and how much evidence is enough

Name the specific user and situation, not "users" in general. A request that serves several audiences with different needs is several problems; pick the one this work addresses and record the others as out of scope. The current workaround matters: what people do today tells you how severe the problem is and what a replacement must beat. A problem nobody currently works around is often a problem nobody feels.

Be honest about evidence strength. A handful of support tickets justifies investigating, not building a large feature. A single loud request is an anecdote. State what you have and what confidence it supports, and choose the size of the bet accordingly: thin evidence justifies a small, fast test, not a large commitment. Inventing numbers or quoting users who were never spoken to is worse than admitting the evidence is thin.

### Framing the bet

State the scope as the smallest behavior that tests the riskiest assumption, and state the non-goals as the things a reasonable person would expect you to include but that you will not. Written non-goals are what keep the work from expanding and what make the boundary reviewable later.

Match the test to the kind of risk. Where the risk is that nobody wants it, the smallest test is often a manual or partial version rather than the engineered one. Where the risk is that it works at the real scale, a small test proves nothing and the constraint itself has to be tested. Say what the chosen approach will and will not prove, so a result is read correctly.

Then name the bet: the belief it rests on, the investment it takes, and the result that would make you stop or change direction. A small bet on thin evidence is appropriate; a large commitment on thin evidence is the outcome this method is meant to prevent. End by listing the decisions only the user can make, since discovery that settles a direction question on its own has gone past its role.

## Workflow

1. Restate the request as a problem: who is affected, what they do today, and what is costly about it.
2. Sort the supporting statements into evidence, assumptions, and solution ideas.
3. For each assumption, write the observation that would falsify it.
4. Define the smallest scope that tests the riskiest assumption, and list non-goals.
5. Name the success signal and the guardrail metric.
6. Hand the genuine direction choices to the user with options and a recommendation.

## Worked example

The request: "Add an AI chatbot to the settings page."

Restated as a problem, the evidence on hand is that support tickets about configuring notifications are the largest single category, and the settings page has a high exit rate. The chatbot is a solution idea, not a requirement.

Assumptions: users cannot find the notification settings (falsified if session recordings show they find the control but do not understand its effect); users would rather ask than read (falsified if a plain inline explanation reduces the tickets without any chatbot).

The smallest approach that tests the risky assumption is an inline explanation next to the notification control, measurable within a week. The chatbot would take far longer and would test several assumptions at once, so a result would not say which mattered.

Success signal: fewer notification-related tickets. Guardrail: no drop in users completing notification setup. Non-goal: general-purpose assistance across the rest of the product.

The decision for the user is whether the outcome is fewer tickets or a chatbot specifically, because those lead to different work.

## Failure signals

- The problem statement is just the requested feature reworded.
- Numbers or user quotes appear that nobody actually measured or recorded.
- Assumptions are listed with no way they could be disproved.
- Scope grows to cover neighboring ideas that do not serve the outcome.
- A success metric is named with no guardrail against collateral damage.
- A direction choice is made silently instead of being handed to the user.

## Evaluation scenario

Given "users want a dashboard," the result should restate a specific problem grounded in cited evidence, list the assumptions with what would falsify each, propose the smallest version and what it proves, name a success signal and a guardrail, and identify which choices are the user's. It fails the method if it proceeds straight to laying out dashboard widgets, or if it presents assumed user behavior as established fact.

## Output

- Problem statement
- Users and their current workaround
- Evidence, assumptions, and solution ideas, separated
- Falsification for each assumption
- Smallest scope and non-goals
- Success signal and guardrail
- Open decisions for the user

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
