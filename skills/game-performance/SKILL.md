---
name: game-performance
description: Identify the limiting game workload and measure one targeted improvement at a time against frame and memory budgets. Use when a game drops frames, hitches, exceeds device budgets, or needs a defensible optimization decision.
---

# Game Performance

## 1. When to use / When not to use

Use for slow frames, uneven pacing, load spikes, memory pressure, or a specified performance target that needs measurement.

Do not optimize from intuition alone. Without access to a representative workload, prepare a measurement plan and state the gap. Physics correctness belongs with game-physics; engine profiler controls and deployment instructions belong to project-side guidance. A prototype without a performance requirement does not justify a speculative optimization framework.

## 2. Novice orientation

A frame is one displayed image. Frame time measures how long producing frames takes; an average frame rate can hide occasional stalls. The CPU performs game logic and submits rendering work; the GPU renders images. They overlap, so adding their reported times is not generally the displayed frame duration.

For a first session, select one repeatable scene and camera path. Record the target device, build, resolution, quality settings, and desired frame rate. Through the project's profiling instructions, capture that path after loading has settled, recording frame times and CPU/GPU timings. Repeat without changing anything to see normal variation. Choose a candidate change only after the limiting workload is identified.

First-session checklist:

- Record the exact workload and capture duration, including warm-up policy.
- Convert the target to milliseconds per frame: `budget_ms = 1000 / target_fps`.
- Identify the slowest relevant path and whether its time is work or waiting.
- Keep a baseline capture for comparison with the same settings.

Terms: a **profiler** attributes time or memory to work; a **bottleneck** limits throughput or causes a particular stall; a **percentile** describes a tail of the measured frame distribution; **allocation** reserves memory; **GC** is automatic reclamation of managed memory; a **budget** is a project-agreed upper bound.

## 3. Core method

### Decide CPU versus GPU before choosing an optimization

Reproduce the issue in a representative optimized build on target hardware. Capture total frame pacing, CPU work and waits, GPU work, allocation activity, and loading events around the problem. Identify whether the limiting path is CPU computation/submission, GPU rendering, synchronization, storage, or deliberate frame pacing. A long CPU wait for the GPU is not expensive gameplay logic; draw-call overhead may constrain CPU submission rather than GPU execution.

Use controlled probes where timings are ambiguous: a resolution reduction can support a pixel-work hypothesis, but unchanged timings may also reflect a frame cap. Remove that ambiguity in the measurement setup before drawing a conclusion. If GPU timing is unavailable, label the classification provisional and state what capture would settle it.

### Fix one measured cause at a time

Choose one bottleneck in the measured slow path, make one causally related change, then repeat the same capture. Do not combine unrelated optimizations: their individual effect and regressions become impossible to attribute. Prefer eliminating unnecessary work over making the same work slightly cheaper.

Only after classification, consider the matching intervention:

| Observed cost | Candidate intervention | Regression to check |
| --- | --- | --- |
| Repeated CPU searches or decisions | Reduce scope, cache valid results, or update less often | Stale state and response delay |
| Spawn/despawn or allocation spikes | Reuse buffers or bounded object pools | Retained memory, pool exhaustion, stale object state |
| CPU rendering submission | Compatible batching or instancing | Culling granularity and visual correctness |
| GPU pixel work or bandwidth | Reduce overdraw, shader work, or excessive resolution | Readability and image quality |
| Load/decompression or residency pressure | Adjust streaming and asset budgets | Missing content, loading stalls, memory peaks |

Pooling has a memory cost; batching has compatibility and culling constraints. Neither is a default fix. Allocation counts alone do not establish that GC caused the observed spike: correlate them with reclamation and frame timings.

### Measure the same question again

Record before/after frame-time distribution, the relevant tail percentile, slow-frame count, limiting subsystem time, and peak memory as applicable. State duration, sample count, device thermal/power conditions, and whether loading was included. Repeat enough times to distinguish a useful improvement from observed run-to-run variation; do not choose an arbitrary universal threshold.

Keep a change only when it improves the target without violating gameplay, visual, latency, or memory constraints. If another bottleneck becomes dominant, establish a new baseline before addressing it. Translate the measured envelope into subsystem and asset budgets appropriate to the lowest supported device. Derived example: a chosen 60-frame-per-second target permits approximately 16.67 milliseconds per frame; it is not a universal target or an additive CPU-plus-GPU allowance.

## 4. Failure criteria and measurable invariants

- The selected frame-time percentile and allowed slow-frame count satisfy the declared budget for the recorded workload and duration.
- A claimed improvement exceeds the measured baseline variation under equivalent conditions, and the expected bottleneck metric changes in the predicted direction.
- Peak resident memory remains below the project limit; a bounded pool cannot silently grow without limit.
- The changed workload preserves its declared gameplay and visual acceptance cases.

Without a baseline, device/build identity, repeatable workload, and before/after capture, report **not assessed** rather than faster or optimized. An editor-only measurement supports an editor observation, not a device-release claim. Lower draw-call counts or fewer allocations without improved user-relevant timing are intermediate observations, not proof of success.

## 5. Platform/engine boundary

The project's AGENTS.md, externalSkills, and roleBindings own profiler setup, release-build creation, device attachment, engine rendering settings, and capture tooling. The product owner sets acceptable quality and device targets; implementation and test owners measure the tradeoff. Consult version-matched engine/platform guidance for operations; this method supplies experiment design and interpretation only.

## 6. Sources and verification status

Consulted on 2026-10-23: [Performance optimization](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/38a4c2500eeb5ff9ac084336b8f66108069d2f8d/skills/disciplines/performance-optimization/SKILL.md), gamedev-skills/awesome-gamedev-agent-skills at `38a4c2500eeb5ff9ac084336b8f66108069d2f8d`, Apache-2.0. The source verifies the methodological emphasis on measurement, CPU/GPU classification, one bottleneck per iteration, and pooling/batching/allocation/asset budgets. This text is an original restatement, with explicit wait-time and submission-cost distinctions; no upstream code or prose is copied.

Actual speedups, suitable budgets, and device behavior are unverified until measured in the project. Verify-current-policy before application: confirm supported device tiers, available profiler counters, build configuration, current engine documentation, and the project's quality/performance acceptance policy.
