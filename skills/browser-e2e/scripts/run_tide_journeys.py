import json
import sys
from pathlib import Path
from urllib.parse import urlsplit

try:
    from playwright.sync_api import sync_playwright
except ModuleNotFoundError as error:
    sys.stderr.write("missing dependency: Python Playwright (" + error.name + ")\n")
    sys.exit(1)

JOURNEYS = ("saves a tide reading", "refuses a blank tide time")


def run(fixture, executable, html=None, journeys=None, seed_defect=False):
    selected = list(journeys or JOURNEYS)
    results = []
    if not Path(executable).is_file():
        return {"ok": False, "journeys": [], "failures": ["missing dependency: Chromium executable was not found at " + executable]}
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path=executable, headless=True)
        try:
            page = browser.new_page()
            if seed_defect:
                page.add_init_script(
                    "document.addEventListener('submit', (event) => {"
                    " const list = document.getElementById('readings');"
                    " if (!list) return;"
                    " const item = document.createElement('li');"
                    " list.appendChild(item);"
                    "}, true);"
                )
            target = open_target(page, fixture, html)
            if target is not None:
                browser.close()
                return target
            for journey_index, name in enumerate(selected):
                if name == "saves a tide reading":
                    results.append(save_reading(page))
                elif name == "refuses a blank tide time":
                    results.append(refuse_blank(page))
                else:
                    results.append({"name": name, "ok": False, "detail": "unknown journey"})
                if journey_index + 1 < len(selected):
                    page.goto("about:blank")
                    reopened = open_target(page, fixture, html)
                    if reopened is not None:
                        results.append({"name": name, "ok": False, "detail": "fixture unavailable"})
                        break
        finally:
            browser.close()
    missing = [name for name in JOURNEYS if name not in selected]
    failures = [f"{item['name']}: {item['detail']}" for item in results if not item["ok"]]
    failures.extend(f"{name}: journey removed" for name in missing)
    return {"ok": not failures, "journeys": results, "failures": failures}



def open_target(page, fixture, html):
    if html is not None:
        page.set_content(html)
        return None
    if "://" in fixture:
        parts = urlsplit(fixture)
        if parts.scheme != "http" or parts.hostname != "127.0.0.1":
            return {"ok": False, "journeys": [], "failures": ["fixture refused: only a loopback http address is allowed"]}
        try:
            page.goto(fixture)
        except Exception as error:
            return {"ok": False, "journeys": [], "failures": [f"fixture unavailable: {error}"]}
        return None
    page.goto(Path(fixture).resolve().as_uri())
    return None


def save_reading(page):
    field = page.get_by_role("textbox", name="Tide time")
    field.focus()
    field.press_sequentially("06:12")
    page.get_by_role("button", name="Save reading").press("Enter")
    items = page.get_by_role("listitem").all_text_contents()
    empty_hidden = page.locator("#empty").is_hidden()
    ok = items == ["06:12"] and empty_hidden
    return {"name": "saves a tide reading", "ok": ok, "detail": f"items={items} emptyHidden={empty_hidden}"}


def refuse_blank(page):
    page.get_by_role("textbox", name="Tide time").focus()
    page.get_by_role("button", name="Save reading").press("Enter")
    alert = page.get_by_role("alert")
    visible = alert.is_visible()
    text = alert.text_content() if visible else ""
    items = page.get_by_role("listitem").all_text_contents()
    ok = visible and text == "Tide time is required." and items == []
    return {"name": "refuses a blank tide time", "ok": ok, "detail": f"visible={visible} text={text!r} items={items}"}


def main():
    request = json.loads(sys.stdin.read())
    report = run(request["fixture"], request["executable"], request.get("html"), request.get("journeys"), bool(request.get("seedDefect")))
    json.dump(report, sys.stdout)


if __name__ == "__main__":
    main()
