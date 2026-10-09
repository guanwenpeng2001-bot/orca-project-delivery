---
name: react-performance
description: Measure and reduce React request waterfalls, rendering cost, and bundle weight without changing behavior. Use for evidenced React performance work.
---

# React Performance

## Core principle

Change a React performance path only after measuring the request sequence, render cost, or bundle contributing to the user-visible delay. A list of optimizations without before-and-after numbers is not a result.

## Decision criteria

Trace a waterfall by listing which requests cannot start until another finishes. Independent reads move together; a dependent read stays behind the value it needs. Fetching everything earlier is not an improvement if it loads data the interaction may never use.

Treat render cost as wasted work when the same subtree renders with unchanged inputs. Memoization helps only where measurement shows repeated rendering or an expensive calculation. Wrapping every component hides bugs and can retain stale closures. State should live where an update changes the smallest necessary tree.

For bundle weight, compare the production build before and after. Import a large library only from the route that uses it, and prefer a direct module import over an index that pulls unrelated modules. A development-server transfer size is not evidence of the shipped bundle.

React 19 introduces APIs and compiler behavior that older applications do not have. Mark any recommendation that depends on React 19 or later, and do not apply it to an unverified version. Preserve behavior tests while changing loading or rendering.

### Reference

This is an original method based on public React documentation, not a copy of a vendor skill collection. Rendering and loading guidance: https://react.dev/learn/render-and-commit and https://react.dev/reference/react/lazy

## Workflow

1. Record the current request timeline, render profile, or production bundle report.
2. Name one delay and the requests or modules responsible.
3. Make the smallest change that targets that cause.
4. Rerun the same measurement and the behavior tests.
5. Reject the change if the number does not improve or behavior changes.

## Worked example

A reading page waits for account data before requesting the first visible chart, although the chart depends only on the station identifier already in the route. Moving that request beside the account request removes one round trip, reducing fixture load from 420ms to 250ms. The production chart route remains lazy-loaded, and its existing data assertion still passes. No React 19-only API is required.

## Failure signals

- A recommendation says “memoize” without a profile showing repeated work.
- Bundle improvement is claimed from a development build.
- The change starts extra requests for hidden content and calls that faster.
- Behavior assertions fail and are weakened to preserve the optimization.

## Evaluation scenario

Given a seeded waterfall or oversized import, the result shows the original measurement, the changed measurement, and unchanged behavior tests. It fails without both measurements.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
