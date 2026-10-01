# Branch and Worktree Adapter

## Branch planes

### Coordinator control branch

Hosts:

- the only Coordinator Agent;
- local `AGENTS.md`;
- `.dev-work/`;
- orchestration state and reports.

It is not:

- a source-development branch;
- a merge target;
- a task base;
- a review target;
- a final verification branch.

Its HEAD may be stale without affecting delivery.

### Delivery branch

Resolved once at run intake:

- user-specified branch; or
- the repository default branch when unspecified, resolved as `origin/HEAD` → `init.defaultBranch` → `main` → `master` → the current branch, recorded with its source.
- an explicit `-DeliveryBranch` whenever the repository's default branch is none of the above.

It is the default task base, reviewed-source merge target, and final-verification source.

### Task branches

Every worker Task gets an isolated branch/worktree, including read-only research and review work.

Default base: `delivery_branch`.

Override only for:

- an explicit user base;
- review of a specific source branch;
- a true unintegrated prerequisite;
- historical reproduction.

## Integration

- Read-only branches are normally not merged.
- Source branches are independently reviewed before integration.
- Accepted source merges directly into the actual worktree that has `delivery_branch` checked out.
- Never merge source into the coordinator control branch.
- Final verification uses a fresh branch/worktree from the latest `delivery_branch`.
- Remove worktrees and branches only after their result is integrated, rejected, or explicitly abandoned.

## One-writer rule

One task branch has one writer at a time. A replacement Agent takes over only after authoritative stop/failure/fencing or explicit handoff.
