---
name: document-production
description: Produce and reopen Markdown, editable DOCX/PPTX/XLSX, and PDF from structured source using independently written local examples.
---

# Document Production

## Core principle

A document is finished when its content survives reopening and its layout is readable in the target viewer. A successful save alone proves neither.

## Decision criteria

Choose Markdown for reviewed text, DOCX for prose editing, PPTX for editable slides, XLSX for tabular source values, and PDF for a fixed reading copy. Use appropriate libraries; do not rename Markdown to a binary extension. Preserve facts, numbers, caveats, and reading order.

`scripts/markdown-document.mjs` renders the title/bullet Markdown path and the same bounded blocks as real Markdown. `scripts/office-document.py` generates actual Office ZIP/XML packages or PDF, then reopens them before atomically replacing the output. Both accept the original source `{"title":"Harbor notes","blocks":[{"type":"bullets","items":["Keep one fact per bullet"]}]}` unchanged, and also `heading` (`{"type":"heading","text":"Berth plan"}`, a level-2 heading), `paragraph` (`{"type":"paragraph","text":"..."}`), ordered `list` (`{"type":"list","ordered":true,"items":[...]}`), and `table` (`{"type":"table","columns":["Berth","Draft m"],"rows":[["North","12.4"]]}`). A table is a real DOCX table, a real XLSX cell grid, and a real Markdown table; cell text is literal, so `=SUM(A1:A2)` is stored as text and never evaluated. PPTX and PDF have no table support and reject a `table` block by name instead of dropping it. Unknown block types and malformed tables (a row whose width differs from the columns) are rejected the same way. The schema stays intentionally bounded: no merged cells, nested tables, column widths, charts, macros, or arbitrary templates.

Python 3.10+ and the packages pinned in `scripts/requirements.txt` are required for the binary example. DOCX uses python-docx 1.2.0 (MIT), PPTX uses python-pptx 1.0.2 (MIT), XLSX uses openpyxl 3.1.5 (MIT), and PDF uses ReportLab 5.0.1 (BSD) plus pypdf 6.20.0 (BSD-3-Clause). These maintained libraries are installed separately and not vendored; their licenses remain their own. The script and method are original and contain no proprietary document-Skill text.

The example paginates slides at five lines, rejects titles over 80 characters and slide lines over 160 characters or containing newlines, and checks slide count/text. These conservative bounds do not replace visual layout review: nothing here checks whether a table overflows its page, whether column text wraps readably, or how a font substitutes in a target viewer, and read-back is not visual acceptance. Spreadsheet inputs stay literal strings, including `=...` in a table cell; no formulas are evaluated. DOCX read-back checks paragraph order and table cell text. PDF checks extracted text and page count. ASCII uses the built-in PDF font; non-ASCII requires `--font PATH` to a licensed TrueType font covering the source glyphs. Without one it fails rather than emitting missing-glyph squares. Newlines are handled per format, not by one schema rule: Markdown flattens a cell newline to a space and escapes both a literal `|` and a literal backslash, so neither can break out of its cell, while DOCX and XLSX keep a newline inside the cell and PPTX rejects any newline in slide text.

### Reference

Original method and scripts using public library APIs: [python-docx](https://python-docx.readthedocs.io/), [python-pptx](https://python-pptx.readthedocs.io/), [openpyxl](https://openpyxl.readthedocs.io/), [ReportLab](https://docs.reportlab.com/), [pypdf](https://pypdf.readthedocs.io/), and [CommonMark](https://spec.commonmark.org/0.31.2/). Package versions and license metadata were checked during the repair.

## Workflow

1. Define format and structured source; reject unsupported blocks explicitly.
2. Install the selected local dependencies in an isolated environment.
3. Generate, reopen, and compare source text/numbers and object counts.
4. Open Office output in the actual receiving editor and PDF in a viewer; inspect overflow, pagination, fonts, and links if present.
5. Report programmatic and visual checks separately; do not claim viewer compatibility from read-back alone.

## Worked example

Before first-time Office/PDF generation, load [Office generation example](examples/office-generation.md) for dependency setup and commands; keep development environments and generated files outside the formal package.

Accept JSON `output`, `format`, `reopened: true` and object counts only as programmatic evidence. Missing libraries exit 2; invalid source/text/output exits 1. Match output extension to format and use an existing destination parent. Unsupported content or failed read-back must preserve existing output.

## Failure signals

- Markdown bytes are distributed with an Office extension.
- Unsupported source content is dropped during rendering.
- Spreadsheet text unexpectedly executes as a formula.
- A table block is silently flattened or dropped for a format that cannot represent it.
- Reopening is called visual acceptance, or unavailable Office/PDF viewers are reported as checked.

## Evaluation scenario

When maintaining this Skill or its scripts, load [Document production evaluation](references/evaluation.md) for regression suites and expected cases; actual viewer rendering, table overflow, font substitution, accessibility tagging and PDF pagination still need visual inspection.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
