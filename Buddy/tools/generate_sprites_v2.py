#!/usr/bin/env python3
"""Generate Buddy pet sprite sheets — option A workflow.

Per character:
1. Generate 16 individual sprites (one per pose) via Gemini Nano Banana
2. Auto-crop transparent margins of each
3. Center each in a 256x256 cell, share consistent ground baseline
4. Composite into a single 1024x1024 4×4 sprite sheet

Usage:
    .venv/bin/python tools/generate_sprites_v2.py [garfield|pikachu|mario|kuromi|all]
"""
import base64, json, os, sys, time, urllib.request, io
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "buddy-ios", "Sources", "buddy", "Resources", "Assets.xcassets")
CACHE = os.path.join(ROOT, ".sprite_cache")
os.makedirs(CACHE, exist_ok=True)

KEY = None
for line in open(os.path.join(ROOT, ".env")):
    if line.startswith("GEMINI_API_KEY="):
        KEY = line.split("=", 1)[1].strip()
assert KEY, "GEMINI_API_KEY missing"

URL = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key={KEY}"

CELL_SIZE = 256       # final cell dimensions in the sheet
COLS, ROWS = 4, 4
SHEET_W, SHEET_H = COLS * CELL_SIZE, ROWS * CELL_SIZE
MARGIN_PCT = 0.08     # space on edges (no cropping all the way to bbox)

CHARACTERS = {
    "garfield": "chubby orange tabby cat with darker orange stripes on back, white belly and paws, small black dot eyes, pink nose, side view (Garfield-inspired, original design)",
    "pikachu":  "chubby chibi yellow electric mouse, red round cheeks, lightning-shaped tail tip, brown ear tips, big black eyes (Pikachu-inspired, original design)",
    "mario":    "chibi human plumber, red cap with white M circle, brown mustache, blue overalls with yellow buttons, white gloves, brown shoes, big head proportions (Mario-inspired, original design)",
    "kuromi":   "chibi white round bunny mascot, black/purple jester cap with red devil horns, pink heart on cap forehead, devil tail (Kuromi-inspired, original design)",
    # Player human avatar (the kid you control with the joystick)
    "player":   "chibi human boy, big head proportions, brown short hair, light skin, light blue short-sleeve t-shirt, navy blue pants, white sneakers, friendly smile, big black dot eyes",
}

# 16 poses per pet character: 4 rows × 4 cols
# Row 0: idle (4 breathing variations) — character standing still, slight pose changes
# Row 1: walk side right (4-frame cycle) — character walking sideways
# Row 2: eat (4 frames with food bowl)
# Row 3: sleep (4 frames curled up)
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

# 16 poses for the player avatar (human boy)
# Row 0: idle facing front (subtle breathing variations)
# Row 1: walk side right (4-frame cycle)
# Row 2: walk facing front (4-frame, marching toward camera)
# Row 3: actions (carry pet, feed, pet, wave)
PLAYER_POSES = [
    # row 0 - idle facing front
    "standing still facing the camera, arms at sides, neutral happy expression",
    "standing still facing camera, arms at sides, head turned slightly to the right",
    "standing still facing camera, eyes half-closed (mid-blink), arms at sides",
    "standing still facing camera, big smile, slight body lean to the left",
    # row 1 - walk side right
    "walking sideways to the RIGHT, side profile view, left leg forward right leg back, arms swinging opposite",
    "walking sideways to the RIGHT, side profile view, legs together passing through center",
    "walking sideways to the RIGHT, side profile view, right leg forward left leg back, opposite arm swing",
    "walking sideways to the RIGHT, side profile view, legs together other passing position",
    # row 2 - walk facing front
    "walking toward the camera, front view, left leg forward, arms swinging slightly",
    "walking toward the camera, front view, legs together",
    "walking toward the camera, front view, right leg forward",
    "walking toward the camera, front view, legs together",
    # row 3 - actions
    "side view, bending down, holding a small food bowl with both hands, placing it on the ground",
    "side view, kneeling, one hand reaching forward as if petting a small pet",
    "front view, both arms raised holding a small pet (cat or animal) above the head, smiling",
    "front view, waving hello with right arm raised high, big smile",
]
assert len(PLAYER_POSES) == 16

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
        req = urllib.request.Request(URL, data=body, headers={"Content-Type": "application/json"})
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
    with consistent baseline (sprite's bottom edge sits at cell's bottom edge minus margin).
    """
    im = Image.open(img_path).convert("RGBA")
    px = im.load()
    w, h = im.size

    # Sample 4 corners to detect baked background (Gemini sometimes bakes checker/white)
    corner_samples = [px[1, 1], px[w-2, 1], px[1, h-2], px[w-2, h-2]]
    # Determine if a uniform background color was baked (corners similar AND opaque)
    baked_bg = None
    if all(c[3] > 200 for c in corner_samples):
        # Average them; if spread is low, treat as the background color
        rs = [c[0] for c in corner_samples]
        gs = [c[1] for c in corner_samples]
        bs = [c[2] for c in corner_samples]
        if max(rs) - min(rs) < 30 and max(gs) - min(gs) < 30 and max(bs) - min(bs) < 30:
            baked_bg = (sum(rs)//4, sum(gs)//4, sum(bs)//4)

    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            avg = (r + g + b) / 3
            spread = max(r, g, b) - min(r, g, b)
            # Rule 1: near-white grayscale → transparent
            if avg > 235 and spread < 25:
                px[x, y] = (r, g, b, 0); continue
            # Rule 2: checker-pattern medium grays (low saturation) → transparent
            if 150 < avg < 220 and spread < 18:
                px[x, y] = (r, g, b, 0); continue
            # Rule 3: matches detected baked corner background within tolerance
            if baked_bg:
                if abs(r - baked_bg[0]) < 25 and abs(g - baked_bg[1]) < 25 and abs(b - baked_bg[2]) < 25:
                    px[x, y] = (r, g, b, 0); continue

    # Find bbox of remaining non-transparent pixels
    bbox = im.getbbox()
    if bbox is None:
        return Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    cropped = im.crop(bbox)
    cw, ch = cropped.size

    # Scale to fit within target_size with margin, preserving aspect ratio
    inner = int(target_size * (1 - 2 * MARGIN_PCT))
    scale = min(inner / cw, inner / ch)
    new_w, new_h = max(1, int(cw * scale)), max(1, int(ch * scale))
    resized = cropped.resize((new_w, new_h), Image.NEAREST)

    # Place into cell, horizontally centered, baseline = cell bottom minus margin
    cell = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    margin_px = int(target_size * MARGIN_PCT)
    px_x = (target_size - new_w) // 2
    px_y = target_size - new_h - margin_px
    cell.paste(resized, (px_x, px_y), resized)
    return cell


def composite_sheet(char_id: str, raw_paths: list[str]) -> Image.Image:
    sheet = Image.new("RGBA", (SHEET_W, SHEET_H), (0, 0, 0, 0))
    for i, raw in enumerate(raw_paths):
        col, row = i % COLS, i // COLS
        cell = crop_and_normalize(raw, CELL_SIZE)
        sheet.paste(cell, (col * CELL_SIZE, row * CELL_SIZE), cell)
    return sheet


def ensure_imageset(name: str, filename: str) -> str:
    folder = os.path.join(ASSETS, f"{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    contents = {
        "images": [
            {"idiom": "universal", "filename": filename, "scale": "1x"},
            {"idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    return os.path.join(folder, filename)


def build_character(char_id: str, char_desc: str):
    print(f"\n=== {char_id} ===")
    char_cache = os.path.join(CACHE, char_id)
    os.makedirs(char_cache, exist_ok=True)
    poses = PLAYER_POSES if char_id == "player" else PET_POSES
    raw_paths = []
    for i, pose in enumerate(poses):
        out = os.path.join(char_cache, f"{i:02d}.png")
        prompt = f"{STYLE}\n\nCharacter: {char_desc}\n\nPose: {pose}\n\nGenerate ONE single sprite, 256x256, transparent PNG."
        print(f"  pose {i:02d}: {pose[:60]}…")
        if not gen_image(prompt, out):
            print(f"    ✗ FAILED")
            continue
        raw_paths.append(out)
        time.sleep(2)
    if len(raw_paths) < 16:
        print(f"  ⚠ only {len(raw_paths)}/16 sprites generated")
    sheet = composite_sheet(char_id, raw_paths)
    if char_id == "garfield":
        asset = "pet_sheet"
    elif char_id == "player":
        asset = "player_sheet"
    else:
        asset = f"pet_sheet_{char_id}"
    out = ensure_imageset(asset, f"{asset}.png")
    sheet.save(out)
    print(f"  ✓ {out} ({os.path.getsize(out)//1024} KB)")


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
