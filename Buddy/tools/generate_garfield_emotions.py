#!/usr/bin/env python3
"""Generate emotion sprites for Garfield (angry, sad, scared).

Output: buddy-flutter/assets/sprites/garfield_{emotion}.png (256x256 each).
Reuses the same style and crop logic from generate_sprites_flutter.py.
"""
import base64
import json
import os
import sys
import time
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "buddy-flutter", "assets", "sprites")
CACHE = os.path.join(ROOT, ".sprite_cache", "garfield_emotions")
os.makedirs(CACHE, exist_ok=True)
os.makedirs(ASSETS, exist_ok=True)

KEY = None
for line in open(os.path.join(ROOT, ".env")):
    if line.startswith("GEMINI_API_KEY="):
        KEY = line.split("=", 1)[1].strip()
assert KEY, "GEMINI_API_KEY missing in .env"

URL = (
    "https://generativelanguage.googleapis.com/v1beta/models/"
    f"gemini-2.5-flash-image:generateContent?key={KEY}"
)

CELL_SIZE = 256
MARGIN_PCT = 0.08

GARFIELD_DESC = (
    "chubby orange tabby cat with darker orange stripes on back, white belly"
    " and paws, small black dot eyes, pink nose, side view (Garfield-inspired,"
    " original design)"
)

EMOTIONS = {
    "angry": (
        "side view, eyebrows tightly furrowed, mouth open showing teeth in a"
        " grumpy snarl, body tense, fur slightly puffed up, tail flicked stiff,"
        " pupils narrow"
    ),
    "sad": (
        "side view, drooping ears, downturned mouth, tear in one eye, head"
        " tilted slightly down, body slumped, tail laid flat behind"
    ),
    "scared": (
        "side view, body crouched low, fur puffed out (afraid pose), wide round"
        " eyes with tiny pupils, ears pinned back flat, mouth slightly open,"
        " trembling, tail tucked between legs"
    ),
}

STYLE = """Pixel art, 256x256 pixels, modern clean pixel art aesthetic similar to Stardew Valley or Coromon (NOT 8-bit retro NES style). Subtle anti-aliasing on edges.
ABSOLUTE RULES:
- FULLY TRANSPARENT background (alpha=0). NO checkerboard pattern, NO gray fill, NO solid background of any color.
- NO text, NO labels, NO words, NO grid lines.
- Single character only, centered, with consistent foot/ground baseline at the bottom of the image.
- Character occupies roughly 70-80% of the canvas height with small transparent margin on all sides.
"""


def gen_image(prompt: str, out_path: str, retries: int = 4) -> bool:
    if os.path.exists(out_path) and os.path.getsize(out_path) > 1000:
        print(f"    cached")
        return True
    body = json.dumps(
        {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"responseModalities": ["IMAGE"]},
        }
    ).encode()
    for attempt in range(retries):
        req = urllib.request.Request(
            URL, data=body, headers={"Content-Type": "application/json"}
        )
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                data = json.load(r)
            for p in data["candidates"][0]["content"]["parts"]:
                if "inlineData" in p:
                    img = base64.b64decode(p["inlineData"]["data"])
                    with open(out_path, "wb") as f:
                        f.write(img)
                    return True
            print(f"    no image in response")
        except Exception as e:
            msg = str(e)[:140]
            print(f"    retry {attempt+1}/{retries}: {msg}")
            time.sleep(8 + attempt * 5)
    return False


def crop_and_normalize(img_path: str, target_size: int) -> Image.Image:
    im = Image.open(img_path).convert("RGBA")
    px = im.load()
    w, h = im.size
    corner_samples = [px[1, 1], px[w - 2, 1], px[1, h - 2], px[w - 2, h - 2]]
    baked_bg = None
    if all(c[3] > 200 for c in corner_samples):
        rs = [c[0] for c in corner_samples]
        gs = [c[1] for c in corner_samples]
        bs = [c[2] for c in corner_samples]
        if max(rs) - min(rs) < 30 and max(gs) - min(gs) < 30 and max(bs) - min(bs) < 30:
            baked_bg = (sum(rs) // 4, sum(gs) // 4, sum(bs) // 4)
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            avg = (r + g + b) / 3
            spread = max(r, g, b) - min(r, g, b)
            if avg > 235 and spread < 25:
                px[x, y] = (r, g, b, 0); continue
            if 150 < avg < 220 and spread < 18:
                px[x, y] = (r, g, b, 0); continue
            if baked_bg:
                if (
                    abs(r - baked_bg[0]) < 25
                    and abs(g - baked_bg[1]) < 25
                    and abs(b - baked_bg[2]) < 25
                ):
                    px[x, y] = (r, g, b, 0); continue
    bbox = im.getbbox()
    if bbox is None:
        return Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    cropped = im.crop(bbox)
    cw, ch = cropped.size
    inner = int(target_size * (1 - 2 * MARGIN_PCT))
    scale = min(inner / cw, inner / ch)
    new_w, new_h = max(1, int(cw * scale)), max(1, int(ch * scale))
    resized = cropped.resize((new_w, new_h), Image.NEAREST)
    cell = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    margin_px = int(target_size * MARGIN_PCT)
    px_x = (target_size - new_w) // 2
    px_y = target_size - new_h - margin_px
    cell.paste(resized, (px_x, px_y), resized)
    return cell


def build_emotion(emotion: str, pose: str):
    print(f"\n=== garfield {emotion} ===")
    raw = os.path.join(CACHE, f"{emotion}.png")
    prompt = (
        f"{STYLE}\n\nCharacter: {GARFIELD_DESC}\n\nPose: {pose}"
        "\n\nGenerate ONE single sprite, 256x256, transparent PNG."
    )
    print(f"  pose: {pose[:60]}…")
    if not gen_image(prompt, raw):
        print("  ✗ FAILED")
        return
    cell = crop_and_normalize(raw, CELL_SIZE)
    out_file = os.path.join(ASSETS, f"garfield_{emotion}.png")
    cell.save(out_file)
    print(f"  ✓ {out_file} ({os.path.getsize(out_file)//1024} KB)")


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else "all"
    if target == "all":
        for e, p in EMOTIONS.items():
            build_emotion(e, p)
            time.sleep(2)
    elif target in EMOTIONS:
        build_emotion(target, EMOTIONS[target])
    else:
        print(f"Unknown: {target}. Options: {list(EMOTIONS)} or 'all'")
        sys.exit(1)
    print("\n✓ done")


if __name__ == "__main__":
    main()
