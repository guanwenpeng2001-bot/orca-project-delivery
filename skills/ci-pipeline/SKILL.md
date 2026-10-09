---
name: ci-pipeline
description: Design deterministic CI stages, failure gates, and artifact retention. Use when changing a pipeline or diagnosing why a check did not block delivery.
---

# CI Pipeline

## Core principle

A pipeline gate is real only when a known bad change fails it and a good change passes the same command. A green badge whose command skips the relevant check is not protection.

## Decision criteria

Order stages by feedback cost: parse and unit checks before integration, and long browser or package checks after the cheap failures. Each required stage must return nonzero when its assertion fails. A stage that catches an error and prints a warning does not gate delivery.

Make inputs explicit. Pin tool versions, use a clean checkout, and do not depend on a developer machine’s cached credentials or global services. Separate network-dependent checks from deterministic tests so an outage cannot masquerade as a code failure.

Retain the evidence needed to explain a failure: test output, the exact command, and artifacts such as traces. Retaining every dependency archive indefinitely is not the same thing. Set a retention period matched to review time.

A deploy stage follows a verified build artifact rather than rebuilding from a branch that may have moved. Record who can trigger it and what environment it changes. Do not hide a failure by marking the job allowed to fail unless the check is explicitly informational.

### Reference

The method is original. Reproducible build and pipeline concepts are discussed by NIST SSDF: https://csrc.nist.gov/pubs/sp/800/218/final

## Workflow

1. Name the defect class the stage is supposed to stop.
2. Run the stage against a change containing that defect and retain the nonzero result.
3. Run it against the corrected change.
4. Confirm artifacts and logs identify the failing command.
5. Mark any stage that could not be executed in the available CI environment.

## Worked example

A package verification stage runs `verify-package.ps1`. A fixture that changes a declared count but not the catalog makes that command exit 1, so the stage fails and stores the output. Restoring the count makes the same command exit 0. The deploy stage consumes the tested archive and is not triggered by the failing commit.

## Failure signals

- A required failure is converted to a warning to keep the branch green.
- The pipeline installs unpinned tools from a network script.
- The passing run uses local state unavailable to CI.
- The retained log does not contain the failing command or its exit code.

## Evaluation scenario

Given one seeded failing check, the result shows a blocked pipeline, the retained output, and a passing rerun. It fails if the stage stays green by skipping the check.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
