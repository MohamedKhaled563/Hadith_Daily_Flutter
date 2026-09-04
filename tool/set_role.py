"""Grant or revoke a moderator/admin role for a user.

Run from the project root, by an existing admin, using the Admin SDK
service account key:

    python tool/set_role.py someone@example.com moderator
    python tool/set_role.py someone@example.com admin
    python tool/set_role.py someone@example.com user      # revoke back to plain user

This is the "trusted environment" custom claims require (see the roadmap
doc, Phase 4/§5) — a local script rather than a callable Cloud Function, so
granting a role never requires the Blaze plan. It does two separate,
privileged things, both via the Admin SDK, both bypassing firestore.rules
entirely:

  1. Sets a custom claim on the user's Auth token — this is the one
     firestore.rules actually checks (`request.auth.token.role`).
  2. Mirrors the same role onto users/{uid} in Firestore, purely so the
     app's own UI can read a role cheaply without decoding a token.

The custom claim only takes effect on that user's NEXT sign-in, or after
their app calls `user.getIdTokenResult(forceRefresh: true)` — an
already-open session keeps using its old token until then.

Requires: pip install firebase-admin
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
SERVICE_ACCOUNT_KEY = ROOT / "secrets" / "service-account.json"

VALID_ROLES = {"user", "moderator", "admin"}


def main() -> int:
    if len(sys.argv) != 3 or sys.argv[2] not in VALID_ROLES:
        print(
            f"usage: python {Path(__file__).name} <email> <user|moderator|admin>",
            file=sys.stderr,
        )
        return 1

    email, role = sys.argv[1], sys.argv[2]

    if not SERVICE_ACCOUNT_KEY.exists():
        print(
            f"error: service account key not found at {SERVICE_ACCOUNT_KEY}",
            file=sys.stderr,
        )
        return 1

    import firebase_admin
    from firebase_admin import auth, credentials, firestore

    cred = credentials.Certificate(str(SERVICE_ACCOUNT_KEY))
    app = firebase_admin.initialize_app(cred)

    try:
        user = auth.get_user_by_email(email, app=app)
    except auth.UserNotFoundError:
        print(f"error: no user found with email {email}", file=sys.stderr)
        return 1

    # A plain "user" clears the claim rather than setting role: 'user' —
    # the rules only ever check `in ['moderator','admin']`, so having no
    # claim at all is equivalent and keeps the token smaller.
    claims = None if role == "user" else {"role": role}
    auth.set_custom_user_claims(user.uid, claims, app=app)

    db = firestore.client(app)
    db.collection("users").document(user.uid).set(
        {
            "email": user.email or "",
            "displayName": user.display_name or "",
            "role": role,
        },
        merge=True,
    )

    print(f"{email} ({user.uid}) is now: {role}")
    print("Takes effect on their next sign-in, or after their app force-refreshes its ID token.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
