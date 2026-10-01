# Agent Model and Effort Selection

## Inputs

- Role minimum quality tier;
- Task complexity and risk;
- user-pinned provider/model;
- current host capability probe;
- Agent health and quota evidence;
- model-control mode;
- permission requirements;
- Skill-delivery support.

## Model-control modes

### `orca-launch-preferences`

Use current Orca structured launch preferences only when the Agent catalog supports them. Record the launch receipt.

### `custom-terminal-args`

Start an exact Agent command using the current Agent CLI contract, wait for readiness, verify the model, then attach the terminal to supervision. Do not add model/effort options while reusing that terminal.

### `session-command`

Start the Agent, apply model/effort inside the session, and verify through the Agent's actual status surface.

### `agent-config`

Use the Agent's own configuration. Record evidence when visible; otherwise mark effective values unverifiable.

### `unverified`

Manual-only. Exclude from automatic routes and fallbacks.

## Requested versus effective

Every attempt record contains both.

- Requested means what the coordinator intended.
- Effective means what the Agent/Orca evidence confirms.
- Unknown means unknown; do not copy requested values into effective fields.

## Selection principles

- Use the least costly healthy profile that meets the Role floor.
- Increase capability for architecture, security, difficult debugging, adjudication, and final high-risk review.
- Prefer a well-specified Task over a more expensive model.
- Do not lower quality merely to avoid asking the user when the Task is critical.
