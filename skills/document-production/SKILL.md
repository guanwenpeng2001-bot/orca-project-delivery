---
name: document-production
description: Render structured notes into readable Markdown and check the written result. Use for source-controlled documents rather than proprietary Office binaries.
---

# Document Production

## Core principle

A document is finished when its structure is readable by a person and mechanically checked against its source. A styled binary that nobody can read back is not evidence.

## Decision criteria

Use structured Markdown for source-controlled notes, decisions, and reports. Each document has one title, headings in descending order, and lists whose items are parallel. Tables need a header and one fact per cell. Do not use formatting to compensate for an undefined reading order.

The script `skills/document-production/scripts/markdown-document.mjs` accepts a title and bullet blocks and writes the Markdown. Unsupported block types fail instead of being dropped silently. This is intentionally small: it proves a structured source can be rendered and read back without a proprietary library.

Editable Office and PDF binaries require a task-specific library whose license has been reviewed. This package does not copy proprietary document-skill text or claim Word, PowerPoint, Excel, or PDF compatibility. When such a library is separately approved, the same read-back rule applies: open the output and verify text, numbers, links, and pagination rather than trusting the conversion log.

Preserve source facts verbatim. Rounding, unit conversion, and omitted caveats are content changes and belong in a reviewed edit, not in rendering.

### Reference

The method is original. Markdown structure follows the CommonMark specification: https://spec.commonmark.org/0.31.2/

## Workflow

1. Put the title, sections, and repeated items in structured source.
2. Render with the smallest approved tool.
3. Read the output back against every source fact.
4. Reject silent omission of unsupported content.
5. Use a separately licensed library only when the delivery must be a proprietary format.

## Worked example

`document-input.json` contains title “Harbor notes” and one bullet, “Keep one fact per bullet.” The script writes exactly `# Harbor notes`, a blank line, and `- Keep one fact per bullet`. Adding a table block fails because tables are unsupported by this renderer. The failure prevents a partial document from looking complete.

## Failure signals

- The output drops an unsupported block and exits successfully.
- A binary export is accepted without opening and reading it.
- Source numbers change during formatting.
- The result claims Office compatibility without an approved library and read-back.

## Evaluation scenario

Given one bullet document and one unsupported block, the first matches the expected Markdown and the second exits nonzero. It fails if unsupported content disappears silently.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
