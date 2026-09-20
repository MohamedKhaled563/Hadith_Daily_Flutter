"""Re-exports the ornament PNGs from art-originals/ at the right geometry.

Two bugs this fixes, both of them invisible in the source files and obvious
once measured.

**The golden divider rendered at 45% of its intended width, everywhere.** The
shipped PNG was a 560x187 canvas (aspect 3.0) whose actual ink is only
2154x295 of the 2172x724 original (aspect 7.30) — the rest is transparent
padding. Every call site asks for a wide thin slot (120x18, aspect 6.67), and
AssetHelper contains rather than stretches, so the padded canvas was fitted
instead of the art and the flourish shrank to about 54x18. Cropping to the ink
makes the asset's own aspect match what the layout asks for.

**The emblem was 256x238, not square**, so in every 80x80 or 64x64 circular
badge it painted letterboxed and sat a few pixels above the optical centre.
Padding to a square canvas fixes that at every call site at once.

While here, each ornament is exported at roughly 3x its largest on-screen use
rather than whatever it happened to be, which also cuts the bundle: these were
being decoded at up to 320x480 to be drawn at 86x96.

    python tool/export_assets.py

Source of truth is art-originals/. Re-run after replacing any of those.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art-originals"
OUT = ROOT / "assets" / "images"

# Alpha below this is padding, not art. Anti-aliased edges sit well above it.
ALPHA_FLOOR = 8


def ink_box(im: Image.Image) -> tuple[int, int, int, int]:
    """Bounding box of everything that is actually drawn."""
    alpha = np.asarray(im.split()[3])
    ys, xs = np.where(alpha > ALPHA_FLOOR)
    if len(xs) == 0:
        return (0, 0, im.width, im.height)
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def fit_width(im: Image.Image, width: int) -> Image.Image:
    height = max(1, round(im.height * width / im.width))
    return im.resize((width, height), Image.LANCZOS)


def export_cropped(name: str, width: int) -> None:
    """Crop to the ink, then scale to `width`."""
    src = Image.open(SRC / f"{name}.png").convert("RGBA")
    cropped = src.crop(ink_box(src))
    out = fit_width(cropped, width)
    path = OUT / f"{name}.png"
    out.save(path, optimize=True)
    print(
        f"{name:22s} {src.width}x{src.height} -> {out.width}x{out.height}"
        f"  ({path.stat().st_size // 1024} KB)"
    )


def export_square(name: str, size: int) -> None:
    """Crop to the ink, then centre it on a transparent square.

    A square canvas is what makes a circular badge able to centre the art
    without every call site having to know the art's own proportions.
    """
    src = Image.open(SRC / f"{name}.png").convert("RGBA")
    cropped = src.crop(ink_box(src))

    side = max(cropped.width, cropped.height)
    scale = size / side
    art = cropped.resize(
        (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale))),
        Image.LANCZOS,
    )

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(art, ((size - art.width) // 2, (size - art.height) // 2), art)
    path = OUT / f"{name}.png"
    canvas.save(path, optimize=True)
    print(
        f"{name:22s} {src.width}x{src.height} -> {size}x{size} (art "
        f"{art.width}x{art.height})  ({path.stat().st_size // 1024} KB)"
    )


def export_webp(name: str, quality: int = 86) -> None:
    """The full-bleed backgrounds, as WebP.

    Deliberately NOT upscaled: art-originals only has these at 853x1844, so a
    larger export would be interpolation, not detail. They stay soft on a 1080p
    phone until the artwork is re-rendered at source — what changes here is
    only the payload, which WebP roughly thirds for this kind of soft
    watercolour.
    """
    for suffix in ("", "_night"):
        stem = f"{name}{suffix}"
        src_path = (SRC if not suffix else OUT) / f"{stem}.png"
        if not src_path.exists():
            continue
        im = Image.open(src_path).convert("RGB")
        path = OUT / f"{stem}.webp"
        im.save(path, "WEBP", quality=quality, method=6)
        before = src_path.stat().st_size // 1024
        after = path.stat().st_size // 1024
        print(f"{stem:22s} {im.width}x{im.height}  {before} KB -> {after} KB (webp)")


def main() -> None:
    # Widths are ~3x the largest on-screen use, so a 3x screen gets real
    # pixels without carrying art nobody sees.
    export_cropped("golden_divider", 448)   # largest use 130dp wide
    export_cropped("leaf_accent", 128)      # largest use 14dp wide
    export_cropped("botanical_top_right", 320)
    export_cropped("botanical_bottom_left", 320)
    export_square("heart_leaf_emblem", 288)  # largest use 80dp

    export_webp("home_background")
    export_webp("background_empty")


if __name__ == "__main__":
    main()
