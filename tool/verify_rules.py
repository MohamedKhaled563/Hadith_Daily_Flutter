"""Exercises the deployed firestore.rules against real allow/deny cases.

Unlike the Admin SDK (which ignores security rules entirely), this mints a
custom token for a throwaway test uid, exchanges it for a real ID token via
the Identity Toolkit REST API, and issues raw Firestore REST calls with
that token — the same path a signed-in client goes through, so a PASS here
means the rule actually enforces what its comment in firestore.rules says.

There's no Firebase Rules Unit Testing SDK here (that's a Node package;
this project has no Node tooling) — this is the from-scratch equivalent,
kept as a plain script so it's easy to re-run after any rules change.

    python tool/verify_rules.py

Requires: pip install firebase-admin requests
"""

from __future__ import annotations

import sys
import time
import uuid
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
SERVICE_ACCOUNT_KEY = ROOT / "secrets" / "service-account.json"
PROJECT = "hadithdaily-5fc06"
API_KEY = "AIzaSyA1jc9xLvrPYS-Svye4q8zXAhAAUhPZbj0"  # web app key, public by design

import firebase_admin
import requests
from firebase_admin import auth, credentials

cred = credentials.Certificate(str(SERVICE_ACCOUNT_KEY))
app = firebase_admin.initialize_app(cred)

FIRESTORE_URL = (
    f"https://firestore.googleapis.com/v1/projects/{PROJECT}"
    "/databases/(default)/documents"
)

_passed = 0
_failed = 0


def check(label: str, got_ok: bool, want_ok: bool) -> None:
    global _passed, _failed
    ok = got_ok == want_ok
    _passed += ok
    _failed += not ok
    status = "PASS" if ok else "FAIL"
    verb = "allowed" if got_ok else "denied"
    expect = "allow" if want_ok else "deny"
    print(f"[{status}] {label} — {verb} (expected {expect})")


def id_token_for(uid: str) -> str:
    custom_token = auth.create_custom_token(uid).decode()
    resp = requests.post(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key={API_KEY}",
        json={"token": custom_token, "returnSecureToken": True},
    )
    resp.raise_for_status()
    return resp.json()["idToken"]


def rest_headers(id_token: str | None) -> dict:
    return {"Authorization": f"Bearer {id_token}"} if id_token else {}


def create_doc(collection: str, fields: dict, id_token: str | None) -> requests.Response:
    body = {"fields": _encode_fields(fields)}
    return requests.post(
        f"{FIRESTORE_URL}/{collection}", json=body, headers=rest_headers(id_token)
    )


def _encode_value(v):
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, str):
        return {"stringValue": v}
    raise TypeError(type(v))


def _encode_fields(fields: dict) -> dict:
    return {k: _encode_value(v) for k, v in fields.items()}


def main() -> int:
    uid_a = f"rules-test-a-{uuid.uuid4().hex[:8]}"
    uid_b = f"rules-test-b-{uuid.uuid4().hex[:8]}"
    token_a = id_token_for(uid_a)
    token_b = id_token_for(uid_b)

    print("== communityMessages create ==")

    # Valid pending submission by its own author — should be allowed.
    resp = create_doc(
        "communityMessages",
        {
            "authorUid": uid_a,
            "authorName": "Rules Test",
            "hadithNumber": 7,
            "message": "رسالة اختبار صالحة",
            "status": "pending",
            "likeCount": 0,
        },
        token_a,
    )
    check("valid pending create by own author", resp.status_code == 200, True)
    created_name = resp.json().get("name") if resp.status_code == 200 else None

    # Claiming someone else's uid as author — must be denied.
    resp = create_doc(
        "communityMessages",
        {
            "authorUid": uid_b,
            "authorName": "Rules Test",
            "hadithNumber": 7,
            "message": "انتحال هوية",
            "status": "pending",
            "likeCount": 0,
        },
        token_a,
    )
    check("create claiming another uid as author", resp.status_code == 200, False)

    # Creating already-approved — must be denied.
    resp = create_doc(
        "communityMessages",
        {
            "authorUid": uid_a,
            "authorName": "Rules Test",
            "hadithNumber": 7,
            "message": "محاولة تجاوز المراجعة",
            "status": "approved",
            "likeCount": 0,
        },
        token_a,
    )
    check("create pre-approved", resp.status_code == 200, False)

    # Message over the 2000-char cap — must be denied (phase 10 hardening).
    resp = create_doc(
        "communityMessages",
        {
            "authorUid": uid_a,
            "authorName": "Rules Test",
            "hadithNumber": 7,
            "message": "x" * 2001,
            "status": "pending",
            "likeCount": 0,
        },
        token_a,
    )
    check("create with oversized message (>2000 chars)", resp.status_code == 200, False)

    # hadithNumber outside 1..42 — must be denied.
    resp = create_doc(
        "communityMessages",
        {
            "authorUid": uid_a,
            "authorName": "Rules Test",
            "hadithNumber": 999,
            "message": "رقم حديث غير موجود",
            "status": "pending",
            "likeCount": 0,
        },
        token_a,
    )
    check("create with out-of-range hadithNumber", resp.status_code == 200, False)

    # Unauthenticated create — must be denied.
    resp = create_doc(
        "communityMessages",
        {
            "authorUid": uid_a,
            "authorName": "Rules Test",
            "hadithNumber": 7,
            "message": "بدون تسجيل دخول",
            "status": "pending",
            "likeCount": 0,
        },
        None,
    )
    check("create while signed out", resp.status_code == 200, False)

    if created_name:
        doc_id = created_name.rsplit("/", 1)[-1]

        print("\n== communityMessages read/update/delete ==")

        # Another signed-in user reading a still-pending message that isn't
        # theirs — must be denied (only approved/own/moderator can read).
        resp = requests.get(f"{FIRESTORE_URL}/communityMessages/{doc_id}", headers=rest_headers(token_b))
        check("read someone else's pending message", resp.status_code == 200, False)

        # The like subcollection: user B liking user A's (still pending —
        # doesn't matter, likes only checks auth+uid) message — allowed.
        resp = requests.patch(
            f"{FIRESTORE_URL}/communityMessages/{doc_id}/likes/{uid_b}",
            json={"fields": {}},
            headers=rest_headers(token_b),
        )
        check("like as the signed-in uid matching the doc id", resp.status_code == 200, True)

        # User B trying to write a like doc keyed by someone else's uid —
        # must be denied.
        resp = requests.patch(
            f"{FIRESTORE_URL}/communityMessages/{doc_id}/likes/{uid_a}",
            json={"fields": {}},
            headers=rest_headers(token_b),
        )
        check("like doc keyed by a different uid than the caller", resp.status_code == 200, False)

        # Clean up the like.
        requests.delete(
            f"{FIRESTORE_URL}/communityMessages/{doc_id}/likes/{uid_b}",
            headers=rest_headers(token_b),
        )

        # Author deletes their own still-pending submission — allowed.
        resp = requests.delete(
            f"{FIRESTORE_URL}/communityMessages/{doc_id}", headers=rest_headers(token_a)
        )
        check("author deletes own pending submission", resp.status_code == 200, True)

    print(f"\n{_passed} passed, {_failed} failed")
    return 1 if _failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
