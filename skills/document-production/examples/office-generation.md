# Office generation example

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
