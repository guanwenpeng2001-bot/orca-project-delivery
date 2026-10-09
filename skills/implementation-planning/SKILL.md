---
name: implementation-planning
description: Turn an approved requirement and design into small, self-contained, dependency-aware Tasks with exact scope, acceptance, tests, roles, skills, branches, and reports.
---

# Implementation Planning

## Core principle

A Task should be independently executable by a capable worker without guessing.

## Workflow

1. Read the authoritative objective, requirements, design, project rules, and current branch state.
2. Split work along coherent ownership and verification boundaries.
3. Assign one Primary Role and a minimal Skill set per Task.
4. Specify exact allowed and forbidden scope, inputs, outputs, acceptance, and tests.
5. Encode only real dependencies and identify safe parallel waves.
6. Define branch base, report path, review target, merge target, and final-verification relationship.
7. Preflight the graph for shared-file conflicts, missing interfaces, cycles, and untestable completion.

## Required output

- Task DAG
- Task briefs
- Role/Skill assignments
- Branch plan
- Acceptance/test plan
- Risk and decision gates

## Rules

- Do not use vague Tasks such as investigate or improve without a concrete output.
- Do not assign multiple writers to the same branch.
- Do not hide product decisions inside engineering Tasks.
- Do not create deep chains when integration into the delivery branch can simplify the graph.

## Completion

The worker must write the requested report, include concrete evidence, state unresolved uncertainty, and return the Task's required completion status. This Skill never authorizes broader scope, branch integration, or orchestration control.
