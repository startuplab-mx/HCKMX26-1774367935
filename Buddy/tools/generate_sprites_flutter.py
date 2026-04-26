#!/usr/bin/env python3
"""Generate Buddy pet sprite sheets for the Flutter app (Android/iOS).

Output: buddy-flutter/assets/sprites/pet_sheet_{name}.png (1024×1024, 4×4 grid).
Reuses .sprite_cache/ from the iOS generator to avoid regenerating frames.

Usage:
    .venv/bin/python tools/generate_sprites_flutter.py [name|all]

Available names: cocodrilo, elefante, jirafa, mono, monocafe, rinoceronte, zorro

Cost: ~16 API calls per character (cached after first run).
"""
import base64
import io
import json
import os
import sys
import time
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "buddy-flutter", "assets", "sprites")
CACHE = os.path.join(ROOT, ".sprite_cache")
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
COLS, ROWS = 4, 4
SHEET_W, SHEET_H = COLS * CELL_SIZE, ROWS * CELL_SIZE
MARGIN_PCT = 0.08

# Descripciones específicas para cada animal del onboarding actual.
CHARACTERS = {
    "cocodrilo": (
        "chibi green crocodile, big round head, light yellow belly, short stubby"
        " legs, small triangular dorsal scales on back, big round black eyes,"
        " friendly toothy smile, cute and not scary"
    ),
    "elefante": (
        "chibi gray baby elephant, oversized round head, small floppy ears,"
        " short trunk curling up at the tip, white tusks just barely visible,"
        " stubby legs, pink cheeks, big black eyes, very cute"
    ),
    "jirafa": (
        "chibi yellow baby giraffe, oversized head, short proportioned neck"
        " (not too long, kawaii style), brown spots on body and neck, two tiny"
        " horns with brown tips, big black eyes, slightly tongue out"
    ),
    "mono": (
        "chibi yellow howler monkey, light yellow body and face, dark amber tail"
        " curling, big round eyes, small round ears, big mouth showing tiny teeth,"
        " playful expression, slightly tongue out"
    ),
    "monocafe": (
        "chibi brown spider monkey, dark chocolate brown fur, lighter beige face"
        " and belly, long curled tail, big black eyes, small round ears, friendly"
        " smile"
    ),
    "rinoceronte": (
        "chibi gray rhinoceros, oversized round head, small round ears, single"
        " short white horn on snout, stubby legs, light pink belly, big black"
        " eyes, friendly smile (not aggressive)"
    ),
    "zorro": (
        "chibi orange fox, fluffy big tail with white tip, white belly and chest,"
        " black ears tips, small white snout, big amber eyes, alert pointy ears,"
        " mischievous smile"
    ),
}

PET_POSES = [
    # row 0 - idle
    "standing still, eyes open, neutral expression, facing slightly toward viewer",
    "standing still, eyes open, body slightly leaning, looking right",
    "standing still, eyes half-closed (mid-blink), neutral pose",
    "standing still, eyes open, looking up curiously",
    # row 1 - walk side right
    "walking sideways to the RIGHT, side profile view, both legs visible, left leg forward right leg back, body slightly tilted",
    "walking sideways to the RIGHT, side profile view, legs together passing through center",
    "walking sideways to the RIGHT, side profile view, right leg forward left leg back, opposite tilt",
    "walking sideways to the RIGHT, side profile view, legs together other passing position",
    # row 2 - eat
    "side view, standing in front of a small round food bowl on the ground, looking down at the bowl",
    "side view, head bent down toward food bowl, mouth slightly open about to bite",
    "side view, head down inside food bowl, eating",
    "side view, head up after eating, satisfied happy expression, bowl visible empty below",
    # row 3 - sleep
    "side view, lying down curled up, eyes closed, body rounded",
    "side view, lying down curled up, eyes closed, with one small Z floating above",
    "side view, lying down curled up, eyes closed, with two Z floating above",
    "side view, lying down curled up, eyes closed, peaceful, with three Z floating above",
]
assert len(PET_POSES) == 16

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
    body = json.dumps({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["IMAGE"]},
    }).encode()
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
    """Auto-crop transparent margins, then place character in target_size cell
    with consistent baseline.
    """
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
                px[x, y] = (r, g, b, 0)
                continue
            if 150 < avg < 220 and spread < 18:
                px[x, y] = (r, g, b, 0)
                continue
            if baked_bg:
                if (
                    abs(r - baked_bg[0]) < 25
                    and abs(g - baked_bg[1]) < 25
                    and abs(b - baked_bg[2]) < 25
                ):
                    px[x, y] = (r, g, b, 0)
                    continue

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


def composite_sheet(raw_paths: list) -> Image.Image:
    sheet = Image.new("RGBA", (SHEET_W, SHEET_H), (0, 0, 0, 0))
    for i, raw in enumerate(raw_paths):
        col, row = i % COLS, i // COLS
        cell = crop_and_normalize(raw, CELL_SIZE)
        sheet.paste(cell, (col * CELL_SIZE, row * CELL_SIZE), cell)
    return sheet


def build_character(char_id: str, char_desc: str):
    print(f"\n=== {char_id} ===")
    char_cache = os.path.join(CACHE, char_id)
    os.makedirs(char_cache, exist_ok=True)
    raw_paths = []
    for i, pose in enumerate(PET_POSES):
        out = os.path.join(char_cache, f"{i:02d}.png")
        prompt = (
            f"{STYLE}\n\nCharacter: {char_desc}\n\nPose: {pose}"
            "\n\nGenerate ONE single sprite, 256x256, transparent PNG."
        )
        print(f"  pose {i:02d}: {pose[:60]}…")
        if not gen_image(prompt, out):
            print(f"    ✗ FAILED")
            continue
        raw_paths.append(out)
        time.sleep(2)
    if len(raw_paths) < 16:
        print(f"  ⚠ only {len(raw_paths)}/16 sprites generated")
    sheet = composite_sheet(raw_paths)
    out_file = os.path.join(ASSETS, f"pet_sheet_{char_id}.png")
    sheet.save(out_file)
    print(f"  ✓ {out_file} ({os.path.getsize(out_file)//1024} KB)")


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else "all"
    if target == "all":
        for cid, desc in CHARACTERS.items():
            build_character(cid, desc)
    elif target in CHARACTERS:
        build_character(target, CHARACTERS[target])
    else:
        print(f"Unknown char: {target}. Options: {list(CHARACTERS)} or 'all'")
        sys.exit(1)
    print("\n✓ done")


if __name__ == "__main__":
    main()
