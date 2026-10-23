---
id: example-role
name: Example Role
category: engineering
defaultSkills: []
optionalSkills: []
---

# Example Role

## When to use

State the deliverable and situations this Role owns.

## Responsibilities

State implementation boundaries, decision rights, and evidence obligations.

## Non-goals

State responsibilities assigned to other Roles.

## Inputs and outputs

List the Task inputs and concrete outputs needed for review.

## Completion

Describe acceptance evidence and reporting obligations. Execute only the assigned Task. Native internal helpers may work within it; the parent owns scope, write isolation, results and cleanup. Creating other Orca Tasks or Runs requires explicit authorization.

## Registration checklist

- Save as roles/engineering/example-role.md after replacing the example ID and content.
- Register the same ID, name, category, path, defaultSkills, and optionalSkills in roles/catalog.json.
- Add a role-selection deliverable route when needed. Roles describe responsibility and Skill bindings, not Agent, model or effort selection.
- Declare optional requires only in the catalog; use schemas/requirements.schema.json. Declarations contain names and purposes, never values, hooks, or commands to execute.
- Update PACKAGE-MANIFEST.json role count and run scripts/verify-package.ps1.
