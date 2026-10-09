---
name: technical-research
description: Research current technical behavior using primary sources, source code, standards, and reproducible experiments. Use when library, CLI, protocol, platform, or vendor behavior can affect a decision.
---

# Technical Research

## Core principle

Prefer current primary evidence over memory and secondary summaries.

## Workflow

1. Define the decision, environment, version range, and required certainty.
2. Search official documentation, specifications, release notes, and upstream source first.
3. Record source date, version, platform, and any account- or feature-gated behavior.
4. Run a minimal reproducible experiment when documentation is ambiguous and the environment permits it.
5. Compare viable options on capability, limitations, migration cost, operational burden, reversibility, and risk.
6. State what is verified, inferred, disputed, or unavailable.

## Required output

- Research question
- Environment and versions
- Primary evidence
- Option comparison
- Recommendation
- Uncertainty and follow-up

## Rules

- Do not silently use stale model memory.
- Do not cite a source for claims it does not support.
- Do not invent a CLI flag, model id, or platform capability.
- Distinguish product documentation from observed local behavior.

## Completion

The worker must write the requested report, include concrete evidence, state unresolved uncertainty, and return the Task's required completion status. This Skill never authorizes broader scope, branch integration, or orchestration control.
