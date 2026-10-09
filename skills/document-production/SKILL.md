---
name: document-production
description: Produce and reopen Markdown, editable DOCX/PPTX/XLSX, and PDF from structured source using independently written local examples.
---

# Document Production

## Core principle

A document is finished when its content survives reopening and its layout is readable in the target viewer. A successful save alone proves neither.

## Decision criteria

Choose Markdown for reviewed text, DOCX for prose editing, PPTX for editable slides, XLSX for tabular source values, and PDF for a fixed reading copy. Use appropriate libraries; do not rename Markdown to a binary extension. Preserve facts, numbers, caveats, and reading order.

`scripts/markdown-document.mjs` retains the small title/bullet Markdown path. `scripts/office-document.py` generates actual Office ZIP/XML packages or PDF, then reopens them before atomically replacing the output. Both accept source shaped as `{"title":"Harbor notes","blocks":[{"type":"bullets","items":["Keep one fact per bullet"]}]}`. Unknown blocks are rejected, not silently dropped. The binary example supports this intentionally bounded source schema, not arbitrary templates, rich tables, charts, macros, or a general document converter.

Python 3.10+ and the packages pinned in `scripts/requirements.txt` are required for the binary example. DOCX uses python-docx 1.2.0 (MIT), PPTX uses python-pptx 1.0.2 (MIT), XLSX uses openpyxl 3.1.5 (MIT), and PDF uses ReportLab 5.0.1 (BSD) plus pypdf 6.20.0 (BSD-3-Clause). These maintained libraries are installed separately and not vendored; their licenses remain their own. The script and method are original and contain no proprietary document-Skill text.

The example paginates slides at five bullets, rejects titles over 80 characters and slide bullets over 160 characters or containing newlines, and checks slide count/text. These conservative bounds do not replace visual layout review. Spreadsheet inputs stay literal strings, including `=...`; no formulas are evaluated. DOCX read-back checks paragraph order. PDF checks extracted text and page count. ASCII uses the built-in PDF font; non-ASCII requires `--font PATH` to a licensed TrueType font covering the source glyphs. Without one it fails rather than emitting missing-glyph squares.

### Reference

Original method and scripts using public library APIs: [python-docx](https://python-docx.readthedocs.io/), [python-pptx](https://python-pptx.readthedocs.io/), [openpyxl](https://openpyxl.readthedocs.io/), [ReportLab](https://docs.reportlab.com/), [pypdf](https://pypdf.readthedocs.io/), and [CommonMark](https://spec.commonmark.org/0.31.2/). Package versions and license metadata were checked during the repair.

## Workflow

1. Define format and structured source; reject unsupported blocks explicitly.
2. Install the selected local dependencies in an isolated environment.
3. Generate, reopen, and compare source text/numbers and object counts.
4. Open Office output in the actual receiving editor and PDF in a viewer; inspect overflow, pagination, fonts, and links if present.
5. Report programmatic and visual checks separately; do not claim viewer compatibility from read-back alone.

## Worked example

Run from the package root. PowerShell installation and execution (use `.venv-documents/bin/python` on POSIX):

```powershell
python -m venv .venv-documents
.venv-documents/Scripts/python -m pip install --only-binary=:all: -r skills/document-production/scripts/requirements.txt
.venv-documents/Scripts/python -I skills/document-production/scripts/office-document.py --input tests/fixtures/capability/document-input.json --format docx --output notes.docx
.venv-documents/Scripts/python -I skills/document-production/scripts/office-document.py --input tests/fixtures/capability/document-input.json --format pptx --output notes.pptx
.venv-documents/Scripts/python -I skills/document-production/scripts/office-document.py --input tests/fixtures/capability/document-input.json --format xlsx --output notes.xlsx
.venv-documents/Scripts/python -I skills/document-production/scripts/office-document.py --input tests/fixtures/capability/document-input.json --format pdf --output notes.pdf
.venv-documents/Scripts/python -I tests/document-production.test.py
```

Keep the environment and generated files outside the formal package when developing the package itself. Each successful command emits JSON with `output`, `format`, `reopened: true`, and paragraphs/slides/rows/pages. Missing libraries exit 2; invalid source, unsupported text, or output errors exit 1. Output extension must match the selected format, and the destination parent must exist. Unsupported content and failed read-back never replace an existing document.

## Failure signals

- Markdown bytes are distributed with an Office extension.
- Unsupported source content is dropped during rendering.
- Spreadsheet text unexpectedly executes as a formula.
- Reopening is called visual acceptance, or unavailable Office/PDF viewers are reported as checked.

## Evaluation scenario

`python -I tests/document-production.test.py` in the configured environment generates and reopens all four formats, compares exact text and numbers, tests literal spreadsheet formula-like input, checks slide pagination, and verifies failed generation preserves existing output. The package's optional `verify-package.ps1 -DocumentPython PATH` runs this same suite. Actual Office-application rendering, font substitution, accessibility tagging, and visual PDF pagination still require target-viewer inspection.

## Boundary

This Skill never authorizes broader scope, branch integration, or orchestration control. Product direction, scope, and irreversible choices stay with the user.
