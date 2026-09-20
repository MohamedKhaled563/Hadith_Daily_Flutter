"""Exports the in-app privacy policy and terms to standalone HTML.

Play Console wants a privacy-policy *URL* for the store listing, not just an
in-app screen, so the same words have to exist in two places. Rather than keep
two copies in sync by hand, this reads the single source —
`lib/core/legal/legal_documents.dart` — and writes `docs/*.html`.

    python tool/export_legal_docs.py

Host `docs/` anywhere static (GitHub Pages, Firebase Hosting on its own site)
and paste the URLs into Play Console and App Store Connect. Re-run after any
edit to the Dart file; the check at the bottom of this script will tell you if
they have drifted.
"""

from __future__ import annotations

import html
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "lib" / "core" / "legal" / "legal_documents.dart"
OUT_DIR = ROOT / "docs"

TEMPLATE = """<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — طيّب قلبك</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet"
      href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700&display=swap">
<style>
  :root {{
    --bg: #F8F3EA;
    --card: #F2ECE0;
    --ink: #243329;
    --muted: #4A5D52;
    --gold: #7A5B0E;
    --line: #D6BE88;
  }}
  @media (prefers-color-scheme: dark) {{
    :root {{
      --bg: #131A15;
      --card: #1C2620;
      --ink: #F7F5EE;
      --muted: #B5C0B8;
      --gold: #D9B44A;
      --line: #3A4A3F;
    }}
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0;
    background: var(--bg);
    color: var(--ink);
    font-family: Tajawal, "Segoe UI", system-ui, sans-serif;
    font-size: 16px;
    line-height: 1.75;
  }}
  .wrap {{
    max-width: 720px;
    margin: 0 auto;
    padding-inline: 20px;
    padding-block: 48px 72px;
  }}
  header {{
    border-bottom: 2px solid var(--line);
    padding-bottom: 18px;
    margin-bottom: 8px;
  }}
  h1 {{ font-size: 30px; font-weight: 700; margin: 0 0 6px; }}
  .updated {{ color: var(--gold); font-weight: 500; font-size: 14px; }}
  .doc {{
    background: var(--card);
    border: 1px solid var(--line);
    border-radius: 20px;
    padding: 26px 24px;
    margin-top: 26px;
  }}
  h2 {{
    font-size: 18px;
    font-weight: 700;
    color: var(--gold);
    margin: 28px 0 10px;
  }}
  .doc > h2:first-child {{ margin-top: 0; }}
  p {{ margin: 0 0 14px; }}
  ul {{ margin: 0 0 14px; padding-inline-start: 22px; }}
  li {{ margin-bottom: 6px; }}
  footer {{
    margin-top: 28px;
    color: var(--muted);
    font-size: 13.5px;
    text-align: center;
  }}
  a {{ color: var(--gold); }}
</style>
</head>
<body>
<div class="wrap">
  <header>
    <h1>{title}</h1>
    <div class="updated">آخر تحديث: {updated}</div>
  </header>
  <main class="doc">
{body}
  </main>
  <footer>تطبيق «طيّب قلبك» — أحاديث نبوية وهدايات قلبية</footer>
</div>
</body>
</html>
"""


def dart_const(name: str, source: str) -> str:
    """Pulls a `static const name = '''...''';` block out of the Dart file."""
    match = re.search(
        r"static const %s = '''(.*?)''';" % re.escape(name), source, re.S
    )
    if not match:
        raise SystemExit(f"could not find `{name}` in {SOURCE.name}")
    return match.group(1).strip()


def dart_string(name: str, source: str) -> str:
    match = re.search(
        r"static const %s = '([^']*)';" % re.escape(name), source
    )
    if not match:
        raise SystemExit(f"could not find `{name}` in {SOURCE.name}")
    return match.group(1)


def inline(text: str) -> str:
    """Escapes, then turns **bold** into <strong>."""
    escaped = html.escape(text)
    return re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", escaped)


def to_html(body: str) -> str:
    """Same tiny grammar the in-app renderer understands: `## ` headings,
    `• ` bullet blocks, blank-line-separated paragraphs."""
    out: list[str] = []
    for raw in body.split("\n\n"):
        block = raw.strip()
        if not block:
            continue
        if block.startswith("## "):
            out.append(f"    <h2>{inline(block[3:].strip())}</h2>")
        elif block.startswith("• "):
            items = [
                line.strip()[2:].strip()
                for line in block.split("\n")
                if line.strip()
            ]
            lis = "\n".join(f"      <li>{inline(i)}</li>" for i in items)
            out.append(f"    <ul>\n{lis}\n    </ul>")
        else:
            out.append(f"    <p>{inline(block)}</p>")
    return "\n".join(out)


def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    updated = dart_string("lastUpdated", source)

    OUT_DIR.mkdir(exist_ok=True)
    for const, title_const, filename in (
        ("privacy", "privacyTitle", "privacy-policy.html"),
        ("terms", "termsTitle", "terms-of-use.html"),
    ):
        page = TEMPLATE.format(
            title=dart_string(title_const, source),
            updated=updated,
            body=to_html(dart_const(const, source)),
        )
        path = OUT_DIR / filename
        path.write_text(page, encoding="utf-8", newline="\n")
        print(f"wrote {path.relative_to(ROOT)}  ({len(page) // 1024} KB)")


if __name__ == "__main__":
    main()
