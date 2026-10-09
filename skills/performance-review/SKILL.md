---
name: performance-review
description: Measure and analyze latency, throughput, complexity, queries, memory, concurrency, caching, and capacity. Use for performance-sensitive code or claimed optimizations.
---

# Performance Review

## Core principle

Performance claims are measurements, not impressions. A change is an optimization only if it improves a defined metric on a representative workload by more than the noise in the measurement.

## Decision criteria

Define the objective before measuring. Name the metric, the workload, and the threshold that would count as success or as a regression. Common shapes are a latency percentile, a throughput rate, or a resource ceiling. State which percentile matters: the median describes the typical case, the tail (p95, p99) describes the experience of the worst-served requests, and optimizing one can hurt the other.

Measure against the real shape of work. A benchmark that runs a function in a tight loop over uniform data does not represent a system whose cost is dominated by a handful of large records or by network round trips. Include the data volume, the concurrency, and the cache state that production has.

Separate one-time cost from steady cost. The first iteration after startup pays initialization and cold caches; either exclude a warm-up period explicitly or report cold and warm numbers separately. Never compare a cold baseline against a warm candidate.

Account for variance. Run enough repetitions to see the spread, and report it. A single before-and-after pair cannot support a percentage claim, because the next run may move by as much as the claimed gain.

Look for the cause in this order, because the earlier ones dwarf the later ones: an algorithm that scales worse than linearly with input size; repeated work per item such as a query issued inside a loop; waiting on a remote call that could be batched; contention on a shared lock; and only then micro-level allocation or copying.

Guard the result. Any optimization worth making is worth a test or an alert that fails if the metric regresses, since nothing else stops a later change from quietly undoing it.

### Comparing fairly

Hold everything constant between baseline and candidate except the change under test: same hardware, same data volume, same concurrency, same warm-up handling. Measure the candidate the same way you measured the baseline, in the same session where practical, because environmental drift between sessions can exceed the effect you are measuring. Report absolute numbers alongside any percentage, since a large percentage of a tiny baseline is a different result from a large percentage of a costly one.

### Reading a profile

A profile tells you where time or memory goes; use it before forming an opinion. Distinguish CPU time from waiting time. Time spent blocked on a query, a remote call, or a lock is not helped by tightening the code around it — the fix is fewer calls, batched calls, or less contention. Time spent in computation is helped by algorithmic change first and micro-optimization only once the algorithm is sound.

Watch for work that scales with input size when it need not. A query per item, a repeated scan of a growing collection, or a serialization of the whole object to read one field each become the dominant cost exactly when the data gets large, which is when it matters. Confirm with input sizes that match production, because these costs are invisible on small fixtures.

### Caching

Cache only when the measurement shows repeated identical work, and state the invalidation rule at the same time as the cache. A cache without a defined way to become stale returns wrong results, which is a correctness bug wearing a performance hat. Bound the cache size. Account for cache warming in the numbers: the steady-state gain and the cold-start cost are different claims and both belong in the report.

### Capacity, not just speed

Ask what the change does to resource consumption, not only to latency. A change that lowers latency by holding a large dataset in memory, or by opening one connection per request, trades one limit for another. Report the memory, connection, and concurrency consequences alongside the speed.

### Deciding where to stop

Optimize the cost the profile shows dominates, and stop once the metric is within its target. Speeding up a stage that is already cheap adds complexity for a gain nobody can perceive. Given several ways to improve the dominant cost, prefer the one that removes work — fewer queries, less data transferred, an algorithm that scales better — over one that does the same work slightly faster.

Name the trade-off you accept. Caching spends memory and risks staleness; a denormalized value spends write complexity to buy read speed; batching spends per-item latency to buy throughput. Stating it makes the cost a decision instead of a surprise found later.

## Workflow

1. Write down the metric, the workload, the environment, and the threshold.
2. Measure the current behavior under that workload and keep the raw numbers.
3. Profile to find where the time or memory actually goes, rather than assuming.
4. Change one thing.
5. Re-measure the same way, including repetitions and spread.
6. Check that correctness and other metrics did not regress.
7. Add a guard for the metric and report the numbers with their variance.

## Worked example

A list endpoint averages 300 ms and the suspicion is the rendering layer.

The measurement plan: p50 and p95 latency, against a database loaded with the production distribution, 50 concurrent clients, ten repetitions after a warm-up run.

Profiling shows each request issues one query for the parent rows and then one query per row for the child records — the cost grows linearly with page size, and at the typical page it accounts for most of the 300 ms. Rendering is a small fraction. The hypothesis was wrong, and optimizing rendering would have been wasted.

The change fetches the child records in one batched query. Re-measuring the same workload gives p50 of 140 ms against a baseline p50 of 290 ms, and p95 of 210 ms against 420 ms, with run-to-run spread under 15 ms. The gain is several times the noise, so it is real. A test asserts the endpoint issues a constant number of queries regardless of page size, which guards the regression without depending on wall-clock timing.

## Failure signals

- A percentage improvement is quoted from a single run with no repetition or spread.
- The benchmark workload does not resemble production data volume, concurrency, or cache state.
- Effort goes into code that profiling shows is a negligible share of the total.
- A cold run is compared with a warm one.
- The optimization is accepted with no guard, so a future change can silently revert it.
- Latency is reported only as an average, hiding a worse tail.

## Evaluation scenario

Given a claim that a refactor made a request "about twice as fast," the review should require the metric and percentile, the workload description, repeated measurements with their spread for both versions, and a statement of whether the difference exceeds that spread. It fails the method if a single pair of timings is accepted as proof, or if the benchmark exercises uniform tiny inputs when production data is large and skewed.

## Output

- Objective, metric, and workload
- Baseline numbers with variance
- Bottleneck analysis and evidence
- Change and resulting numbers
- Correctness and trade-offs
- Regression guard

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
