# Source Manifest

This package is an original implementation assembled for the user's Orca workflow. It does not copy whole prompts or skills from upstream projects.

## Orca sources consulted

Repository: `https://github.com/stablyai/orca`

Relevant source surfaces:

- `src/shared/tui-agent.ts` — canonical Orca Agent ids.
- `src/shared/tui-agent-display-names.ts` — display names.
- `src/shared/tui-agent-config.ts` — detection commands, launch commands, expected processes, prompt injection modes, aliases, trust handling, platform limits, readiness hints.
- `src/shared/tui-agent-config-types.ts` — launch metadata schema.
- `src/shared/tui-agent-permissions.ts` — unattended permission defaults.
- `src/shared/agent-session-option-catalog.ts` and provider catalogs — model/effort control.
- `src/main/runtime/rpc/methods/orchestration/worker/worker-launch-preferences.ts` — structured worker launch preference constraints.
- `docs/site/content/docs/agents/supported.mdx` — supported-agent and permission notes.
- `docs/reference/agent-skill-provider-paths.md` — verified Skill paths for Codex and Claude Code.

Policy: the installed Orca version, current global `orchestration` / `orca-cli` Skills, and live `--help` output are authoritative if this package's advisory metadata drifts.

Local verification note (2026-10-02): the repository URL above could not be verified from this
host, so treat it as unverified provenance. The installed build exposes its own command and agent
registry locally (`orca agent-context --json`), which is the better source when regenerating this
snapshot. `agents/registry.json` therefore carries an `orcaVersion` anchor and is advisory only.

## Role-design sources consulted

- Roo Code custom-mode structure and the Roo Code repository's `.roomodes`.
- `jtgsystems/Custom-Modes-Roo-Code` for examples of role categorization and role metadata.

The delivered Role files are newly written, concise, tool-neutral contracts. They intentionally omit upstream-specific fixed framework versions, assumed MCPs, synthetic business metrics, and blanket quality thresholds.

## Existing project source

The user's existing `AGENTS.md` supplied the initial project-specific defaults:

- Antigravity / Gemini 3.8 Flash / high for reconnaissance.
- Kimi K3 / max for plans and review.
- Codex gpt-6-astra / low or medium for implementation.
- Grok 4.7 / xhigh as Kimi quota fallback.
- Decision ownership, one-writer branches, requested/effective model verification, process artifact exclusion, and Orca lifecycle discipline.

These model identifiers remain requested profiles and require live capability verification before automatic routing.

Correction applied in 1.1.0: the antigravity profile now names the model the CLI actually exposes
(`gemini-3.8-flash-high`); the earlier bare `gemini-3.8-flash` id is not listed by `agy models`.
Its automatic-routing eligibility is decided by the capability probe, not by this manifest.
