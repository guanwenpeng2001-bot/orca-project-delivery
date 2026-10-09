---
name: observability
description: Design logs, metrics, and traces that identify a failed unit from evidence. Use when adding or reviewing operational instrumentation.
---

# Observability

## Core principle

Instrumentation is useful when a person who was not present can identify the failed unit and whether the failure is saturation, a bad request, or a dependency. Volume of telemetry is not evidence.

## Decision criteria

Give each request one correlation identifier and carry it through every service boundary and log line. Without it, timestamps from several hosts only suggest a connection.

Log an outcome at the boundary: operation, stable error class, duration, and whether the caller can retry. Do not log secrets, prompts that contain credentials, or full personal payloads. A high-volume success path records counts and latency, not one unstructured line per item.

Use three metric families. A counter records events, a histogram records latency, and a gauge records current occupancy. Label by low-cardinality dimensions such as operation and result. A label containing user, request, or document identifiers is an unbounded series and will overwhelm the system.

Trace across a remote call when the owner of the delay is otherwise ambiguous. A trace that duplicates every function call inside one process adds cost without narrowing ownership. Alert on symptoms a user can experience, such as error rate or exhausted capacity, and link the alert to the query or log that distinguishes causes.

### Reference

The method is original. Cardinality and correlation practices align with the OpenTelemetry specification’s guidance on attributes and context: https://opentelemetry.io/docs/specs/otel/

## Workflow

1. Name the failure that the operator must diagnose.
2. Add the smallest correlation, log, metric, or trace that distinguishes its causes.
3. Produce the failure in a fixture and locate it from telemetry alone.
4. Check that secrets and high-cardinality values are absent.
5. Record any production backend that was not exercised.

## Worked example

A tide import can fail because the file is malformed or because the database is exhausted. The boundary log includes `import_id`, error class, and duration. A histogram named `import_duration_seconds` has labels `result=accepted|rejected|dependency`, not the filename. During a fixture, refusing one malformed row increments `rejected`; stopping the database increments `dependency`. The operator identifies which fault occurred without reading application source.

## Failure signals

- Logs contain tokens, connection strings, or complete user records.
- A dashboard has dozens of series created from raw identifiers.
- The only signal is “request failed,” with no operation or dependency distinction.
- An alert fires on one internal function’s call count rather than caller-visible failure.

## Evaluation scenario

Given two injected faults, the result shows telemetry that distinguishes them and names the correlation field. It fails if diagnosis requires adding temporary logging after the fault.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
