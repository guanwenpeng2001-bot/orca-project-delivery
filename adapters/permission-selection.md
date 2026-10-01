# Permission Selection

## Default

Manual or least privilege is the default.

A Git worktree isolates the checkout but is not a security sandbox.

## Role guidance

- Scout/Product/Planner/Architect/Reviewer: read-only or read-and-test.
- Implementer/Fixer/Test Engineer/Merge Resolver: workspace write only as needed.
- No Worker receives orchestration control unless explicitly authorized.
- External side effects require user authorization.

## Unattended mode

Use Agent-specific unattended flags only when:

- project policy permits it;
- the Task is bounded;
- the worktree is isolated;
- secrets and external systems are protected;
- the expected commands are understood;
- the user has not requested manual approval.

Read the current Orca permission behavior before launch. The registry's flags are advisory snapshots, not authority.

## Recording

Attempt records include requested and effective permission mode and any command override.
