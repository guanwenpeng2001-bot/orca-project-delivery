# Configuration Precedence

Highest to lowest:

1. User's explicit instruction for the current run or Task.
2. Applicable project and nested `AGENTS.md`.
3. Task Contract.
4. Run-level `.dev-work` override.
5. Project-level `.dev-work/config/` override.
6. Role Contract.
7. Required professional Skills.
8. Global Role routing and Agent profiles.
9. Agent defaults.

## Important consequences

- A user-pinned Agent/model cannot be replaced across providers without permission.
- AGENTS project rules override fixed thresholds or technology assumptions in a generic Role/Skill.
- Task scope overrides a Skill's broad checklist.
- Runtime evidence overrides requested model names.
- Installed Orca behavior overrides this package's source snapshot.
