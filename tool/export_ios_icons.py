"""Derives the whole iOS icon set from one 1024px master.

The master is produced by `flutter test test/export_ios_icons_test.dart`,
which renders design/logo-proposal/emblem_glyph.svg through flutter_svg — the
same engine the app itself draws with, and the only SVG rasteriser available
in this toolchain.

This then does what every icon pipeline does: downscale the master to each
size Contents.json asks for, and flatten to RGB. That second part matters —
App Store validation rejects an icon with an alpha channel, and a widget
render always carries one even when every pixel is opaque.

    flutter test test/export_ios_icons_test.dart   # writes the master
    python tool/export_ios_icons.py                # writes the rest
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
ICONS = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
MASTER = ICONS / "Icon-App-1024x1024@1x.png"

# Every size Contents.json asks for, as points x scale.
SIZES: dict[str, int] = {
    "Icon-App-20x20@1x": 20,
    "Icon-App-20x20@2x": 40,
    "Icon-App-20x20@3x": 60,
    "Icon-App-29x29@1x": 29,
    "Icon-App-29x29@2x": 58,
    "Icon-App-29x29@3x": 87,
    "Icon-App-40x40@1x": 40,
    "Icon-App-40x40@2x": 80,
    "Icon-App-40x40@3x": 120,
    "Icon-App-60x60@2x": 120,
    "Icon-App-60x60@3x": 180,
    "Icon-App-76x76@1x": 76,
    "Icon-App-76x76@2x": 152,
    "Icon-App-83.5x83.5@2x": 167,
    "Icon-App-1024x1024@1x": 1024,
}

# The emerald ground, for flattening any residual transparency onto.
GROUND = (0x15, 0x36, 0x2B)


def main() -> None:
    if not MASTER.exists():
        raise SystemExit(
            f"missing {MASTER.relative_to(ROOT)} — run the Flutter export first"
        )

    master = Image.open(MASTER).convert("RGBA")
    if master.size != (1024, 1024):
        raise SystemExit(f"master is {master.size}, expected 1024x1024")

    flat = Image.new("RGB", master.size, GROUND)
    flat.paste(master, (0, 0), master)

    for name, side in SIZES.items():
        out = flat if side == 1024 else flat.resize((side, side), Image.LANCZOS)
        path = ICONS / f"{name}.png"
        out.save(path, optimize=True)
        assert out.mode == "RGB", "iOS icons must not carry an alpha channel"
        print(f"{name:30s} {side}x{side}  ({path.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
