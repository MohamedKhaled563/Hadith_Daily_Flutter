"""Duotone-remap the daytime watercolours into a night variant.

Keeps the painting's own drawing and a trace of its chroma, but compresses the
luminance into the app's dark range so the result is a designed night ground
rather than a dimmed day one.
"""
from PIL import Image
import numpy as np

# Highlights are crushed hard on purpose: the ground has to stay darker than
# the parchment cards that sit on it (#24362B at their lightest), or the app
# reads as cards punched into the page instead of raised off it.
STOPS = [
    (0.00, (0x0A, 0x0F, 0x0C)),
    (0.15, (0x10, 0x18, 0x13)),
    (0.40, (0x14, 0x1E, 0x18)),
    (0.65, (0x18, 0x22, 0x1B)),
    (0.85, (0x1B, 0x26, 0x1E)),
    (1.00, (0x24, 0x2F, 0x23)),
]

# How much of the original hue survives the remap.
CHROMA = 0.32


def ramp(l):
    xs = np.array([s[0] for s in STOPS])
    out = np.zeros(l.shape + (3,), dtype=np.float32)
    for c in range(3):
        ys = np.array([s[1][c] for s in STOPS], dtype=np.float32)
        out[..., c] = np.interp(l, xs, ys)
    return out


def convert(src, dst):
    im = Image.open(src).convert("RGBA")
    a = np.asarray(im).astype(np.float32)
    rgb, alpha = a[..., :3], a[..., 3:]

    lum = (0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]) / 255.0
    base = ramp(lum)

    # Re-inject the source chroma (colour minus its own luminance) at low
    # strength, so foliage still reads green and the sun still reads warm.
    chroma = rgb - lum[..., None] * 255.0
    out = np.clip(base + chroma * CHROMA, 0, 255)

    res = np.concatenate([out, alpha], axis=-1).astype(np.uint8)
    Image.fromarray(res, "RGBA").save(dst, optimize=True)
    print(f"{dst}  {im.size[0]}x{im.size[1]}")


convert("assets/images/home_background.png", "assets/images/home_background_night.png")
convert("assets/images/background_empty.png", "assets/images/background_empty_night.png")
