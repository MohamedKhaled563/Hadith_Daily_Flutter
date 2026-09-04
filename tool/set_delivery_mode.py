"""Set the daily-tip delivery mode — see the roadmap doc, Phase 5.

    python tool/set_delivery_mode.py random   # a uniformly random unseen pick each day
    python tool/set_delivery_mode.py manual   # walks the pool in ascending `order`

Writes settings/deliveryMode via the Admin SDK. Every device reads this once
per day when DailyTipService makes its pick — there's no push to running
apps, so a change here takes effect the next time each device's local day
rolls over, same as any other pick.

Requires: pip install firebase-admin
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
SERVICE_ACCOUNT_KEY = ROOT / "secrets" / "service-account.json"

VALID_MODES = {"manual", "random"}


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in VALID_MODES:
        print(f"usage: python {Path(__file__).name} <manual|random>", file=sys.stderr)
        return 1

    mode = sys.argv[1]

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

    db.collection("settings").document("deliveryMode").set({"mode": mode})
    print(f"delivery mode set to: {mode}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
