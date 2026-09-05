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
import google.auth
import google.auth.transport.requests
import requests
from firebase_admin import auth, credentials

cred = credentials.Certificate(str(SERVICE_ACCOUNT_KEY))
app = firebase_admin.initialize_app(cred)

FIRESTORE_URL = (
    f"https://firestore.googleapis.com/v1/projects/{PROJECT}"
    "/databases/(default)/documents"
)

# Admin/bootstrap writes below go over plain REST with the service account's
# own OAuth token rather than the google-cloud-firestore (gRPC) client:
# service-account-authenticated requests bypass security rules the same way
# regardless of transport, and some sandboxes only allow outbound HTTPS, not
# raw gRPC — REST keeps this script portable to those.
_admin_creds, _ = google.auth.load_credentials_from_file(
    str(SERVICE_ACCOUNT_KEY),
    scopes=["https://www.googleapis.com/auth/cloud-platform"],
)
_admin_creds.refresh(google.auth.transport.requests.Request())


def admin_headers() -> dict:
    return {"Authorization": f"Bearer {_admin_creds.token}"}


def admin_set(collection: str, doc_id: str, fields: dict) -> None:
    requests.patch(
        f"{FIRESTORE_URL}/{collection}/{doc_id}",
        json={"fields": _encode_fields(fields)},
        headers=admin_headers(),
    ).raise_for_status()


def admin_update(collection: str, doc_id: str, fields: dict) -> None:
    mask = "&".join(f"updateMask.fieldPaths={k}" for k in fields)
    requests.patch(
        f"{FIRESTORE_URL}/{collection}/{doc_id}?{mask}",
        json={"fields": _encode_fields(fields)},
        headers=admin_headers(),
    ).raise_for_status()


def admin_delete(collection: str, doc_id: str) -> None:
    requests.delete(f"{FIRESTORE_URL}/{collection}/{doc_id}", headers=admin_headers())

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
    uid_admin = f"rules-test-admin-{uuid.uuid4().hex[:8]}"

    # roleOf() in firestore.rules (phase 11) does get(users/{uid}) for the
    # caller's own role — in the real app every signed-in user always has
    # that doc (AuthService._ensureUserDoc creates it at sign-in), so these
    # throwaway test accounts need the same bootstrap or every isModerator()/
    # isAdmin() check below would hit a missing document instead of a real
    # allow/deny decision.
    admin_set("users", uid_a, {"email": "a@test", "role": "user"})
    admin_set("users", uid_b, {"email": "b@test", "role": "user"})
    admin_set("users", uid_admin, {"email": "admin@test", "role": "admin"})

    token_a = id_token_for(uid_a)
    token_b = id_token_for(uid_b)
    token_admin = id_token_for(uid_admin)

    print("== users/{uid} role management (phase 11) ==")

    # An admin promoting someone else to moderator — allowed.
    resp = requests.patch(
        f"{FIRESTORE_URL}/users/{uid_b}?updateMask.fieldPaths=role",
        json={"fields": _encode_fields({"role": "moderator"})},
        headers=rest_headers(token_admin),
    )
    check("admin promotes another user to moderator", resp.status_code == 200, True)
    # Put it back so later checks start from a known 'user' state.
    admin_update("users", uid_b, {"role": "user"})

    # A plain (non-admin) user trying to promote someone else — denied.
    resp = requests.patch(
        f"{FIRESTORE_URL}/users/{uid_b}?updateMask.fieldPaths=role",
        json={"fields": _encode_fields({"role": "admin"})},
        headers=rest_headers(token_a),
    )
    check("non-admin tries to promote another user", resp.status_code == 200, False)

    # A moderator (not admin) trying to promote someone else — denied;
    # only isAdmin() may change role, isModerator() isn't enough.
    admin_update("users", uid_a, {"role": "moderator"})
    resp = requests.patch(
        f"{FIRESTORE_URL}/users/{uid_b}?updateMask.fieldPaths=role",
        json={"fields": _encode_fields({"role": "admin"})},
        headers=rest_headers(token_a),
    )
    check("moderator (non-admin) tries to promote another user", resp.status_code == 200, False)
    admin_update("users", uid_a, {"role": "user"})

    # An admin trying to change their OWN role — denied (self-demotion
    # lockout guard: uid != request.auth.uid in the rule).
    resp = requests.patch(
        f"{FIRESTORE_URL}/users/{uid_admin}?updateMask.fieldPaths=role",
        json={"fields": _encode_fields({"role": "user"})},
        headers=rest_headers(token_admin),
    )
    check("admin tries to change their own role", resp.status_code == 200, False)

    # A user renaming themselves — still allowed (unrelated to role).
    resp = requests.patch(
        f"{FIRESTORE_URL}/users/{uid_a}?updateMask.fieldPaths=displayName",
        json={"fields": _encode_fields({"displayName": "Renamed"})},
        headers=rest_headers(token_a),
    )
    check("user renames themselves", resp.status_code == 200, True)

    print("\n== usernames (phase 13) ==")

    # Signed-out client checking availability of an unclaimed name — allowed
    # (this is the whole point: the sign-up screen has no account yet).
    resp = requests.get(f"{FIRESTORE_URL}/usernames/ahmed-test", headers=rest_headers(None))
    check("signed-out user reads an unclaimed name", resp.status_code == 200, False)
    # A 404 from Firestore's GET is still an "allowed read of a missing doc"
    # rather than a permission error — confirm that's actually why it failed.
    if resp.status_code != 200:
        check("...and it's a 404 (missing), not permission-denied", resp.status_code == 404, True)

    # User A claims a name for themselves — allowed.
    resp = requests.patch(
        f"{FIRESTORE_URL}/usernames/ahmed-test",
        json={"fields": _encode_fields({"uid": uid_a})},
        headers=rest_headers(token_a),
    )
    check("user claims a username for their own uid", resp.status_code == 200, True)

    # Signed-out client can now see the name is taken.
    resp = requests.get(f"{FIRESTORE_URL}/usernames/ahmed-test", headers=rest_headers(None))
    check("signed-out user reads a claimed name", resp.status_code == 200, True)

    # User B tries to claim the same name — must be denied (already exists,
    # and update is blocked outright).
    resp = requests.patch(
        f"{FIRESTORE_URL}/usernames/ahmed-test",
        json={"fields": _encode_fields({"uid": uid_b})},
        headers=rest_headers(token_b),
    )
    check("second user claims an already-taken username", resp.status_code == 200, False)

    # User B claims someone else's uid on a fresh name — must be denied.
    resp = requests.patch(
        f"{FIRESTORE_URL}/usernames/impersonated-test",
        json={"fields": _encode_fields({"uid": uid_a})},
        headers=rest_headers(token_b),
    )
    check("claim a fresh username with someone else's uid", resp.status_code == 200, False)

    # Unauthenticated claim attempt — must be denied.
    resp = requests.patch(
        f"{FIRESTORE_URL}/usernames/anon-test",
        json={"fields": _encode_fields({"uid": uid_a})},
        headers=rest_headers(None),
    )
    check("claim a username while signed out", resp.status_code == 200, False)

    # Rules block update/delete outright (even for an admin) — clean up
    # through the service account's own admin access, which bypasses rules
    # entirely, so a re-run doesn't find these names already claimed.
    for name in ("ahmed-test", "impersonated-test", "anon-test"):
        admin_delete("usernames", name)

    print("\n== notificationMessages (phase 12) ==")

    # A moderator/admin creating a valid notification message — allowed.
    resp = create_doc(
        "notificationMessages",
        {"text": "رسالة تنبيه قصيرة", "order": 0, "active": True},
        token_admin,
    )
    check("moderator/admin creates a notification message", resp.status_code == 200, True)
    notif_doc_name = resp.json().get("name") if resp.status_code == 200 else None

    # A plain user creating one — denied.
    resp = create_doc(
        "notificationMessages",
        {"text": "محاولة غير مصرح بها", "order": 1, "active": True},
        token_a,
    )
    check("plain user creates a notification message", resp.status_code == 200, False)

    # Oversized text (phase 12 hardening) — denied.
    resp = create_doc(
        "notificationMessages",
        {"text": "x" * 301, "order": 2, "active": True},
        token_admin,
    )
    check("notification message text over 300 chars", resp.status_code == 200, False)

    # Any signed-in user can read the pool — every device needs it to
    # schedule its own notifications.
    if notif_doc_name:
        notif_doc_id = notif_doc_name.rsplit("/", 1)[-1]
        resp = requests.get(
            f"{FIRESTORE_URL}/notificationMessages/{notif_doc_id}",
            headers=rest_headers(token_a),
        )
        check("signed-in user reads a notification message", resp.status_code == 200, True)

        resp = requests.delete(
            f"{FIRESTORE_URL}/notificationMessages/{notif_doc_id}",
            headers=rest_headers(token_admin),
        )
        check("moderator/admin deletes a notification message", resp.status_code == 200, True)

    # Signed-out read — denied.
    resp = requests.get(f"{FIRESTORE_URL}/notificationMessages", headers=rest_headers(None))
    check("signed-out user lists notification messages", resp.status_code == 200, False)

    print("\n== communityMessages create ==")

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

    for uid in (uid_a, uid_b, uid_admin):
        admin_delete("users", uid)
        try:
            auth.delete_user(uid)
        except auth.UserNotFoundError:
            pass

    print(f"\n{_passed} passed, {_failed} failed")
    return 1 if _failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
