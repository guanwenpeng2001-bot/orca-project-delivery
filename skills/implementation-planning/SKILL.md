---
name: implementation-planning
description: Turn an approved requirement and design into small, self-contained, dependency-aware Tasks with exact scope, acceptance, tests, roles, skills, branches, and reports.
---

# Implementation Planning

## Core principle

A task is well planned when a capable worker can execute it without asking what was meant. If executing it requires guessing about scope, about what "done" means, or about which files may be touched, the plan is not finished.

## Decision criteria

Size each task so it contains one coherent change that ends in something independently verifiable: a test that passes, a command that succeeds, or a behavior that can be demonstrated. A task that cannot be verified until several other tasks land is too big, and a task whose output is "understanding" or "progress" is not a task.

Order tasks by real dependency only. A dependency exists when one task consumes another's output or its interface. "It would be nice to do this first" is not a dependency. Prefer a wide graph of independent tasks that each integrate into the delivery line over a deep chain where every task is blocked on the previous one.

Give each task one owner and one branch. Two writers on one branch will overwrite each other. If work looks inseparable, it is one task.

Make the scope explicit in both directions: the files or modules the task may change, and the ones it must not. State the acceptance criterion as a command or an observable result, not as "implemented" or "working."

Preflight the graph before handing it off. Check that no two tasks in the same parallel wave touch the same file, that every interface a task depends on either exists or is produced by an earlier task, that the graph has no cycle, and that every task has a way to tell it is done.

Keep product decisions out of engineering tasks. Where the plan depends on an unanswered direction choice, surface it as a decision with options rather than embedding an assumption.

### Writing a task someone can execute

Each task definition should contain, concretely: the outcome in one sentence; the paths it may change and the paths it must leave alone; the interfaces it consumes and the ones it produces; the acceptance check as a command or observable result; the tests to add; and the branch it starts from and where it integrates. A task missing any of these forces the worker to guess, and different workers will guess differently.

Order the inside of a task so that it is demonstrable early. The first step should produce something verifiable — a failing test, a skeleton that compiles — rather than leaving all verification to the end. A task whose only check is the last step hides trouble until the deadline.

### Integration shape

Prefer tasks that each merge into the delivery line independently over long chains where one task's branch is based on another's. Chains compound delay and make conflicts likely. Where a chain is genuinely required because one task produces an interface the next consumes, name that interface precisely so the second task can be reviewed against it.

Account for shared files explicitly. Tests, configuration, and schema files are where parallel tasks collide most often. If two tasks must both touch one, either sequence them or split the file's changes so each task owns a distinct part. Discovering the collision during implementation is the failure this planning exists to prevent.

### Acceptance a reviewer can run

Write each task's acceptance as an action with an observable result: a test command and the assertion it makes, a request and the response it returns, a query and the rows it produces. Phrases like "feature complete" or "working correctly" leave done-ness to judgment, and the implementer and the reviewer will judge it differently.

Where the task's purpose is that something does not happen — no duplicate is created, an unauthorized request is refused — the acceptance has to demonstrate that absence. A check that only exercises the successful path will not catch the failure the task exists to prevent.

## Workflow

1. Read the approved requirements, the design, the project rules, and the current state of the branch.
2. Split the work into tasks along ownership and verification boundaries.
3. Assign each task one role, the skills it needs, and the files it may and may not change.
4. Write each task's acceptance criterion as a command or observable result, plus the tests that prove it.
5. Draw the dependencies and group tasks into parallel waves.
6. Define each task's branch base, report location, and where it integrates.
7. Run the preflight checks and fix the graph before anyone starts.

## Worked example

A feature adds email verification on signup, touching account creation, the email sender, and the signup screen.

Split:

- Task A: the token model and its storage, verified by a unit test that a token expires and is single-use. Owns the persistence module only.
- Task B: the email-sending boundary, verified by a test that the correct message is handed to a fake transport. Owns the mail module only.
- Task C: the signup flow consuming both, verified by an integration test that an unverified account cannot sign in.

A and B share no files, so they run in parallel. C depends on both interfaces and runs after. Each names the modules it must not touch.

The preflight catches that the design assumed an email-template helper neither A nor B creates. That becomes an explicit first step in B rather than an implicit gap discovered mid-implementation.

The acceptance line for C is the integration test command, not "signup works."

## Failure signals

- A task's definition of done is a vague verb such as handle, improve, or investigate.
- Two tasks assigned to run in parallel modify the same file.
- A task has no acceptance criterion that can be checked mechanically or by observation.
- The dependency chain is deep even though most tasks could integrate independently.
- A product decision is buried inside a task as an assumption.
- A task's scope is "the codebase" rather than named paths.

## Evaluation scenario

Given a feature spanning five files, the plan should produce a graph where every task ends in its own verifiable result, no two tasks in one parallel wave share a file, every cross-task interface is named and owned by a specific earlier task, and each acceptance criterion is a command or observable check. It fails the method if any task can only be verified after later tasks finish, or if the plan leaves file ownership implicit.

## Output

- Task dependency graph and parallel waves
- Task definitions with scope, role, and skills
- Acceptance criterion and tests per task
- Branch and integration plan
- Preflight results
- Open decisions and risks

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
