---
name: technical-research
description: Research current technical behavior using primary sources, source code, standards, and reproducible experiments. Use when library, CLI, protocol, platform, or vendor behavior can affect a decision.
---

# Technical Research

## Core principle

Base technical decisions on current primary evidence, not on memory or secondary retellings. When the evidence is ambiguous, run the smallest experiment that resolves it, and label everything you could not verify.

## Decision criteria

Prefer sources in this order: the current official documentation or specification, the release notes for the version in question, the source code of the library or tool, and only then secondary write-ups. A blog post or answer site can point you at a primary source; it is not itself evidence about behavior.

Pin every claim to a version and a date. Behavior differs across versions, so "the library supports X" is meaningless without the version observed. Record the version, the platform, and the date you checked, and note where a behavior is gated by edition, license, or configuration.

When documentation disagrees with itself or stays silent on the point that matters, write a minimal reproduction and run it. Prefer an experiment over prolonged reading once reading has stopped reducing uncertainty. Record the exact setup and result so it can be rerun.

Compare options on axes that change the decision: what each can and cannot do, what adopting it costs in migration and operations, whether the choice is reversible, and what risk it carries. A comparison that lists features without these does not support a choice.

Label the status of each significant claim: verified (you saw it in a primary source or ran it), inferred (it follows from verified claims but was not directly observed), disputed (sources disagree), or unavailable (you looked and could not establish it). Never upgrade an inference to a verified claim by phrasing.

### Recording evidence so it stays useful

For each source, note the title or location, the version it covers, and the date you consulted it, so a later reader can judge whether it is still current. Quote or paraphrase only what the source states, and keep your own conclusion separate from it. For an experiment, record the exact commands, versions, and output, not a summary of what you remember happening. This is what makes the difference between a finding someone can recheck and a claim they have to trust.

### Reading sources critically

Check that the source actually supports the claim you are attaching to it. A page that describes a feature does not establish its performance, its limits, or its behavior under failure; cite it only for what it states. Check the date and the version the source applies to, and prefer the documentation matching the version you would actually run. Where sources conflict, report the conflict rather than picking the convenient one, and resolve it with the source code or an experiment.

Account for gated behavior. A feature available only in a paid edition, only behind a flag, or only on one platform is not available to the project unless the project meets that condition. State the condition next to the claim.

### Experiments that settle a question

Keep the experiment minimal and targeted at the single point of uncertainty. Change one variable, record the exact versions and configuration, and capture the output. An experiment that passes does not establish behavior beyond what it tested: note the boundary. Where you cannot run one — no access to the environment, prohibitive cost — mark the claim unverified and say what experiment would settle it, so the gap is visible and actionable.

### Turning evidence into a recommendation

Close with a recommendation aimed at the decision the research was asked to support, and state the conditions that would change it. Scale the evidence to how hard the choice is to undo. A reversible choice can rest on solid documentation; a choice that is costly to reverse should have a primary source, with version and date, behind every claim it depends on, plus an experiment wherever those sources are silent.

Name what you could not establish. A recommendation that lists its open points lets the reader decide whether those points matter here, which is more useful than a confident answer that hides them.

## Workflow

1. State the decision the research serves, the environment, and the version range that matters.
2. Search official documentation, specifications, release notes, and source first.
3. Record the source, its version, its date, and any gating for each claim.
4. Where documentation is ambiguous or silent, run a minimal reproducible experiment.
5. Compare the viable options on capability, limits, cost, reversibility, and risk.
6. Mark each claim verified, inferred, disputed, or unavailable, and state what remains open.

## Worked example

Decision: can the project safely upgrade its database driver, given a report that the new major version changes transaction isolation behavior?

Primary evidence: the driver's upgrade guide for the target version states that the default isolation level changed, and names the old and new defaults. The release notes confirm the version where it landed. Both are recorded with version and date. A forum thread claiming the change is silent and automatic is noted as secondary only.

The ambiguous point — whether an explicit isolation level set per transaction overrides the new default — is not answered by the guide. A minimal experiment opens a transaction, sets the level explicitly, and reads back the effective level. It confirms the explicit setting is honored. Setup and output are recorded so the result can be reproduced.

Comparison: staying on the current version avoids the change but forgoes two fixes the project needs; upgrading requires auditing queries that relied on the implicit default. The choice is reversible, since the driver can be pinned back, which lowers the stakes.

Status labels: the default change is verified from the upgrade guide; the explicit-override behavior is verified by experiment; the claim that no application changes are needed is disputed, since it contradicts the guide.

## Failure signals

- A claim about a library's behavior cites memory or a secondary article and no primary source.
- A behavior is asserted without the version it applies to.
- Documentation that is silent on the decisive point is treated as implying the convenient answer.
- Two options are compared by a feature list with no mention of cost, reversibility, or risk.
- An inference is phrased as a verified fact.
- A source is cited for a claim the source does not actually make.

## Evaluation scenario

Given a choice between two libraries for a task, the result should cite a primary source with version and date for each material claim, resolve at least one point the documentation leaves ambiguous by a recorded experiment, compare the options on migration cost and reversibility as well as capability, and label any claim that could not be verified as unavailable rather than filling the gap. It fails the method if the recommendation rests on secondary sources or unstated memory, or if missing evidence is papered over with a confident assertion.

## Output

- Research question and the decision it serves
- Environment, versions, and dates
- Primary evidence per claim
- Experiments and their results
- Option comparison
- Status of each claim and remaining uncertainty

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
