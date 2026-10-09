# Installation

**English** | [简体中文](zh-CN/installation.md)

This guide installs the `orca-project-delivery` coordinator Skill so a Claude
Code coordinator session can load it from your control worktree. The package
is a plain directory of files — there is no installer, no package registry,
and no build step.

## Prerequisites

| Requirement | Notes |
| --- | --- |
| Windows | All scripts have only been exercised on Windows. Other platforms are untested. |
| PowerShell 7+ (`pwsh`) | Windows PowerShell 5.1 is not sufficient. Check with `pwsh -NoProfile -Command '$PSVersionTable.PSVersion'`. |
| Git | On `PATH`; used for branches, worktrees, merges, and evidence validation. |
| Claude Code | Installed, on `PATH`, and authenticated. All workers are Claude Code agents. |
| Orca Runtime | The `orca` CLI plus the installed global `orchestration`, `orca-cli`, and `orca-per-workspace-env` Skills. They own Run/Task/Dispatch/Worker lifecycle; this package never replaces them. |
| Professional Skills | **Bundled** — all 38 professional Skills ship inside this package under `skills/<skill-id>/SKILL.md`. No separate install step. The original sixteen trace to [orca-professional-skills](https://github.com/guanwenpeng2001-bot/orca-professional-skills); every Skill's upstream, pinned commit, and license are in `skills/README.md`. |

The Skills referenced by `routing/skill-catalog.json` are the original sixteen
plus the twenty-two added in 2.3.0. The original sixteen are
codebase-reconnaissance, technical-research, product-discovery,
product-design, requirements-analysis, solution-architecture, api-design,
database-design, implementation-planning, test-driven-development,
systematic-debugging, code-review, security-review, performance-review,
integration-verification, and merge-conflict-resolution. The added Skills and
their evidence labels are listed in
[Professional capabilities](professional-capabilities.md).

## Directory conventions

The package is designed to live in your skills root:

```text
~/.agents/skills/                 # the skills root (%USERPROFILE%\.agents\skills)
├── orchestration/                # global Orca skill - do not overwrite
├── orca-cli/                     # global Orca skill - do not overwrite
├── orca-per-workspace-env/       # global Orca skill - do not overwrite
└── orca-project-delivery/        # <-- this package (includes skills/ subtree)
```

Two rules:

1. Do not overwrite the Orca-provided Skills (`orchestration`,
   `orca-cli`, `orca-per-workspace-env`). This package adds to them; it never
   replaces them.
2. Professional Skills resolve only from this package's `skills/` directory.
   The verification suite does **not** fall back to sibling directories under
   `~/.agents/skills`.

Project-local state created at runtime (`AGENTS.md`, `.dev-work/`) lives in
each *project* you deliver, not in this package directory.

For worker delivery, use `explicit-path`: the coordinator names the selected
Skill's exact readable `SKILL.md` path in the Task and requires the worker to
read it. If the path is inaccessible, `inline-extract` includes the required
sections with their source path, hash/version, included headings, and omitted
sections recorded. Naming a Skill alone is not proof that it was loaded.

## Installation steps

```powershell
# 1. Clone the package into your skills root (adjust if your root differs)
git clone https://github.com/guanwenpeng2001-bot/orca-project-delivery.git "$env:USERPROFILE\.agents\skills\orca-project-delivery"

# 2. Verify the installation (see the next section for expected output)
pwsh -NoProfile -File "$env:USERPROFILE\.agents\skills\orca-project-delivery\scripts\verify-package.ps1"
```

See [Professional Skills](professional-skills.md) for the Skill list and upstream
source. A clone of this repository is a complete installation for professional
Skills — no companion copy step.

If your skills root already contains an older copy, see
[Upgrade](#upgrade) instead of cloning over it.

If you prefer not to use the default location, you may clone anywhere — workers
still resolve Skills from the package's own `skills/` directory via
`scripts/assemble-task.ps1`.

## Verifying the installation

Run the offline acceptance suite from the package directory:

```powershell
pwsh -NoProfile -File "$env:USERPROFILE\.agents\skills\orca-project-delivery\scripts\verify-package.ps1"
```

Expected shape of the output on a healthy install:

- many `PASS <check>` lines (parse, encoding, routing, metadata, runtime
  fixtures, evidence fixtures, ...);
- a `skills: N/N resolved (... package-bundled)` summary line, where N is the Skill count of the revision you installed (38 for the 2.3.0 capability release);
- a final line of the form `SUMMARY PASS=<n> FAIL=0`;
- process exit code 0.

Quote the `SUMMARY` line you observed. The pass count describes that revision
and is not a number to memorize from an older release.

The suite is read-only with respect to the package: all fixtures and copies
are created under a temporary directory (`orca-package-verification-*`) and
removed at the end. The verdict is the `SUMMARY` line and the exit code; any
`FAIL` line means the installation is not accepted.

A note on the sibling evidence validator: when you use
`scripts/validate-git-evidence.ps1` separately at runtime, read the JSON
`status` field it prints, not only the exit code — both `PASS` and
`NOT_APPLICABLE` exit 0, and `NOT_APPLICABLE` is not acceptance.

## Extensions and local execution configuration

For new methods or responsibilities, use the native catalog recipe in [Extending](extending.md), including current-content hashes, manifest counts and model routes. Bundled Skills are maintained adaptations; this project's original work is MIT, third-party Skills keep their own license, and intentional edits are reviewed before hashes change. `verify-package.ps1 -MetadataOnly` is a quick structural check, not a substitute for the full suite. The summary above describes the revision you installed; success requires no failures, not a permanently fixed count.

The capability release adds methods for software, local assets, images, and
audio, video, and documents. Installing it does not run any of them. The
[capability tutorial](professional-capability-tutorial.md) checks the install
and the dependency helpers only; it makes no provider call, and a passing
package suite is not evidence about generated output.

Bootstrap creates `.env.example` and `project-config.example.json` only when missing, preserving existing files. It adds `/.env` to local Git `info/exclude`, shared by this clone's worktrees. Keep populated `.env` untracked on the actual execution host. Workers must supply their own explicit `ProjectRoot`; helpers neither copy coordinator config nor create worker `.dev-work/` state. The original sixteen declare no credential requirements. A 2.3.0 Skill declares a credential only when it names one, and an online connector named in the docs is an example, not a provider you have selected. No real key belongs in the repository.

## Upgrade

The installed package is deployed in place, so upgrading is replacing the
directory contents and re-verifying:

```powershell
cd "$env:USERPROFILE\.agents\skills\orca-project-delivery"
git pull --ff-only
pwsh -NoProfile -File scripts\verify-package.ps1
```

Check `git status --short` and preserve local changes before updating; do
not overwrite a customized installation. For a copy-based installation,
back up the old directory before replacing package files. Project-local state
is unaffected.

Old runs remain readable, but an unfinished source merge must have its
evidence rebuilt to meet the current gates. Validate project state with
`scripts/validate-run.ps1` and validate Git evidence separately with
`scripts/validate-git-evidence.ps1`; an upgrade does not migrate evidence
automatically.

## Uninstall

Remove the package directory:

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.agents\skills\orca-project-delivery"
```

That is the whole footprint. The package keeps no registry entries and no
state outside the projects you deliver; each delivered project keeps its own
`AGENTS.md` and `.dev-work/`, which you delete independently if desired. Do
not remove the global Orca Skills unless you no longer use anything that
depends on them.

## Troubleshooting installation failures

### Missing bundled skill

Symptom: the verification suite prints

```text
FAIL metadata/skill-paths: skill file missing: <...>\skills\code-review\SKILL.md
```

or a hash failure under `metadata/bundled-skill-integrity`.

Cause: a bundled `skills/<skill-id>/SKILL.md` is missing, was deleted locally,
or no longer matches the current SHA256 table in `skills/README.md`. Inspect and
preserve local changes first. Restore accidental damage from package Git; for an
intentional adaptation, review the body and update its hash as described in
[Extending](extending.md), then re-run the suite.

### PowerShell 7 not found

Symptom: `pwsh` is not recognized, or the suite refuses to run under Windows
PowerShell 5.1.

Fix: install PowerShell 7+ and invoke scripts explicitly with `pwsh
-NoProfile -File <script>`. Verify with:

```powershell
pwsh -NoProfile -Command '$PSVersionTable.PSVersion'
```

### Git configuration injection

Symptom: scripts fail with `fatal: missing config key GIT_CONFIG_KEY_0` even
though Git works in an ordinary terminal.

Cause: some hosts inject `GIT_CONFIG_COUNT` while stripping environment
variables whose names contain `KEY`/`TOKEN`/`SECRET`, leaving an orphaned
count that makes every Git call fail. The bootstrap, run creation, reconciliation, release, run validation, and
capability-probe scripts guard against this orphaned count. The package
suite isolates its child Git environment. For other Git invocations,
inspect and repair the invoking environment; do not clear valid paired
configuration indiscriminately.

```powershell
# Inspect and clear the orphaned variable in your own shell
Get-ChildItem Env:GIT_CONFIG_*
if ($env:GIT_CONFIG_COUNT -and -not $env:GIT_CONFIG_KEY_0) {
    Remove-Item Env:GIT_CONFIG_COUNT -ErrorAction SilentlyContinue
}
```

### Permissions and execution policy

Symptom: `pwsh -File <script>` fails with a file-loading or
execution-policy error, or writes fail inside the skills directory.

Fixes:

```powershell
# Check the effective policy for the current user
pwsh -NoProfile -Command 'Get-ExecutionPolicy -List'

# Common fix on a locked-down machine (choose one deliberately)
pwsh -NoProfile -Command 'Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
# Or bypass the policy for a single invocation
pwsh -NoProfile -ExecutionPolicy Bypass -File '<script>'
```

If the skills directory itself is not writable by your account, grant write
access or relocate the skills root.

### Verification reports unexpected FAIL count

Inspect every `FAIL` line and the `skills: ... resolved` line before
assuming success. Confirm you are running `scripts/verify-package.ps1` from the
directory you just installed, that `VERSION` matches the release you expect,
and that no `FAIL` line scrolled past. Any `FAIL` line means the
installation is not accepted, regardless of the PASS count.
