"""Grant or revoke a moderator/admin role for a user.

Run from the project root, using the Admin SDK service account key:

    python tool/set_role.py someone@example.com moderator
    python tool/set_role.py someone@example.com admin
    python tool/set_role.py someone@example.com user      # revoke back to plain user

Since phase 11, this script exists only to bootstrap the very first admin
(and as a terminal fallback) — day to day, an existing admin can grant
moderator/admin from the dashboard's "المستخدمون" tab instead, because
firestore.rules now reads `users/{uid}.role` directly rather than a custom
claim: it's an ordinary Firestore write an admin can make with the regular
client SDK, no Admin SDK or Cloud Function needed. That's also why this
takes effect immediately rather than waiting for the user's next sign-in —
every rule evaluation reads the live Firestore doc, not a cached token.

Still sets the legacy custom claim alongside the Firestore field (harmless,
and free in case anything ever wants to read it), but nothing in this
project's rules checks that claim anymore.

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
    print("Takes effect immediately — firestore.rules reads this live from Firestore.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
