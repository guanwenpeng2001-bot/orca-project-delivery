---
name: game-testing-ladders
description: Build a game verification ladder from offline smoke through story, regression, soak, real-device, and certification checks with explicit evidence limits. Use when planning game tests, validating a fix, or assessing release readiness.
---

# Game Testing Ladders

## 1. When to use / When not to use

Use to choose the cheapest test that can expose a defect, then establish what higher-cost validation is still required. The progression is smoke -> story -> regression -> soak -> certification, with real-device validation as a distinct required rung before certification for the declared release targets.

Do not treat this method as a platform compliance checklist or a substitute for player research. Consult project-side requirements for certification details. A runnable editor is not evidence of a shippable build, and a null renderer cannot prove visual correctness. An unknown target or an unavailable build blocks the corresponding readiness claim, not unrelated local testing.

## 2. Novice orientation

A test needs a starting state, an action, an expected result, and an observation. Start with one small rule, such as collecting a coin increasing the balance exactly once.

1. Identify the function or simulation that owns collection. Set up a player with zero coins and a single collectible in a local test fixture.
2. Trigger collection and assert a balance of one. Trigger the same consumed collectible again and assert the balance stays one. Use fixed inputs and a fixed simulation clock where possible.
3. Run this without network access. If the game needs an external service, test the local rule with an explicit substitute and label the real service interaction untested.
4. Launch the smallest scene with rendering disabled through the project's documented runner. Check that it initializes, advances a declared number of ticks, and exits successfully without errors.
5. Play the same collection path in a rendered build. Confirm that feedback, input, and saved state match the rule. Record the build and what you observed.

First-session checklist: one runnable rule test, one startup smoke result, one player-path observation, and a list of layers not yet assessed. If a runner is missing, record the missing prerequisite and hand its setup to the implementation owner; do not invent a successful run.

| Term | Meaning |
| --- | --- |
| Smoke | A short check that essential execution works well enough to continue testing |
| Story | A complete player goal, including its visible result and relevant failure/recovery paths |
| Regression | Previously working behavior or a repaired defect becoming broken again |
| Soak | Repeated workload over a declared duration to expose accumulating failures |
| Null renderer | A mode that advances game execution without drawing frames |
| Fixture / oracle | Controlled starting data / the condition that decides whether the outcome is correct |
| Certification | Assessment against the current requirements of a specific distribution target |

## 3. Core method

### Establish the test contract

Record build revision, target list, test environment, critical player paths, known defect cases, and the budgets to judge. Each case needs an ID, starting data, actions, oracle, runner or manual procedure, and applicable targets. Use existing project records; this method does not create a second lifecycle system.

Decide which external interactions can be simulated locally and which require live integration. Keep offline results scoped to the rules actually exercised. A service substitute can test timeout handling but cannot prove the service's current response format or availability.

### Advance through explicit rungs

The order is a progression of evidence, not a requirement to rerun every long test after every edit. After a change, rerun affected cases and the lower checks needed to trust the new build. A higher-rung failure returns work to the relevant lower rung; prior observations remain tied to their original build and configuration.

| Rung | Entry criteria | Work and observable exit criteria |
| --- | --- | --- |
| Smoke: offline logic and null-renderer startup | Local runner, fixtures, expected rule outcomes, startup scene, tick count, and timeout are defined | Run deterministic logic without network access; separately start, tick, and close the game with rendering disabled. Exit when every required assertion passes, initialization/cleanup succeed, and no unexpected errors or timeout occur. Report these two subchecks separately. |
| Story | Relevant smoke checks pass; a player goal and expected visible/state outcomes are specified | Exercise the goal in a rendered build, including applicable cancellation, loss/retry, pause, and persistence paths. Exit when each required step and recovery oracle has an observation, with no unresolved blocking defect. |
| Regression | Current critical paths and fixed-defect cases are mapped to executable or explicit manual tests; relevant story paths pass | Run the curated selection of existing tests for the changed scope and its consumers. Exit when all required selected cases pass and every fixed defect has a test demonstrated to catch its original behavior. |
| Soak | Short checks pass; workload, seed/input schedule, duration or cycle count, warmup, sampling interval, and limits are declared | Repeat representative play, scene transitions, and resource churn. Exit only after the full declared workload completes, no crash or state corruption occurs, and measured memory, latency, handles, or other selected metrics remain within budgets. An early clean sample is not a completed soak. |
| Real-device | A candidate build installs; short checks pass; representative target devices, OS versions, output/input modes, and budgets are selected | Run critical paths on physical target hardware, including relevant lifecycle interruptions, constrained performance, and input/audio/display behavior. Exit when every required matrix cell has passing evidence and device-specific limits hold. Run device soak here where thermal or lifecycle behavior demands it; host soak cannot substitute. |
| Certification | Required lower rungs, including real-device checks, pass for the candidate; distribution scope and current requirement version are known | Map each applicable requirement to evidence or an explicit justified non-applicability decision. Exit when the applicable requirements are satisfied and any required external approval is actually recorded. Internal checklist completion alone is not external certification. |

Keep the real-device rung separate even when some story or soak tests also ran on hardware. State which device/configuration each observation covers. Emulators, headless runners, editor previews, and remote service stubs never fill a physical-device cell by implication.

### Curate regressions rather than duplicate them

Maintain an index of existing tests covering critical paths and repaired bugs. Regression is a selection criterion, not another implementation of every test. Link each selected test to the behavior it protects and keep its actual runner or manual procedure discoverable. Update the selection when critical paths change; remove an entry only when its behavior is deliberately retired or another test demonstrably covers it.

Each bug fix carries a test that would expose the original defect. Prefer observing the test fail on the pre-fix implementation and pass with the fix. When the original environment cannot be reproduced, provide a controlled reproduction of the same defect and label any remaining equivalence uncertainty; a test that only passes after the fix is not proof it catches the bug. Visual or device bugs may need a reproducible manual comparison with a concrete oracle.

Record flaky outcomes as failures to establish reliable evidence. Investigate timing, shared state, uncontrolled randomness, and environment variance; retain the first failure and subsequent attempts. Rerunning until green cannot establish an unconditional pass. A quarantined required case leaves its behavior unassessed unless other evidence covers it.

### Report observations and their limits

For each rung report planned, executed, passed, failed, and unassessed case counts with reasons, build/configuration, and pointers to existing logs or captures. State the next missing observation. Do not collapse local logic, rendered play, device testing, and external approval into one green label.

## 4. Failure criteria and measurable invariants

- For each declared required set, `planned = passed + failed + unassessed`; every case receives exactly one final assessment. A blocked or unrun case belongs to unassessed. Record attempts separately so retries do not inflate coverage.
- A pass requires a nonempty declared scope, all its required cases executed with their oracles satisfied, and no remaining required unassessed case. A scope containing zero cases cannot yield 100% coverage.
- For a fixed seed and configuration on the supported deterministic runner, logic results must match the declared repeatability oracle. Do not assume floating-point simulation is identical across devices unless the game explicitly guarantees and tests that property.
- A soak requires completed duration/cycles and measured values against predeclared limits. For example, if the project sets a retained-memory-growth limit, compare equivalent post-warmup states across cycles rather than comparing unrelated peaks.
- Each fixed bug maps to a demonstrated regression case. A passing case whose assertions never inspect the original failure is a coverage gap.
- Missing build, targets, workload, thresholds, test results, or approval evidence yields `NOT ASSESSED - NO DATA` for the affected claim. List what is absent and how to obtain it; refuse an overall readiness pass. If there is also a known failure, report not ready and preserve the missing-data list.
- Explicit `certification: none` is a scoped decision that external certification is not required, with its reason recorded; it is not a claim of certification. An absent certification decision remains unassessed and must not be converted into none. Other release checks still apply.

Evaluation scenario: all offline tests pass, no physical device was used, the soak stopped halfway, and certification scope is blank. Smoke may pass; device and certification remain unassessed, soak is incomplete, and release readiness cannot pass. Repeat with a coin-duplication fix whose added test also passes against the original bug: reject the claimed regression coverage until the oracle exposes duplication.

## 5. Platform/engine boundary

Project `AGENTS.md`, `externalSkills`, and `roleBindings` identify the active engine test runner, device harness, build instructions, and distribution requirements. Follow those sources for invocation syntax, credentials, device provisioning, and certification submission. This skill chooses cases and evaluates evidence; it does not invoke external studio hooks, dispatch agents, install a toolchain, submit a build, or authorize branch integration.

## 6. Sources and verification status

Consulted on 2026-10-23: [assessment and regression source repository](https://github.com/Donchitos/Claude-Code-Game-Studios/tree/05ad7c8a5b8aa2aa86bbd3439ae7cf7295cac418), MIT. Source inspection verified three permitted ideas: missing-input refusal, distinguishing an explicit none from an absent decision, and curating existing tests with a defect-catching case for each fix. Only those ideas informed this original text; no upstream skill files, scripts, hooks, or orchestration mechanisms were incorporated.

The ladder, rung criteria, offline simulation, null-renderer distinction, and real-device boundary are locally organized method design. They have not been validated by running a game as part of authoring this skill. Project effectiveness remains unassessed until the prescribed observations exist.

Verify-current-policy checklist: before release, recheck the distribution target's current certification requirements and effective date, engine runner compatibility with the installed version, and the supported device/OS matrix. A pinned methodology source is not evidence that current platform policy has been satisfied.
