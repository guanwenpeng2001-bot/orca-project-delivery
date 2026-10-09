---
name: example-skill
description: State the bounded method and when to use it.
---

# Example Skill

## Method

Provide domain-specific steps and decision criteria that a worker can apply without external context.

## Worked example

Show a realistic input, decision, and expected result.

## Failure signals

State how to detect an incorrect result and what evidence to gather.

## Evaluation scenario

Specify an input and observable success criteria for this method.

## Completion

Name required evidence. This Skill does not authorize broader scope or orchestration control.

## Registration checklist

- Save as skills/example-skill/SKILL.md after replacing the example name and content.
- Register its ID, name, description, and exact skills/<id>/SKILL.md path in routing/skill-catalog.json.
- Add the current SHA256 row to skills/README.md, retaining provenance and license notices.
- Add optional requires metadata only to the catalog using schemas/requirements.schema.json; no values or executable hooks.
- Update PACKAGE-MANIFEST.json professionalSkills count; optionally reference the Skill in a Role; run scripts/verify-package.ps1.
- Keep essential methods in this file so both explicit-path and inline-extract deliver them.
