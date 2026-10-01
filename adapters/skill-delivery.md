# Professional Skill Delivery

Professional Skills are global sibling folders under `.agents/skills`.

## Modes

### Native

The Agent discovers the canonical Skill root itself. **Verified on this host: Codex**
(`codex.exe` contains the `.agents/skills` lookup string, and `orca skills installed`
publishes to the `codex` provider).

### Provider alias

A provider-specific path points to the canonical root, managed by Orca.

There is currently **no verified provider alias on this host**: `orca skills installed`
lists only the `agent-skills` and `codex` providers, and the historical Claude path
(`%USERPROFILE%\.claude\skills`) does not exist. Treat `provider-alias` as unverified and
start from `explicit-path`. See `agents/skill-loading.json` for the recorded evidence.

### Explicit path

The Task lists exact paths such as:

`%USERPROFILE%\.agents\skills\code-review\SKILL.md`

The Worker must read them before starting. This is the default for every agent whose
discovery behaviour has not been verified on the current host.

### Inline extract

Use only when the Worker cannot reliably read the global path.

The coordinator records:

- Skill name;
- source path;
- file hash/version;
- included headings;
- omitted sections.

## Rules

- Do not claim a Skill was loaded merely because its name appeared in the Task; require the
  Worker to name the path it read or quote the method it applied.
- Do not inline an entire large library when only one method is needed.
- Do not give a Worker unrelated Skills.
- Skill instructions remain below user, AGENTS, Task, and Role constraints.
- Coordinator loads only `orca-project-delivery`; workers load the selected professional Skills.
