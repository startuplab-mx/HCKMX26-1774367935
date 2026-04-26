#!/usr/bin/env python3
"""Generate Buddy chatter phrases via Gemini Flash (text).

Output: buddy-flutter/assets/phrases.json — flat array of short strings.
The Flutter overlay picks one at random every 5–15 s.

Usage:
    .venv/bin/python tools/generate_phrases.py [count]
"""
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "buddy-flutter", "assets", "phrases.json")

KEY = None
for line in open(os.path.join(ROOT, ".env")):
    if line.startswith("GEMINI_API_KEY="):
        KEY = line.split("=", 1)[1].strip()
assert KEY, "GEMINI_API_KEY missing in .env"

URL = (
    "https://generativelanguage.googleapis.com/v1beta/models/"
    f"gemini-2.5-flash:generateContent?key={KEY}"
)


def build_prompt(count: int) -> str:
    return f"""Eres un escritor de juego Tamagotchi (Buddy).

Genera EXACTAMENTE {count} frases muy CORTAS distintas que la mascota dice al dueño desde un globito que sale junto al personaje.

REGLAS ESTRICTAS — SI ROMPES UNA, FALLAS:
- Idioma: español neutro.
- Tono: tierno, juguetón. Nunca cínico ni grosero.
- LÍMITE DE LARGO: cada frase máximo 14 CARACTERES, contando espacios y emojis. NUNCA más.
- Mejor frases de 5–10 caracteres. Súper concisas.
- 70 % sin emoji, 30 % con un solo emoji al final.
- Variedad: hambre, sed, sueño, juego, cariño, onomatopeyas (*pio*, *zzz*), preguntas (¿jugar?), saludos cortos (¡hola!), aburrimiento.
- NUNCA repitas la misma frase.
- NO uses comillas dentro.
- NO menciones "Tamagotchi" ni "Buddy".

Ejemplos válidos: "¡hola!" "tengo hambre" "¿jugar? 🎮" "*zzz*" "te extraño" "¡ven!" "sed 💧" "aburrido" "¿paseo?"
Ejemplos INVÁLIDOS por largos: "Te extrañé mucho hoy." "¿Vamos al parque a jugar?"

Devuelve EXCLUSIVAMENTE un JSON array de {count} strings. NADA de texto fuera del array."""


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 80
    prompt = build_prompt(count)
    body = json.dumps(
        {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 1.15,
                "responseMimeType": "application/json",
            },
        }
    ).encode()
    req = urllib.request.Request(
        URL, data=body, headers={"Content-Type": "application/json"}
    )
    print(f"Calling Gemini Flash for {count} phrases...")
    with urllib.request.urlopen(req, timeout=300) as r:
        data = json.load(r)
    text = data["candidates"][0]["content"]["parts"][0]["text"]
    try:
        phrases = json.loads(text)
    except json.JSONDecodeError:
        # If the model wrapped the array in something, salvage the JSON.
        start = text.find("[")
        end = text.rfind("]") + 1
        phrases = json.loads(text[start:end])
    assert isinstance(phrases, list) and all(isinstance(p, str) for p in phrases)
    # Deduplicar manteniendo orden + filtrar las que excedan 14 chars.
    MAX_LEN = 14
    seen = set()
    unique = []
    rejected = []
    for p in phrases:
        p = p.strip()
        if not p or p in seen:
            continue
        if len(p) > MAX_LEN:
            rejected.append(p)
            continue
        seen.add(p)
        unique.append(p)
    print(f"  → {len(unique)} unique short phrases (≤ {MAX_LEN} chars)")
    if rejected:
        print(f"  → descartadas {len(rejected)} por largas:")
        for r in rejected[:5]:
            print(f"      ({len(r)}) {r}")
        if len(rejected) > 5:
            print(f"      ... y {len(rejected) - 5} más")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(unique, f, indent=2, ensure_ascii=False)
    print(f"  ✓ {OUT}")
    print("\nMuestra:")
    for p in unique[:8]:
        print(f"  · {p}")


if __name__ == "__main__":
    main()
