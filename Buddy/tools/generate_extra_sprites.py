#!/usr/bin/env python3
"""Genera 4 poses adicionales (bath, caress, play, happy) para Garfield
y las anexa al sheet existente, produciendo un sheet 4×8 (1024×2048).

Pipeline:
1. Genera 16 imagenes individuales (4 poses × 4 frames) via Gemini Nano Banana.
2. Reusa crop_and_normalize de generate_sprites_v2.
3. Compone una extension 4×4 (1024×1024) con las 4 nuevas filas.
4. Carga el sheet existente y stack-eo vertical -> 1024×2048.
5. Aplica fill_holes para reparar huecos internos.

Uso:
    .venv/bin/python tools/generate_extra_sprites.py garfield
    .venv/bin/python tools/generate_extra_sprites.py pikachu mario kuromi
"""
import os
import sys
import time
import importlib.util

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools")
ASSETS = os.path.join(ROOT, "buddy-flutter", "assets", "sprites")
CACHE = os.path.join(ROOT, ".sprite_cache")
os.makedirs(CACHE, exist_ok=True)

# Reuse generation/crop helpers from v2
spec = importlib.util.spec_from_file_location(
    "v2", os.path.join(TOOLS, "generate_sprites_v2.py")
)
v2 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v2)
spec_holes = importlib.util.spec_from_file_location(
    "fh", os.path.join(TOOLS, "fill_holes.py")
)
fh = importlib.util.module_from_spec(spec_holes)
spec_holes.loader.exec_module(fh)

CELL = v2.CELL_SIZE  # 256
COLS = v2.COLS  # 4
EXT_ROWS = 4  # bath, caress, play, happy
SHEET_W = COLS * CELL
EXT_H = EXT_ROWS * CELL

CHARACTERS = {
    "garfield": "chubby orange tabby cat with darker orange stripes on back, white belly and paws, small black dot eyes, pink nose (Garfield-inspired, original design)",
    "pikachu":  "chubby chibi yellow electric mouse, red round cheeks, lightning-shaped tail tip, brown ear tips, big black eyes (Pikachu-inspired, original design)",
    "mario":    "chibi human plumber, red cap with white M circle, brown mustache, blue overalls with yellow buttons, white gloves, brown shoes (Mario-inspired, original design)",
    "kuromi":   "chibi white round bunny mascot, black/purple jester cap with red devil horns, pink heart on cap forehead, devil tail (Kuromi-inspired, original design)",
}

# Row 4: BATH — character bathing in a small wooden tub with bubbles
# Row 5: CARESS — receiving affection (eyes closed bliss, blushing, content)
# Row 6: PLAY — playing with a small red ball
# Row 7: HAPPY/DANCE — celebrating, jumping, dancing
EXTRA_POSES = [
    # row 4 - bath
    "sitting inside a small wooden bath tub, soapy water up to chest, white foam bubbles floating around, holding a yellow sponge with one paw, side view, eyes open content",
    "inside the same wooden bath tub, scrubbing back with sponge, head turned slightly, eyes closed in enjoyment, bubbles around",
    "inside the wooden bath tub, splashing water with one paw, water droplets flying outward, mouth open in happy smile",
    "inside the wooden bath tub, leaning back fully relaxed, white soap bubbles on top of head, content closed eyes, peaceful smile",
    # row 5 - caress (being petted)
    "sitting facing the camera, eyes closed in pure bliss, mouth slightly open in soft smile, pink blush on cheeks, body relaxed",
    "looking up with big sparkly hearts in eyes, open mouth in delighted smile, intense pink blush, very excited",
    "tilting head to the right side, half-closed happy eyes, content small smile, ears perked up",
    "leaning forward toward the camera as if asking for more pets, mouth open in happy smile, eyes wide and bright",
    # row 6 - play with ball
    "side view, crouched body, batting at a small red rubber ball with one front paw, focused expression",
    "standing on hind legs, both front paws raised reaching up for a small red ball above, eyes wide excited",
    "rolling on back, all four paws holding a small red ball, playful belly-up pose, mouth open laughing",
    "side view, mid-pounce after a small red ball, body fully stretched in a leap, action pose, ball just ahead",
    # row 7 - happy / dance
    "front view, both front paws raised high in the air, big open smile, body slightly squatted ready to jump",
    "front view, mid-jump in the air, all paws off the ground, mouth open in joy, ears flying upward",
    "front view, just landed from a jump, front paws spread wide, big closed-eye smile, slight crouch",
    "front view, dancing pose with one paw raised and one on hip, head tilted to side, content confident smile",
]
assert len(EXTRA_POSES) == EXT_ROWS * COLS


def gen_extra_sheet(char_id: str) -> Image.Image:
    desc = CHARACTERS[char_id]
    char_dir = os.path.join(CACHE, f"{char_id}_extra")
    os.makedirs(char_dir, exist_ok=True)
    raw_paths = []
    for i, pose in enumerate(EXTRA_POSES):
        out = os.path.join(char_dir, f"{i:02d}.png")
        prompt = (
            v2.STYLE
            + f"\n\nCharacter: {desc}\n\nPose: {pose}\n\n"
            "Generate ONE single sprite, 256x256, transparent PNG."
        )
        print(f"  pose {i:02d}: {pose[:64]}…")
        if not v2.gen_image(prompt, out):
            raise RuntimeError(f"failed pose {i}")
        raw_paths.append(out)
        time.sleep(0.5)
    # Compose extension 4×4
    ext = Image.new("RGBA", (SHEET_W, EXT_H), (0, 0, 0, 0))
    for i, raw in enumerate(raw_paths):
        col, row = i % COLS, i // COLS
        cell = v2.crop_and_normalize(raw, CELL)
        ext.paste(cell, (col * CELL, row * CELL), cell)
    return ext


def merge_with_existing(char_id: str, ext: Image.Image) -> str:
    sheet_path = os.path.join(ASSETS, f"pet_sheet_{char_id}.png")
    if not os.path.exists(sheet_path):
        raise FileNotFoundError(sheet_path)
    base = Image.open(sheet_path).convert("RGBA")
    bw, bh = base.size
    new = Image.new("RGBA", (bw, bh + EXT_H), (0, 0, 0, 0))
    new.paste(base, (0, 0))
    new.paste(ext, (0, bh))
    new.save(sheet_path)
    print(f"✓ {sheet_path}  → {bw}×{bh + EXT_H}")
    return sheet_path


def main():
    chars = sys.argv[1:] or ["garfield"]
    for c in chars:
        if c not in CHARACTERS:
            print(f"Skip unknown {c}")
            continue
        print(f"\n=== {c} ===")
        ext = gen_extra_sheet(c)
        path = merge_with_existing(c, ext)
        # Repair holes (panza/dientes/manos blancas)
        fh.repair(path)


if __name__ == "__main__":
    main()
