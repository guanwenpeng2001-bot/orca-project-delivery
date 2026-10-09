---
name: codebase-reconnaissance
description: Inspect a codebase, branch, history, configuration, and tests to answer scoped factual questions without modifying source. Use for dynamic reconnaissance before planning or review.
---

# Codebase Reconnaissance

## Core principle

Evidence first. Separate observed facts, inference, and unknowns.

## Workflow

1. Restate the exact information question and what decision it will support.
2. Identify the smallest repository regions, branches, history, tests, configuration, and runtime evidence that can answer it.
3. Trace relevant symbols, callers, data flow, state transitions, and side effects.
4. Record exact file paths, symbols, commits, commands, or outputs for every material conclusion.
5. Actively search for contradictory evidence and nearby alternate paths.
6. Summarize facts, implications, unknowns, and recommended next investigation—not a final implementation plan.

## Required output

- Question and scope
- Evidence table
- Observed behavior
- Implications
- Unknowns and confidence
- Suggested next step

## Rules

- Do not edit production source.
- Do not scan the whole repository without a scoped reason.
- Do not turn an inference into a fact.
- Do not propose broad refactors unless the Task explicitly asks for options.

## Completion

The worker must write the requested report, include concrete evidence, state unresolved uncertainty, and return the Task's required completion status. This Skill never authorizes broader scope, branch integration, or orchestration control.
