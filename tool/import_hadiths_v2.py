"""Convert `assets/data/الأربعون_النووية_رسائل_يومية.xlsx`'s "الأحاديث والشروح"
sheet into `assets/data/hadiths.json` (the app's bundled offline copy) and,
with --push, into the `hadiths` Firestore collection — replacing content
previously sourced from `Hadith App DB.xlsx` by the now-retired
`import_hadith_db.py`.

The database and the bundled JSON are both meant to hold only this
workbook's data — see `import_daily_messages_v2.py` for the same decision
applied to `dailyMessages`/`insights.json`. This script therefore captures
every column the sheet has, without inventing fields the workbook doesn't
supply (no `keyLessons`/`narratorBio` — the Hadith model's own empty
defaults cover their absence). The sheet supplies who extracted/collected
the hadith (المخرج, e.g. "البخاري ومسلم") and the isnad/ananah phrase that
introduces the hadith text (عنعنة), which map to the model's
`mukhrij`/`isnad` fields, and a short explanation alongside the full one.

Run from the project root:

    python tool/import_hadiths_v2.py              # regenerates hadiths.json only
    python tool/import_hadiths_v2.py --push        # also deletes the old hadiths
                                                    # docs and writes these to Firestore

Requires: pip install openpyxl firebase-admin
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import openpyxl

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
WORKBOOK = ROOT / "assets" / "data" / "الأربعون_النووية_رسائل_يومية.xlsx"
HADITHS_OUT = ROOT / "assets" / "data" / "hadiths.json"
SERVICE_ACCOUNT_KEY = ROOT / "secrets" / "service-account.json"

SHEET_HADITHS = "الأحاديث والشروح"


def clean(value) -> str:
    if value is None:
        return ""
    text = str(value).replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[ \t]+", " ", text)
    text = em_dash(text)
    return text.strip()


def em_dash(text: str) -> str:
    """A spaced ASCII hyphen used as a parenthetical dash becomes an em dash.

    The workbook is typed on a normal keyboard, so asides come out as
    `كل عمل نقوم به - عبادة كان أو عملا دنيويا - قيمته` -- a hyphen doing a
    dash's job. It is the wrong mark: too short to read as a break, and it
    sits mid-x-height against Arabic letterforms rather than on their optical
    centre. The app's own UI copy already uses the em dash for exactly this.

    The space on *both* sides is what makes this safe to automate. It is what
    separates a dash from a hyphen that is joining something -- `e-mail`,
    `2024-01-01`, a leading `- ` bullet -- none of which are touched.
    """
    return re.sub(r"(?<=\S) - (?=\S)", " \u2014 ", text)


def load_hadiths() -> list[dict]:
    if not WORKBOOK.exists():
        print(f"error: workbook not found at {WORKBOOK}", file=sys.stderr)
        sys.exit(1)

    workbook = openpyxl.load_workbook(WORKBOOK, data_only=True)
    sheet = workbook[SHEET_HADITHS]

    hadiths = []
    for row in sheet.iter_rows(min_row=2, values_only=True):
        (
            hadith_id,
            title,
            mukhrij,
            isnad,
            text,
            full_expl,
            short_expl,
            messages_count,
        ) = row
        if hadith_id is None:
            continue

        num = int(hadith_id)
        hadiths.append(
            {
                "number": num,
                "title": clean(title),
                "mukhrij": clean(mukhrij),
                "isnad": clean(isnad),
                "text": clean(text),
                "fullExplanation": clean(full_expl),
                "shortExplanation": clean(short_expl),
                "messagesCount": int(messages_count) if messages_count is not None else 0,
                "sourceWorkbook": WORKBOOK.name,
                "order": num,
            }
        )

    return hadiths


def write_json(hadiths: list[dict]) -> None:
    """Write `assets/data/hadiths.json` in the shape `Hadith.fromJson` expects.

    `fullExplanation` becomes the JSON `explanation` field — the app's detail
    screen shows it as the main explanation card. `shortExplanation` is kept
    alongside it for the brief-summary card. `reference`/`keyLessons`/
    `narratorBio` are simply omitted; the Dart model already defaults each of
    them (a fixed reference string, an empty list, an empty string) when the
    JSON doesn't have the key, so nothing breaks by leaving them out.
    """
    records = [
        {
            "number": h["number"],
            "title": h["title"],
            "mukhrij": h["mukhrij"],
            "isnad": h["isnad"],
            "text": h["text"],
            "explanation": h["fullExplanation"],
            "shortExplanation": h["shortExplanation"],
        }
        for h in hadiths
    ]
    HADITHS_OUT.write_text(
        json.dumps(records, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def push_to_firestore(hadiths: list[dict]) -> int:
    if not SERVICE_ACCOUNT_KEY.exists():
        print(
            f"error: service account key not found at {SERVICE_ACCOUNT_KEY}",
            file=sys.stderr,
        )
        return 1

    import firebase_admin
    from firebase_admin import credentials, firestore

    cred = credentials.Certificate(str(SERVICE_ACCOUNT_KEY))
    app = firebase_admin.initialize_app(cred)
    db = firestore.client(app)

    # Delete every existing hadiths doc first, so stale fields from the old
    # workbook (reference, keyLessons, narratorBio, the old-style
    # explanation) can't linger — a merge write would only add/overwrite the
    # fields listed above, not remove ones absent from this payload.
    existing = list(db.collection("hadiths").stream())
    batch = db.batch()
    pending = 0
    for doc in existing:
        batch.delete(doc.reference)
        pending += 1
        if pending >= 400:
            batch.commit()
            batch = db.batch()
            pending = 0
    if pending:
        batch.commit()
    print(f"deleted {len(existing)} existing hadiths docs")

    batch = db.batch()
    pending = 0
    for h in hadiths:
        ref = db.collection("hadiths").document(str(h["number"]))
        batch.set(ref, h, merge=True)
        pending += 1
        if pending >= 400:
            batch.commit()
            batch = db.batch()
            pending = 0
    if pending:
        batch.commit()

    print(f"pushed {len(hadiths)} hadiths to Firestore, sourced solely from {WORKBOOK.name}")
    return 0


def main() -> int:
    hadiths = load_hadiths()

    covered = sorted(h["number"] for h in hadiths)
    print(f"hadiths found  : {len(hadiths)}  from {WORKBOOK.name}")
    print(f"number range   : {covered[0]}-{covered[-1]}")
    missing_text = [h["number"] for h in hadiths if not h["text"]]
    if missing_text:
        print(f"missing text for: {missing_text}")

    write_json(hadiths)
    print(f"wrote          : {HADITHS_OUT.relative_to(ROOT)}")

    if "--push" in sys.argv[1:]:
        print()
        return push_to_firestore(hadiths)

    print()
    print("(pass --push to also delete the old hadiths docs and write these to Firestore)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
