#!/usr/bin/env python3
"""Limpia el fondo (checker/blanco/baked-bg) de un sprite sheet ya generado.
Aplica las mismas reglas que `crop_and_normalize` de generate_sprites_v2.py
pero sobre la imagen completa, sin recortar ni reposicionar.

Uso:
    .venv/bin/python tools/clean_sheet_bg.py <ruta_png> [<ruta_png> ...]
"""
import sys
from PIL import Image


def clean(path: str) -> None:
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()

    # Sample multiple corners and edge midpoints to detect baked bg
    samples = [
        px[1, 1], px[w-2, 1], px[1, h-2], px[w-2, h-2],
        px[w//2, 1], px[w//2, h-2], px[1, h//2], px[w-2, h//2],
    ]
    baked_bg = None
    opaque_samples = [s for s in samples if s[3] > 200]
    if len(opaque_samples) >= 4:
        rs = [c[0] for c in opaque_samples]
        gs = [c[1] for c in opaque_samples]
        bs = [c[2] for c in opaque_samples]
        if max(rs) - min(rs) < 35 and max(gs) - min(gs) < 35 and max(bs) - min(bs) < 35:
            baked_bg = (sum(rs)//len(rs), sum(gs)//len(gs), sum(bs)//len(bs))

    cleared = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            avg = (r + g + b) / 3
            spread = max(r, g, b) - min(r, g, b)
            # near-white grayscale
            if avg > 235 and spread < 25:
                px[x, y] = (r, g, b, 0); cleared += 1; continue
            # checker grays
            if 150 < avg < 220 and spread < 18:
                px[x, y] = (r, g, b, 0); cleared += 1; continue
            # baked bg color
            if baked_bg:
                if (abs(r - baked_bg[0]) < 28 and
                        abs(g - baked_bg[1]) < 28 and
                        abs(b - baked_bg[2]) < 28):
                    px[x, y] = (r, g, b, 0); cleared += 1; continue

    im.save(path)
    pct = 100 * cleared / (w * h)
    bg_str = f"baked={baked_bg}" if baked_bg else "no-baked"
    print(f"✓ {path}  cleared {cleared}px ({pct:.1f}%)  {bg_str}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    for p in sys.argv[1:]:
        clean(p)
