#!/usr/bin/env python3
"""Repara sprite sheets cuyos pixeles internos fueron marcados como
transparentes por error (panzas blancas, dientes, Zs, platos).

Estrategia:
1. Detecta el "exterior" haciendo flood-fill desde los 4 bordes sobre
   pixeles transparentes.
2. Cualquier pixel transparente que NO sea exterior es un hueco interno.
3. Rellena cada hueco copiando el color del pixel opaco mas cercano
   (dilatacion iterativa en 4-vecindad).

Uso:
    .venv/bin/python tools/fill_holes.py <png> [<png> ...]
"""
import sys
from collections import deque
from PIL import Image


def repair(path: str) -> None:
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    pixels = list(im.getdata())  # flat [(r,g,b,a), ...]

    def idx(x, y):
        return y * w + x

    alpha = [p[3] for p in pixels]

    # 1. Flood-fill exterior from borders (only over alpha==0 pixels).
    exterior = bytearray(w * h)  # 0 unknown, 1 exterior
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            i = idx(x, y)
            if alpha[i] == 0 and not exterior[i]:
                exterior[i] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            i = idx(x, y)
            if alpha[i] == 0 and not exterior[i]:
                exterior[i] = 1
                q.append((x, y))

    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                ni = idx(nx, ny)
                if alpha[ni] == 0 and not exterior[ni]:
                    exterior[ni] = 1
                    q.append((nx, ny))

    # 2. Identify internal holes
    holes = [
        i for i in range(w * h)
        if alpha[i] == 0 and not exterior[i]
    ]
    if not holes:
        print(f"✓ {path}  no holes")
        return

    # 3. Iterative dilation: for each hole, look at 4 neighbors;
    # if any is opaque, take that color.
    pixels_mut = list(pixels)
    pending = set(holes)
    while pending:
        next_pending = set()
        filled_this_pass = 0
        for i in pending:
            x, y = i % w, i // w
            best = None
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h:
                    ni = idx(nx, ny)
                    if pixels_mut[ni][3] > 0 and (
                        ni not in pending
                    ):
                        best = pixels_mut[ni]
                        break
            if best is not None:
                pixels_mut[i] = (best[0], best[1], best[2], 255)
                filled_this_pass += 1
            else:
                next_pending.add(i)
        if filled_this_pass == 0:
            break  # nothing connects, leave as-is
        pending = next_pending

    im.putdata(pixels_mut)
    im.save(path)
    print(f"✓ {path}  filled {len(holes) - len(pending)}/{len(holes)} holes")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    for p in sys.argv[1:]:
        repair(p)
