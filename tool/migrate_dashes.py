"""Applies the importers' em-dash rule to content that is already published.

The rule now lives in `clean()` in both importers, so anything imported from
the workbook from here on is correct. This is the one-off pass for what is
already in `assets/data/*.json` and in Firestore.

    python migrate_dashes.py            # report only, changes nothing
    python migrate_dashes.py --apply    # writes JSON and Firestore

Deliberately reports before it writes: this edits the author's own words, and
a regex that turns out to be wrong about one of them should be seen first.
"""

from __future__ import annotations

import json
import pathlib
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")

APPLY = "--apply" in sys.argv
SKIP_REMOTE = "--json-only" in sys.argv
ROOT = pathlib.Path(__file__).resolve()
PROJECT = pathlib.Path.cwd()

DASH = re.compile(r"(?<=\S) - (?=\S)")
EM = " — "

# Fields that carry prose. `id`, `sourceCollection`, numbers and the like are
# never rewritten, so a hyphen inside an identifier is out of reach by
# construction rather than by luck.
PROSE_FIELDS = {
    "text",
    "isnad",
    "title",
    "explanation",
    "fullExplanation",
    "shortExplanation",
    "narratorBio",
    "keyLessons",
    "arabic",
    "english",
    "message",
}


def fix(node, field: str | None = None):
    """Returns (new_node, count)."""
    if isinstance(node, dict):
        out, n = {}, 0
        for k, v in node.items():
            out[k], c = fix(v, k)
            n += c
        return out, n
    if isinstance(node, list):
        out, n = [], 0
        for v in node:
            nv, c = fix(v, field)
            out.append(nv)
            n += c
        return out, n
    if isinstance(node, str) and field in PROSE_FIELDS:
        c = len(DASH.findall(node))
        return (DASH.sub(EM, node), c) if c else (node, 0)
    return node, 0


def main() -> None:
    total = 0

    for name in ("hadiths.json", "insights.json"):
        path = PROJECT / "assets" / "data" / name
        data = json.loads(path.read_text(encoding="utf-8"))
        fixed, n = fix(data)
        total += n
        print(f"{name}: {n} dash(es)")
        if n and APPLY:
            path.write_text(
                json.dumps(fixed, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
                newline="\n",
            )
            print(f"  wrote {path.relative_to(PROJECT)}")

    # ---- Firestore -------------------------------------------------------
    if SKIP_REMOTE:
        print("\n(skipping Firestore)")
        return
    import google.auth
    import google.auth.transport.requests
    import requests

    creds, _ = google.auth.load_credentials_from_file(
        str(PROJECT / "secrets" / "service-account.json"),
        scopes=["https://www.googleapis.com/auth/cloud-platform"],
    )
    creds.refresh(google.auth.transport.requests.Request())
    headers = {"Authorization": f"Bearer {creds.token}"}
    base = (
        "https://firestore.googleapis.com/v1/projects/hadithdaily-5fc06"
        "/databases/(default)/documents"
    )

    backup: dict[str, dict[str, str]] = {}

    for collection in ("dailyMessages", "hadiths"):
        docs, token, touched = [], None, 0
        while True:
            params = {"pageSize": 300}
            if token:
                params["pageToken"] = token
            resp = requests.get(f"{base}/{collection}", headers=headers, params=params)
            if resp.status_code != 200:
                print(f"{collection}: HTTP {resp.status_code} — skipped")
                break
            body = resp.json()
            docs.extend(body.get("documents", []))
            token = body.get("nextPageToken")
            if not token:
                break

        for doc in docs:
            updates = {}
            for field, value in doc.get("fields", {}).items():
                if field not in PROSE_FIELDS or "stringValue" not in value:
                    continue
                text = value["stringValue"]
                n = len(DASH.findall(text))
                if n:
                    updates[field] = DASH.sub(EM, text)
                    touched += n
            if updates:
                name = doc["name"].split("/documents/")[1]
                # The pre-change values, so this is undoable without
                # re-running the whole workbook import.
                backup[name] = {
                    f: doc["fields"][f]["stringValue"] for f in updates
                }
            if updates and APPLY:
                name = doc["name"].split("/documents/")[1]
                mask = "&".join(f"updateMask.fieldPaths={f}" for f in updates)
                requests.patch(
                    f"{base}/{name}?{mask}",
                    json={
                        "fields": {
                            k: {"stringValue": v} for k, v in updates.items()
                        }
                    },
                    headers=headers,
                ).raise_for_status()

        total += touched
        print(f"{collection}: {len(docs)} doc(s), {touched} dash(es)")

    if backup:
        out = pathlib.Path(__file__).with_name("dash-migration-backup.json")
        out.write_text(
            json.dumps(backup, ensure_ascii=False, indent=2),
            encoding="utf-8",
            newline="\n",
        )
        print(f"\npre-change values for {len(backup)} doc(s) -> {out.name}")

    print(f"\n{total} total" + ("" if APPLY else " — dry run, nothing written"))


if __name__ == "__main__":
    main()
