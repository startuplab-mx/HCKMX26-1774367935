#!/usr/bin/env python3
"""Generate Buddy game assets via Gemini Nano Banana API.
Reads GEMINI_API_KEY from .env in the repo root.
Outputs to buddy-ios/Sources/buddy/Resources/Assets.xcassets/<imageset>/<file>.png
"""
import base64, json, os, sys, time, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "buddy-ios", "Sources", "buddy", "Resources", "Assets.xcassets")
KEY = None
for line in open(os.path.join(ROOT, ".env")):
    if line.startswith("GEMINI_API_KEY="):
        KEY = line.split("=", 1)[1].strip()
assert KEY, "GEMINI_API_KEY missing"

URL = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key={KEY}"

STYLE = """STYLE: Modern clean pixel art (NOT 8-bit retro), aesthetic similar to Stardew Valley or Coromon.
Subtle anti-aliasing on edges. Character pixels solid, everything else FULLY TRANSPARENT alpha=0.
CRITICAL: NO checkerboard pattern, NO gray fill background. Pure transparent PNG."""

PALETTE = """COLOR PALETTE: warm cream #EFD9B0, sage green #9CB57A, orange #F0A878, dark ink #3C2C1C."""

PET_SHEET_PROMPT = """{style}
{palette}

ABSOLUTE RULES:
- NO TEXT, NO LABELS, NO WORDS, NO LETTERS anywhere in the image.
- NO grid lines, NO cell borders, NO numbering.
- Only character sprites on a fully transparent background.

Generate a pixel art SPRITE SHEET 1024x1024 pixels.
Layout: EXACTLY 4 columns × 4 rows = 16 sprite cells. Each cell exactly 256x256 pixels.
Character: {char_desc}
The SAME character in all 16 cells, only the pose changes.

Cell layout (read left-to-right, top-to-bottom):
- Cells 1-4 (top row): IDLE — character sitting/standing, 4 breathing variations, side view
- Cells 5-8 (second row): WALK CYCLE — character walking sideways to the right, 4-frame walk loop
- Cells 9-12 (third row): EAT — character with a small food bowl, 4 frames of eating
- Cells 13-16 (bottom row): SLEEP — character curled up sleeping, 4 frames

CRITICAL ALIGNMENT: Each character is centered in its 256x256 cell with consistent ground baseline.
Empty space inside each cell is fully transparent (alpha=0).
Character proportions IDENTICAL in every cell (same size, same anchor point).
NO rendering outside the character itself. NO text, NO labels, NO grid lines, NO frame borders."""

CHARACTERS = [
    ("garfield", "chubby chibi orange tabby cat with darker orange stripes on back, white belly and paws, small black dot eyes, pink nose, side view. Original design (Garfield-inspired)."),
    ("pikachu", "chubby chibi yellow electric mouse, red cheeks, lightning-shaped tail tip, brown ear tips, big black eyes. Original design."),
    ("mario",   "chibi human plumber, red cap with white M circle, brown mustache, blue overalls, white gloves, brown shoes, big head proportions. Original design."),
    ("kuromi",  "chibi white rabbit-like mascot, black/purple jester cap with red devil horns, pink heart on cap, devil tail. Original Sanrio-inspired but unique design."),
]

BG_PROMPT = """{style}
{palette}

Generate a single seamless pixel art background, side-view 2D scene (NOT isometric).
Composition (1760x2432 portrait):
- Top 70%: {wall_color} colored wall with subtle pixel texture
- Bottom 30%: floor with horizontal pattern lines
- {scene_desc}

Atmosphere: cozy, empty room ready for a character to live in. NO characters, NO pets.
Single image PNG, no transparency needed."""

SCENES = [
    ("background_bedroom",
     "purple-blue night",
     "Centered: a cozy small bed with quilted blanket and fluffy pillow. To the left: a small nightstand with a glowing lamp. Window above the bed shows a starry night sky and a crescent moon. Floor is light wood. Add a small rug under the bed. Warm tones."),
    ("background_garden",
     "bright sky blue",
     "Outdoor scene. Centered: a wooden bench. Around it: pixel grass, several colorful flowers (red, yellow, pink), a small bush. Background: a tall tree on the left, a wooden fence in the back, a couple of butterflies. Bright sunny atmosphere."),
    ("background_kitchen",
     "warm yellow-cream",
     "Centered: a wooden kitchen counter with a small stove and a bowl of fruits on top. Right side: a fridge with a magnet. Left side: a window with a potted plant on the sill, sunlight streaming through. Floor: checkered tile pattern."),
    ("background_beach",
     "bright cyan sky",
     "Outdoor beach scene. Bottom 50%: golden sandy beach. Above: light cyan ocean horizon with small wave pixels. Centered: a colorful beach umbrella with a striped pattern. Right: a single tall palm tree. Left: a beach ball half-buried in sand. A few seagulls in the distance."),
]

# Wide landscape backgrounds for scrolling room (aspect ratio ~3:1)
WIDE_BG_PROMPT = """{style}
{palette}

Generate a WIDE LANDSCAPE pixel art background, aspect ratio 3:1 (very wide, like a side-scrolling video game level).
The image must seamlessly tile for a scrolling 2D side-view scene (NOT isometric).

Composition (extends across the full wide canvas, ~1500x500 pixels):
- Top 60%: {wall_color} colored wall/sky with subtle texture
- Bottom 40%: walkable floor area with horizontal pattern lines
- {scene_desc}

Make the scene feel SPACIOUS and EXTENDED — multiple furniture items spread across the width, varied details from left to right (different objects, decorations, posters, plants on different sides).
Camera viewpoint: side-view at human height, eye-level perspective.

Atmosphere: cozy, empty room ready for characters to walk around in. NO characters, NO pets.
Output: single PNG, NO transparency needed, fills the entire wide canvas."""

WIDE_SCENES = [
    ("background_living_room_wide",
     "warm cream",
     "Multiple cozy living room furniture spread horizontally: a long orange sofa on the left with green cushions, a small coffee table in the middle with a magazine on it, a TV stand with flat-screen TV on the right, two framed pictures on the wall (one with a cat photo, one with daisies), a tall potted plant in the corner, a window in the center showing daylight sky and city silhouette. Wood floor with horizontal plank lines."),
    ("background_bedroom_wide",
     "purple-blue night",
     "Spacious bedroom: a bed in the center with quilted blanket and pillow, a nightstand with glowing warm lamp on the left, a wooden dresser on the right with a small toy on top, a large window showing a starry night sky with crescent moon and a few stars above the bed, a soft rug on the floor, hanging picture frame on the wall. Wooden floor."),
    ("background_garden_wide",
     "bright sky blue",
     "Sunny outdoor garden: green grass field with horizontal lines, a wooden bench in the center, two colorful flower beds (one on each side) with red yellow and pink flowers, a tall apple tree on the left with red fruits, a small bush on the right, a wooden picket fence across the back, two butterflies in the air, a few clouds in the bright blue sky."),
    ("background_kitchen_wide",
     "warm yellow-cream",
     "Spacious kitchen: a long wooden counter spans the bottom with a stove on the left, a bowl of fruits in the center, a fridge with magnets on the right; a window above the counter on the left showing daylight with a potted plant on the sill; cabinets and shelves on the wall with cooking pots and jars; checkered tile floor."),
    ("background_beach_wide",
     "bright cyan sky",
     "Wide beach scene: bottom 50% golden sandy beach with footprints; above, light cyan ocean horizon with wave pixels; on the left a colorful striped beach umbrella with a beach ball half-buried in sand; in the center a sandcastle with a tiny flag; on the right a tall palm tree with coconuts; several seagulls flying in the distance; a small boat on the horizon."),
]


def generate(prompt: str, out_path: str, retries: int = 3) -> bool:
    body = json.dumps({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"responseModalities": ["IMAGE"]},
    }).encode()
    req = urllib.request.Request(URL, data=body, headers={"Content-Type": "application/json"})
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                data = json.load(r)
            parts = data["candidates"][0]["content"]["parts"]
            for p in parts:
                if "inlineData" in p:
                    img = base64.b64decode(p["inlineData"]["data"])
                    os.makedirs(os.path.dirname(out_path), exist_ok=True)
                    with open(out_path, "wb") as f:
                        f.write(img)
                    print(f"  ✓ {out_path} ({len(img)//1024} KB)")
                    return True
            print(f"  ⚠ no image in response: {[list(p.keys()) for p in parts]}")
        except urllib.error.HTTPError as e:
            err = e.read().decode()[:300]
            print(f"  ⚠ attempt {attempt+1}/{retries}: HTTP {e.code} — {err}")
            time.sleep(15)
        except Exception as e:
            print(f"  ⚠ attempt {attempt+1}/{retries}: {e}")
            time.sleep(15)
    return False


def ensure_imageset(name: str, filename: str):
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


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else "all"

    if target in ("all", "pets"):
        print("\n=== PET SPRITE SHEETS ===")
        for cid, desc in CHARACTERS:
            # garfield uses asset name "pet_sheet" (legacy), others "pet_sheet_<id>"
            asset = "pet_sheet" if cid == "garfield" else f"pet_sheet_{cid}"
            print(f"\n{cid} → {asset}…")
            png = ensure_imageset(asset, f"{asset}.png")
            prompt = PET_SHEET_PROMPT.format(style=STYLE, palette=PALETTE, char_desc=desc)
            generate(prompt, png)
            time.sleep(3)  # gentle pacing
    if target == "garfield":
        cid, desc = CHARACTERS[0]
        png = ensure_imageset("pet_sheet", "pet_sheet.png")
        prompt = PET_SHEET_PROMPT.format(style=STYLE, palette=PALETTE, char_desc=desc)
        generate(prompt, png)

    if target in ("all", "scenes"):
        print("\n=== BACKGROUNDS ===")
        for asset, wall, desc in SCENES:
            print(f"\n{asset}…")
            png = ensure_imageset(asset, f"{asset}.png")
            prompt = BG_PROMPT.format(style=STYLE, palette=PALETTE, wall_color=wall, scene_desc=desc)
            generate(prompt, png)
            time.sleep(3)

    if target in ("all", "wide", "scenes-wide"):
        print("\n=== WIDE BACKGROUNDS (3:1 for scrolling) ===")
        for asset, wall, desc in WIDE_SCENES:
            print(f"\n{asset}…")
            png = ensure_imageset(asset, f"{asset}.png")
            prompt = WIDE_BG_PROMPT.format(style=STYLE, palette=PALETTE, wall_color=wall, scene_desc=desc)
            generate(prompt, png)
            time.sleep(3)

    print("\n✓ done")


if __name__ == "__main__":
    main()
