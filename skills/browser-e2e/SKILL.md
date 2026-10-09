---
name: browser-e2e
description: Design and execute browser journeys through the real entry point, including failure paths and retained traces. Use for browser regression evidence.
---

# Browser End-to-End Testing

## Core principle

A browser test proves a caller can complete or be refused a journey through the real entry point. A locator library without an executed failure is structure, not evidence.

## Decision criteria

Select the smallest journey that crosses the boundary where the defect can hide: browser to server, server to database, or a permission check. Mock only a boundary the test does not own, such as a payment provider. Do not mock the application page under test.

Prefer locators a user could name: role, accessible name, and visible text. A generated selector tied to layout breaks when the design changes but the behavior does not. Assert the outcome the requirement states, such as “the saved reading appears,” not an internal call count.

Every regression needs one successful journey and one deliberate failure. The failure must be observed first, with a screenshot or trace retained, and then pass after the fix. A test written against working code and run once cannot show that it detects the defect.

Keep the test deterministic. Control clock, network delay, and seeded data explicitly. A wait for an arbitrary timeout hides ordering bugs; wait for the observable state instead.

Node.js is the declared host for the project’s browser runner. The package never installs a browser and never launches one on its own. Running `run-tide-journeys.mjs` launches an already installed local Chromium through the caller’s Python Playwright. If Python, Python Playwright, or that Chromium is missing, the caller gets a named missing-dependency error and the optional browser test skips with that reason. A skip is not browser coverage.

### Reference

The method is original. Accessible-role locators follow the W3C ARIA role model: https://www.w3.org/TR/wai-aria-1.2/

## Workflow

1. Write the journey and the refusal or defect it must expose.
2. Run it while the defect exists and retain the failing trace.
3. Apply the smallest fix and rerun the same command.
4. Add the neighboring success journey if the fix could reject it.
5. Report command, result, trace path, and anything the browser environment could not run.

## Worked example

A tide-entry journey submits a valid time and expects the new row. A second journey submits a blank time and expects the field error. With validation absent, the blank submission creates a row and the second test fails; its trace shows the row count increasing. After the server rejects the blank value, the same test passes and the valid submission still creates one row.

`skills/browser-e2e/scripts/run-tide-journeys.mjs` runs both journeys in the installed local Chromium: one that saves a tide reading and one that refuses a blank tide time, using the keyboard. It opens the fixture through a `file:` URL, so it does not need the server. Serve the fixture on loopback only when a caller needs HTTP:

```
node skills/browser-e2e/scripts/serve-fixture.mjs
```

It prints `listening http://127.0.0.1:<port>` and stops when its input ends. Pass `seedDefect: true` to `runTideJourneys` to add a row before validation. Both journeys then fail: the saved reading is preceded by an empty row, and the blank submission leaves that row. Keep that failing result even after the suite is green. A fixture address must be a local path or `http://127.0.0.1`; any other address is refused.

## Failure signals

- The suite contains page objects but no command output from a browser run.
- The only passing run predates the assertion that should catch the defect.
- The failure is an import or selector typo rather than the behavior being asserted.
- The trace is discarded after the test becomes green.

## Evaluation scenario

Given a fixture with one successful save and one seeded validation defect, the result includes a failing run that names the incorrect save, the retained trace, and a passing rerun after the fix. It fails if no failing behavioral run is shown.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
