---
name: performance-review
description: Measure and analyze latency, throughput, complexity, queries, memory, concurrency, caching, and capacity. Use for performance-sensitive code or claimed optimizations.
---

# Performance Review

## Core principle

Measure before and after; explain the workload and environment.

## Workflow

1. Define the performance objective, workload, environment, and guardrails.
2. Establish a repeatable baseline.
3. Inspect algorithmic complexity, data access, allocations, network calls, contention, and blocking.
4. Design a representative benchmark or trace.
5. Measure the change and account for variance and warm-up.
6. Check correctness and resource trade-offs.
7. Recommend changes only where evidence justifies complexity.

## Required output

- Objective and workload
- Baseline
- Bottleneck analysis
- Measurements
- Trade-offs
- Recommendation

## Rules

- Do not benchmark unrealistic toy input as the only evidence.
- Do not optimize a non-bottleneck.
- Do not trade correctness for speed without an explicit decision.
- Do not claim percent improvement without reproducible numbers.

## Completion

The worker must write the requested report, include concrete evidence, state unresolved uncertainty, and return the Task's required completion status. This Skill never authorizes broader scope, branch integration, or orchestration control.
