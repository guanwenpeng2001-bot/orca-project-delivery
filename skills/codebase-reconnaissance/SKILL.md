---
name: codebase-reconnaissance
description: Inspect a codebase, branch, history, configuration, and tests to answer scoped factual questions without modifying source. Use for dynamic reconnaissance before planning or review.
---

# Codebase Reconnaissance

## Core principle

Report what the code does and how you know, and keep observed fact, inference, and the unknown visibly separate. A reconnaissance report that states inferences as facts sends later work in a direction nobody checked.

## Decision criteria

Scope to the smallest region that can answer the question. Name the question and the decision it informs first, then identify the modules, history, and tests that bear on it. Reading the whole repository feels thorough but buries the answer and burns time; widen only when the narrow search leaves the question unresolved.

Label every material statement. A fact was directly observed and cites where: a file and line, a command and its output, a commit. An inference is a conclusion drawn from facts and is marked as such, with the facts it rests on. An unknown is something the question needs that was not established. Conflating these is the central failure of this kind of work.

Cite precisely enough to be rechecked. "The handler validates input" is not a finding; the finding is the file, the function, and the lines where validation happens, plus what it does and does not check. A reader should be able to confirm each fact without redoing the whole investigation.

Look for contradictions deliberately. Search for other callers, other implementations, and tests that assert the opposite of what you found. A single confirming path is not the whole story, and the contradictory one is usually the one that matters.

State confidence where it is not certain. Where evidence is partial — one example, an unclear history — say so and say what additional evidence would settle it.

Do not propose the solution. End with the facts, their implications, and the specific next question worth answering. Designing the change is a different task.

### Where to look, in order

Start with the entry point that serves the question: the route, handler, command, or job. Follow the calls it makes rather than searching for keywords across the repository, because a keyword hit does not tell you whether the code runs on this path. Use the history where the question is about why something is the way it is: the commit that introduced it and its message often state an intent the code no longer makes obvious. Use the tests as evidence of intended behavior, and note where tests are absent, since untested behavior is exactly where intent is least reliable.

Configuration and feature flags change behavior without changing code. If the question concerns what the system does in a given environment, check the configuration that environment runs with, not just the source.

### Strength of evidence

Rank what you found. A branch you read and traced is stronger than a name you inferred a purpose from. A test that asserts a behavior is evidence of intent; it is not evidence the behavior occurs in production, where configuration may differ. A comment is a claim, not a fact, and comments drift from the code — verify against the code. When you report an inference, name the facts it rests on so a reader can judge it. When something material is uncertain, say what you would need to check to settle it, which turns an unknown into a next step.

### Writing the answer so it can be checked

Open with the direct answer, then the support for it. Attach each material claim to the file and line, or the command and output, that it comes from, and mark it as observed or inferred. Put the unknowns in their own list with the specific check that would settle each one, so the reader sees both the established ground and its edge.

Stay inside the question. Adjacent discoveries that do not affect the decision being made belong in a brief note, not in the conclusion, where they would blur the answer and invite an unrequested recommendation.

## Workflow

1. Restate the question and the decision it will feed.
2. Identify the smallest set of modules, history, configuration, and tests that could answer it.
3. Trace the relevant symbols, their callers, the data flow, and the side effects.
4. Record each material fact with its exact location or command output.
5. Search for contradictory evidence and alternate paths.
6. Separate findings into facts, inferences, and unknowns, and name the next question.

## Worked example

Question: can the export endpoint return another user's data? Decision it feeds: whether a security fix is needed before launch.

Facts:

- `export/handler.py:42` loads records with `user_id` taken from the request body, not from the authenticated session.
- The route requires authentication (`routes.py:17`), so an anonymous caller is rejected.
- `export/handler_test.py:88` asserts only that an authenticated user receives a file, using a fixture with one user, so it cannot catch a cross-user read.

Inference, marked as such: because the filter value comes from the request, an authenticated caller who supplies another user's id would receive that user's records. This rests on the two facts above and was not executed.

Contradiction search: a second query path in `export/legacy.py` filters on the session user instead. It is reachable only from a deprecated route, so the exposure is on the current route specifically.

Unknown: whether any middleware rewrites the request body before the handler. Not established; would be settled by tracing the middleware chain.

Recommended next step: one focused test that authenticates as user A and requests user B's id, to confirm the inference before any fix is scoped.

## Failure signals

- Conclusions are stated with no file, line, or command behind them.
- Inferences are written in the same voice as observed facts.
- The investigation ranges over the whole repository regardless of the question.
- A single supporting path is reported without looking for a contradicting one.
- Unknowns are omitted instead of listed.
- The report ends with a proposed implementation rather than findings.

## Evaluation scenario

Given a question about whether a background job retries failed work, the result should cite the exact locations that determine retry behavior, label as inference anything concluded rather than read, report a contradiction search such as a second code path or a test asserting otherwise, and list what remains unknown. It fails the method if the answer is a bare yes or no with no locations, or if the report recommends a redesign rather than reporting evidence.

## Output

- Question, the decision it informs, and scope
- Evidence with exact locations or command output
- Facts, inferences, and unknowns, separated
- Contradictions found
- Confidence and what would raise it
- Recommended next question

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
