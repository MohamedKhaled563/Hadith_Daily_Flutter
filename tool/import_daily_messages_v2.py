"""Convert `assets/data/الأربعون_النووية_رسائل_يومية.xlsx`'s "جدول الرسائل"
sheet into `assets/data/insights.json` (the app's bundled offline copy) and,
with --push, into the `dailyMessages` Firestore collection — the sole source
for that collection now (see `import_hadith_db.py`'s docstring for the
now-retired workbook this replaced).

Run from the project root:

    python tool/import_daily_messages_v2.py              # regenerates insights.json only
    python tool/import_daily_messages_v2.py --push        # also writes to Firestore

Doc ids are `{hadithNumber:02d}-{seq:02d}` (e.g. "01-00", "02-03", ...).
Idempotent: re-running overwrites the same documents rather than
duplicating them, and never touches `timesShown`/`lastShownAt`, so it's
always safe to re-run after the delivery engine (Phase 5) is live.

Requires: pip install openpyxl firebase-admin
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import openpyxl

# Windows consoles default to cp1252, which can't print the Arabic workbook
# filename in the summary below — force UTF-8 rather than requiring
# PYTHONIOENCODING=utf-8 on every invocation.
sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
WORKBOOK = ROOT / "assets" / "data" / "الأربعون_النووية_رسائل_يومية.xlsx"
INSIGHTS_OUT = ROOT / "assets" / "data" / "insights.json"
SERVICE_ACCOUNT_KEY = ROOT / "secrets" / "service-account.json"

SHEET_MESSAGES = "جدول الرسائل"


def clean(value) -> str:
    if value is None:
        return ""
    text = str(value).replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[ \t]+", " ", text)
    return text.strip()


def load_messages() -> list[dict]:
    if not WORKBOOK.exists():
        print(f"error: workbook not found at {WORKBOOK}", file=sys.stderr)
        sys.exit(1)

    workbook = openpyxl.load_workbook(WORKBOOK, data_only=True)
    sheet = workbook[SHEET_MESSAGES]

    messages = []
    seq_within_hadith: dict[int, int] = {}

    for row in sheet.iter_rows(min_row=2, values_only=True):
        message_id, hadith_id, text, length_category = row
        if hadith_id is None or not clean(text):
            continue

        num = int(hadith_id)
        seq = seq_within_hadith.get(num, 0)
        seq_within_hadith[num] = seq + 1

        messages.append(
            {
                "docId": f"{num:02d}-{seq:02d}",
                "hadithNumber": num,
                "arabic": clean(text),
                "english": "",
                "category": "",
                "themes": "",
                "keywords": "",
                "lengthCategory": clean(length_category),
                "sourceMessageId": int(message_id),
                "sourceWorkbook": WORKBOOK.name,
                "order": num * 100 + seq,
            }
        )

    return messages


def write_json(messages: list[dict]) -> None:
    """Write `assets/data/insights.json` in the shape `Insight.fromJson`
    expects — `category`/`english`/`themes`/`keywords` are left empty since
    this workbook doesn't supply them; the Dart model already defaults an
    empty `category` to "رسالة اليوم", so nothing breaks by omitting it.
    """
    records = [
        {
            "hadithNumber": m["hadithNumber"],
            "arabic": m["arabic"],
        }
        for m in messages
    ]
    INSIGHTS_OUT.write_text(
        json.dumps(records, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def push_to_firestore(messages: list[dict]) -> int:
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

    batch = db.batch()
    pending = 0

    for m in messages:
        doc_id = m.pop("docId")
        ref = db.collection("dailyMessages").document(doc_id)
        batch.set(ref, m, merge=True)
        pending += 1
        if pending >= 400:
            batch.commit()
            batch = db.batch()
            pending = 0

    if pending:
        batch.commit()

    print(f"pushed {len(messages)} daily messages to Firestore")
    return 0


def main() -> int:
    messages = load_messages()

    covered = sorted({m["hadithNumber"] for m in messages})
    print(f"messages found : {len(messages)}  from {WORKBOOK.name}")
    print(f"hadith coverage: {covered[0]}-{covered[-1]} ({len(covered)} of 42)")

    write_json(messages)
    print(f"wrote          : {INSIGHTS_OUT.relative_to(ROOT)}")

    if "--push" in sys.argv[1:]:
        print()
        return push_to_firestore(messages)

    print()
    print("(pass --push to also write these to Firestore)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
