---
name: security-review
description: Review trust boundaries, authentication, authorization, input handling, secrets, sensitive data, injection, dependencies, configuration, and abuse paths. Use for security-sensitive changes.
---

# Security Review

## Core principle

A security finding needs a plausible threat path, affected asset, and evidence.

## Workflow

1. Define assets, actors, trust boundaries, entry points, and threat assumptions.
2. Review authentication, session, authorization, tenancy, and privilege transitions.
3. Review validation, canonicalization, injection, serialization, file/network/process boundaries, and SSRF-style paths.
4. Review secrets, cryptography, sensitive data, logging, caching, storage, and transport.
5. Review dependency, configuration, deployment, and supply-chain implications.
6. Estimate exploitability, impact, confidence, and compensating controls.
7. Recommend the smallest effective remediation and verification.

## Required output

- Threat scope
- Findings with severity
- Exploit path/evidence
- Affected assets
- Mitigation
- Residual risk

## Rules

- Do not label generic hardening advice as a vulnerability.
- Do not invent an attacker capability unsupported by the system.
- Do not expose secrets in the report.
- Do not perform destructive exploitation without explicit authorization.

## Completion

The worker must write the requested report, include concrete evidence, state unresolved uncertainty, and return the Task's required completion status. This Skill never authorizes broader scope, branch integration, or orchestration control.
