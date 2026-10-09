import argparse
import json
import os
from pathlib import Path
import tempfile
from xml.sax.saxutils import escape


BLOCK_FIELDS = {
    "bullets": {"type", "items"},
    "list": {"type", "ordered", "items"},
    "heading": {"type", "text"},
    "paragraph": {"type", "text"},
    "table": {"type", "columns", "rows"},
}


def nonempty_text(value, detail):
    if not isinstance(value, str) or not value.strip():
        raise ValueError(detail)
    return value


def load_source(filename):
    source = json.loads(Path(filename).read_text(encoding="utf-8"))
    if not isinstance(source, dict) or set(source) != {"title", "blocks"}:
        raise ValueError("expected title and blocks")
    nonempty_text(source["title"], "title must be nonempty text")
    if not isinstance(source["blocks"], list):
        raise ValueError("blocks must be a list")
    blocks = [validate_block(block) for block in source["blocks"]]
    return source["title"], blocks


def validate_block(block):
    if not isinstance(block, dict) or block.get("type") not in BLOCK_FIELDS:
        raise ValueError(f"unsupported block {block.get('type') if isinstance(block, dict) else block}")
    if set(block) != BLOCK_FIELDS[block["type"]]:
        raise ValueError(f"{block['type']} block has unexpected fields")
    kind = block["type"]
    if kind in {"bullets", "list"}:
        if kind == "list" and block["ordered"] is not True:
            raise ValueError("list blocks must set ordered true")
        items = block["items"]
        if not isinstance(items, list) or any(not isinstance(item, str) or not item.strip() for item in items):
            raise ValueError(f"{kind} items must be nonempty text")
    elif kind in {"heading", "paragraph"}:
        nonempty_text(block["text"], f"{kind} text must be nonempty text")
    else:
        columns = block["columns"]
        rows = block["rows"]
        if not isinstance(columns, list) or not columns or any(not isinstance(column, str) or not column.strip() for column in columns):
            raise ValueError("table columns must be nonempty text")
        if not isinstance(rows, list):
            raise ValueError("table rows must be a list")
        for index, row in enumerate(rows, start=1):
            if not isinstance(row, list) or len(row) != len(columns):
                raise ValueError(f"row {index} has {len(row) if isinstance(row, list) else 0} cells but {len(columns)} columns")
            if any(not isinstance(cell, str) for cell in row):
                raise ValueError(f"row {index} cells must be text")
    return block


def render_docx(output, title, blocks, font):
    from docx import Document
    document = Document()
    document.add_heading(title, 0)
    expected_rows = []
    for block in blocks:
        kind = block["type"]
        if kind == "heading":
            document.add_heading(block["text"], level=2)
        elif kind == "paragraph":
            document.add_paragraph(block["text"])
        elif kind == "list":
            for item in block["items"]:
                document.add_paragraph(item, style="List Number")
        elif kind == "bullets":
            for item in block["items"]:
                document.add_paragraph(item, style="List Bullet")
        else:
            table = document.add_table(rows=1 + len(block["rows"]), cols=len(block["columns"]))
            for column, heading in enumerate(block["columns"]):
                table.rows[0].cells[column].text = heading
            for row_index, row in enumerate(block["rows"], start=1):
                for column, value in enumerate(row):
                    table.rows[row_index].cells[column].text = value
            expected_rows.append([block["columns"], *block["rows"]])
    document.save(output)
    reopened = Document(output)
    actual = [(paragraph.style.name, paragraph.text) for paragraph in reopened.paragraphs]
    if actual != expected_paragraphs(title, blocks):
        raise ValueError("DOCX read-back differs from source")
    actual_rows = [[[cell.text for cell in row.cells] for row in table.rows] for table in reopened.tables]
    if actual_rows != expected_rows:
        raise ValueError("DOCX table read-back differs from source")
    return {"paragraphs": len(actual), "tables": len(actual_rows)}


DOCX_STYLES = {"heading": "Heading 2", "paragraph": "Normal", "list": "List Number", "bullets": "List Bullet"}


def expected_paragraphs(title, blocks):
    paragraphs = [("Title", title)]
    for block in blocks:
        kind = block["type"]
        if kind in {"heading", "paragraph"}:
            paragraphs.append((DOCX_STYLES[kind], block["text"]))
        elif kind in {"list", "bullets"}:
            paragraphs.extend((DOCX_STYLES[kind], item) for item in block["items"])
    return paragraphs


def slide_lines(blocks):
    lines = []
    for block in blocks:
        kind = block["type"]
        if kind == "table":
            raise ValueError("pptx does not support table blocks; use docx, xlsx, or markdown")
        if kind == "heading":
            lines.append(block["text"])
        elif kind == "paragraph":
            lines.append(block["text"])
        else:
            lines.extend(block["items"])
    return lines


def render_pptx(output, title, blocks, font):
    from pptx import Presentation
    from pptx.util import Inches, Pt
    items = slide_lines(blocks)
    if len(title) > 80 or any(len(item) > 160 or "\n" in item for item in items):
        raise ValueError("PPTX sample needs title <=80 and single-line bullets <=160 characters; edit layout for longer text")
    deck = Presentation()
    deck.slide_width = Inches(13.333)
    deck.slide_height = Inches(7.5)
    groups = [items[index:index + 5] for index in range(0, len(items), 5)] or [[]]
    for group in groups:
        slide = deck.slides.add_slide(deck.slide_layouts[1])
        slide.shapes.title.text = title
        text = slide.placeholders[1].text_frame
        text.clear()
        for index, item in enumerate(group):
            paragraph = text.paragraphs[0] if index == 0 else text.add_paragraph()
            paragraph.text = item
            paragraph.font.size = Pt(24)
    deck.save(output)
    reopened = Presentation(output)
    actual = [paragraph.text for slide in reopened.slides for paragraph in slide.placeholders[1].text_frame.paragraphs if paragraph.text]
    if actual != items or any(slide.shapes.title.text != title for slide in reopened.slides):
        raise ValueError("PPTX read-back differs from source")
    return {"slides": len(reopened.slides)}


def render_xlsx(output, title, blocks, font):
    from openpyxl import Workbook, load_workbook
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "Notes"
    rows = sheet_rows(title, blocks)
    for row_index, row in enumerate(rows, start=1):
        for column, value in enumerate(row, start=1):
            cell = sheet.cell(row=row_index, column=column, value=value)
            cell.data_type = "s"
    sheet.column_dimensions["A"].width = 80
    sheet.freeze_panes = "A2"
    workbook.save(output)
    workbook.close()
    reopened = load_workbook(output)
    try:
        actual = [trim_row(row) for row in reopened.active.iter_rows()]
        literal = all(cell.data_type == "s" for row in reopened.active.iter_rows() for cell in row if cell.value is not None)
        if actual != [trim_values(row) for row in rows] or not literal:
            raise ValueError("XLSX read-back differs from literal source text")
        return {"rows": len(actual), "formulasEvaluated": False}
    finally:
        reopened.close()


def trim_row(row):
    return trim_values([cell.value for cell in row])


def trim_values(values):
    trimmed = list(values)
    while trimmed and trimmed[-1] is None:
        trimmed.pop()
    return trimmed


def sheet_rows(title, blocks):
    rows = [[title]]
    for block in blocks:
        kind = block["type"]
        if kind == "table":
            rows.append([])
        if kind in {"heading", "paragraph"}:
            rows.append([block["text"]])
        elif kind in {"list", "bullets"}:
            rows.extend([item] for item in block["items"])
        else:
            rows.append(list(block["columns"]))
            rows.extend(list(row) for row in block["rows"])
    return rows


def pdf_lines(blocks):
    lines = []
    for block in blocks:
        kind = block["type"]
        if kind == "table":
            raise ValueError("pdf does not support table blocks; use docx, xlsx, or markdown")
        if kind in {"heading", "paragraph"}:
            lines.append(block["text"])
        else:
            lines.extend(block["items"])
    return lines


def render_pdf(output, title, blocks, font):
    from reportlab.lib.styles import getSampleStyleSheet
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
    from pypdf import PdfReader
    items = pdf_lines(blocks)
    if font:
        pdfmetrics.registerFont(TTFont("DocumentFont", str(font)))
    elif not all(value.isascii() for value in [title, *items]):
        raise ValueError("non-ASCII PDF text requires --font with a licensed TrueType font covering those glyphs")
    styles = getSampleStyleSheet()
    if font:
        styles["Title"].fontName = "DocumentFont"
        styles["BodyText"].fontName = "DocumentFont"
    story = [Paragraph(escape(title), styles["Title"]), Spacer(1, 12)]
    for item in items:
        story.extend([Paragraph(escape(item), styles["BodyText"]), Spacer(1, 8)])
    SimpleDocTemplate(str(output)).build(story)
    with PdfReader(output) as document:
        actual = " ".join(" ".join(page.extract_text().split()) for page in document.pages)
        expected = " ".join(" ".join(value.split()) for value in [title, *items])
        if actual != expected:
            raise ValueError("PDF extracted text differs from source")
        return {"pages": len(document.pages)}


def main():
    parser = argparse.ArgumentParser(description="Generate and reopen a small editable Office or PDF document from title/bullet JSON.")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--format", required=True, choices=["docx", "pptx", "xlsx", "pdf"])
    parser.add_argument("--font", type=Path)
    args = parser.parse_args()
    temporary = None
    try:
        if args.output.suffix.lower() != f".{args.format}":
            raise ValueError("output extension must match format")
        title, blocks = load_source(args.input)
        descriptor, filename = tempfile.mkstemp(suffix=f".{args.format}", dir=args.output.parent)
        os.close(descriptor)
        temporary = Path(filename)
        renderers = {"docx": render_docx, "pptx": render_pptx, "xlsx": render_xlsx, "pdf": render_pdf}
        details = renderers[args.format](temporary, title, blocks, args.font)
        os.replace(temporary, args.output)
        print(json.dumps({"output": str(args.output), "format": args.format, "reopened": True, **details}))
        return 0
    except ImportError as error:
        print(json.dumps({"error": "missing-dependency", "module": error.name}))
        return 2
    except (ValueError, OSError, KeyError) as error:
        print(json.dumps({"error": "document-failed", "detail": str(error)}))
        return 1
    finally:
        if temporary:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    raise SystemExit(main())
