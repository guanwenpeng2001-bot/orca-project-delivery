---
name: security-review
description: Review trust boundaries, authentication, authorization, input handling, secrets, sensitive data, injection, dependencies, configuration, and abuse paths. Use for security-sensitive changes.
---

# Security Review

## Core principle

A security finding is a plausible path from an actor to an asset, backed by evidence in the code. Hardening advice with no such path is not a vulnerability and should not be reported as one.

## Decision criteria

Start with a short threat model rather than a checklist. Name the assets worth taking, the actors involved, and every boundary where trust changes — between user input and the server, between services, between the server and the database, between the server and the filesystem. Then ask, at each boundary, what goes wrong if the data crossing it is hostile: can it be spoofed, tampered with, repudiated, leaked, denied, or used to gain privilege.

Treat all input as untrusted until validated, and that includes output from a language model, content fetched from upstream services, and values read back out of storage that users can influence. Validate against an allow-list of expected shape, not a block-list of bad characters.

The reliable defenses are structural, not pattern-based:

- Queries are parameterized. Build them so data can never be parsed as a statement.
- Output is encoded for the context it lands in. The encoding that makes text safe inside HTML body content does not make it safe inside an attribute, a URL, or a script.
- Authorization is checked on the server against the specific object being accessed, not inferred from whether the UI showed the button.
- Secrets come from the environment or a secret store, never from source, and are never written to logs.
- Files and URLs derived from user input are constrained to an expected prefix and scheme. A path is resolved before use and rejected if it escapes its directory; a URL is rejected unless its host is on the allowed list, so a request cannot be aimed at an internal address.

Rate severity by combining how reachable the path is with what the asset is worth. A flaw that requires an already-privileged actor and exposes low-value data is not critical, however untidy the code looks.

### Input that does not look like input

Untrusted data is not only what arrives in the current request. It includes records written earlier by users and read back now, content fetched from upstream systems, configuration that an attacker could have influenced, and output from a language model. Apply the same boundary checks wherever such data is used to build a query, a path, a command, markup, or an outbound request. The mistake is trusting data because it came from your own database rather than asking who put it there.

### Authorization, session, and tenancy

Authentication establishes who the caller is; authorization establishes what they may do to a specific object. Check both, on the server, for every operation that reads or changes data. The failure to watch for is an object reference the caller supplies — an id in the request — that the server fetches without confirming it belongs to the caller's account or tenant. Hiding the control in the interface does not prevent the request being made directly.

Session integrity matters at the transitions: issue a new session identifier on login so a pre-login identifier cannot be carried forward, expire sessions, and invalidate them on logout and on privilege change. Store password material only as a slow hash, never reversible and never in logs.

### Dependencies and supply chain

A change that adds or upgrades a dependency imports that dependency's behavior and its transitive dependencies. Note what was added, whether it is maintained, and whether it runs in a context with access to secrets or to user data. Pin versions so a later publish cannot change what you ship. Treat build and release steps as part of the attack surface: a compromised build step can alter the artifact after review.

### Reporting a finding

State the actor, the entry point, the path through the code, the asset reached, and the preconditions. Rate severity from reachability and asset value together, and say how confident you are given what you could and could not verify. Recommend the smallest change that closes the path and the test that demonstrates it is closed. Do not include exploit payloads or secret values in the report.

### Patterns to trace, not to assume

These are patterns to follow through the code. None is a finding until you can show the path and name the asset.

- Injection: untrusted data built into a query, a command, a template, or a path. The defense is structural — parameterized queries, argument arrays instead of shell strings, output encoded for its destination.
- Broken access control: an identifier from the request used to load data without checking ownership, or an authorization check present on one operation but missing on a sibling operation that reaches the same data.
- Sensitive data exposure: credentials, tokens, or personal data written to logs, error responses, or anything returned to the client.
- Cross-origin state changes: an operation that changes data and authorizes solely by a cookie, so a page on another origin can trigger it.

## Workflow

1. Name the assets, actors, trust boundaries, and entry points the change introduces or touches.
2. Trace authentication, session handling, authorization, tenant separation, and every place privilege changes.
3. Follow untrusted data from where it enters to where it is used: queries, rendered output, file paths, commands, and outbound requests.
4. Check secrets, cryptography, sensitive data in logs and caches, and transport.
5. Check what the change pulls in: dependencies, configuration, and build steps.
6. For each finding, state the path, the asset, the likelihood, and the confidence.
7. Recommend the smallest change that closes the path, and how to verify it is closed.

## Worked example

A feature adds `POST /imports` that fetches a user-supplied URL and stores the response.

The trust boundary is the outbound request: the caller controls the destination. The asset is access to the internal network and to cloud metadata addresses.

Tracing the code, the URL is passed straight to the HTTP client. A caller submitting `http://169.254.169.254/` reaches the instance metadata service and the response, including credentials, is stored and returned. That is a server-side request forgery, reachable by any authenticated user, exposing high-value credentials: a blocker.

The fix constrains the scheme to `https`, resolves the host, and rejects addresses in loopback, link-local, and private ranges, re-checking after redirects. The verification is a test that submits an internal address and asserts it is rejected before any request is made.

A second observation — that the handler lacks a request-size limit — is a real robustness gap but a separate, lower-severity finding, because it does not by itself expose an asset.

## Failure signals

- Findings say "validate input" without naming which input, which boundary, or what happens if it is hostile.
- Severity is assigned from the vulnerability's name rather than from its reachability and the asset behind it.
- A block-list of forbidden characters is accepted as the defense.
- Authorization is assumed because the user interface hides the control.
- A secret or credential value appears in the review report or in logs.
- The review explores exploit mechanics beyond what is needed to demonstrate the path.

## Evaluation scenario

Given a new endpoint that accepts a file and stores it, the review should name the trust boundary and the asset, describe the path by which a hostile filename could escape the storage directory, map it to a concrete code location, and state a fix that constrains the resolved path plus the test that proves an escaping name is rejected. It fails the method if the only output is generic hardening advice, or if a severity is given with no statement of who can reach the flaw and what they gain.

## Output

- Threat scope: assets, actors, boundaries
- Findings with path, evidence, affected asset, and severity
- Mitigation and how to verify it
- Residual risk

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
