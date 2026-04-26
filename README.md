# HCKMX26 · Equipo 1774367935

> **Ecosistema de protección digital infantil con IA generativa, ML aplicado y mascota virtual conversacional.**
> Hackathon **HCKMX26** · CDMX 2026.

Monorepo con la solución end-to-end del equipo: ingesta de TikTok → clasificación ML de contenido sensible → interpretación pedagógica → app iOS para padres (**Flux**) + mascota virtual emocional para niños (**Buddy**).

---

## 🎯 El problema

Los menores consumen TikTok antes que cualquier otra red social. Detectar **contenido de narcocultura** y patrones de riesgo en su feed requiere un pipeline que combine:

1. **Captura de metadata** sin descargar video (yt-dlp / TikTokApi).
2. **Clasificación automática** con un modelo entrenado en señales semánticas + estadísticas.
3. **Traducción pedagógica** de la señal de riesgo a una acción comprensible (no a un dump técnico).
4. **Entrega contextual** al padre (Flux) y al niño (Buddy) sin revictimizar ni exponer datos.

Esa cadena completa vive en este repo.

---

## 🧩 Componentes

```
HCKMX26-1774367935/
├── core/                  · Django 5 — settings, urls, ASGI/WSGI
├── tiktok_receiver/       · Django app — endpoints de ingesta
├── ml_engine/             · Pipeline scikit-learn (RandomForest + TF-IDF)
├── Agentes/
│   ├── agente_B/          · Traductor JSON TikTok → CSV de entrenamiento
│   └── agente_D/          · Intérprete riesgo → recomendación pedagógica
├── Buddy/                 · Mascota virtual (Flutter Android + iOS SwiftUI)
├── Flux/                  · App iOS para padres (SwiftUI + FastAPI backend)
├── analizar_*.py          · Scripts de análisis de features, predicción y sesgo
├── debug_clasificacion.py · Debug del clasificador en datos reales
└── ver_indicadores.py     · Visualizador de métricas
```

### 🤖 Agente B — Traductor

Convierte metadata cruda de TikTok (JSON de yt-dlp o TikTokApi) en filas tabulares listas para entrenamiento.

- **Input**: URL TikTok o JSON ya extraído.
- **Output**: CSV con 21 columnas (`video_id`, `description`, `hashtags_list`, `view_count`, `music_artist`, etc.) en `agente_B/dataset/`.
- **Restricciones**: nunca descarga video. `--skip-download` por defecto.
- Soporta dos fuentes: `ytdlp` (público) o `tiktokapi` (con `ms_token` opcional).

### 🧠 Agente D — Intérprete pedagógico

Traduce el resultado del clasificador a una decisión accionable para Buddy, no a un dump técnico.

- **Input**: JSON con labels + scores del clasificador.
- **Output**: recomendación contextual para el menor.
- **Niveles**: alto → tono protector · medio → cauto + supervisión · bajo → recordatorio positivo · desconocido → neutral-preventivo.
- Robusto a JSON inexistente o inválido.

### 🤖 ML Engine

Clasificador de contenido de narcocultura entrenado sobre **10,000 registros sintéticos** generados con un diccionario masivo de patrones léxicos + métricas de engagement.

- **Pipeline**: `TfidfVectorizer` (texto) + `StandardScaler` (numéricos) + `RandomForestClassifier`, todo dentro de un `Pipeline` + `ColumnTransformer` de scikit-learn.
- **Modelo serializado**: `ml_engine/narco_model.pkl` — carga en milisegundos, predicción en milisegundos, sin reentrenar en producción.
- **Encoder JSON propio** (`NumpyEncoder`) para serializar tipos `numpy` directo a respuesta de API.
- Scripts de auditoría: `analizar_features.py`, `analizar_prediccion.py`, `analizar_sesgo.py`.

### 🛡️ Flux — App iOS para padres

App SwiftUI (iOS 18.2+) que recibe las señales clasificadas y las presenta al padre como **risk score ponderado por confianza**, con foro anónimo de patrones, buzón silencioso para el menor y pareo por proximidad.

- **Frontend**: Swift 5 + SwiftUI + Combine + async/await · 3 targets (app, monitor, widgets) · iOS 18.2+.
- **Backend**: FastAPI 0.115 + SQLModel + Pydantic v2 + SQLite local · roadmap Django + DRF + Celery + Redis + PostgreSQL en Render.
- **Design system propio**: paleta *Calm Sanctuary*, tipografías Geist + Inter + Geist Mono.
- Endpoints: `/risk-score`, `/signals`, `/voz`, `/community/threads`, `/weprotect/insights`, `/pairing/*`, `/analyze-text`.

### 🐾 Buddy — Mascota virtual emocional

Tamagotchi moderno con personajes en pixel art. La mascota **vive fuera de la app** sobre el notch del teléfono (Android) y reacciona en tiempo real a las señales del agente D.

- **Flutter 3.41 + Dart 3.11** · Flame engine · renderer Impeller.
- **Plugin Android Kotlin nativo forkeado** (`local_plugins/overlay_pop_up`) — overlay sobre el punch-hole con `FLAG_LAYOUT_NO_LIMITS` + `LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS`, foreground service `specialUse`, offsets pixel-perfect por device.
- **Random walk orgánico** alrededor del notch (target-following + wobble + notch-avoidance).
- **Speech bubbles dinámicos** con CustomPainter + `Path.combine` (no son notificaciones — son globos del personaje).
- **Tap-to-talk**: tocar al personaje rebota + suelta una frase aleatoria.
- **Mecánicas hiperrealistas**: alimentar, agua, paseo, juego, acariciar, sueño, higiene · personalidad emergente · mortalidad → reencarnación · evoluciones tipo Pokémon · multi-cuidador.
- **Minijuegos**: catch-food, memory-match, rhythm-tap, tap-reaction.
- **iOS legacy** (`Buddy/buddy-ios/`): Swift 5 + SwiftUI + SpriteKit como fuente de verdad de game design durante la migración.

---

## 🎨 Generación de assets con IA

Todos los sprites pixel-art y los diálogos del personaje se generan con la API de **Gemini**, no se dibujan a mano:

| Tool | Modelo | Output |
|---|---|---|
| `Buddy/tools/generate_phrases.py` | **Gemini 2.5 Flash** (text) | 80+ frases en español ≤14 caracteres con prompt estricto + filtrado + dedup |
| `Buddy/tools/generate_sprites_flutter.py` | **Gemini 2.5 Flash Image** | Spritesheets 4×4 (idle / walk / eat / sleep) por personaje, 1024×1024 transparentes |
| `Buddy/tools/generate_garfield_emotions.py` | **Gemini 2.5 Flash Image** | Sprites de emoción (angry / sad / scared) 256×256 con prompt de pose + crop automático con PIL |

Ventaja: el *content pipeline* (sprites + copy) está parametrizado. Agregar un personaje nuevo es ejecutar un script con un prompt distinto.

---

## 🧱 Stack técnico

| Capa | Tecnologías |
|---|---|
| **Backend / API** | Django 5 + DRF + django-cors-headers · PostgreSQL (psycopg2-binary) · gunicorn · dj-database-url · python-dotenv |
| **ML / IA** | scikit-learn 1.8 · pandas 3.0 · numpy 2.4 · joblib · Gemini 2.5 Flash · Gemini 2.5 Flash Image |
| **Ingesta TikTok** | yt-dlp 2026.3 · TikTokApi (opcional) · Playwright/Chromium para sesión |
| **Mobile (Buddy)** | Flutter 3.41 · Dart 3.11 · Flame · Kotlin nativo (Android overlay) · Swift 5 + SpriteKit (iOS legacy) |
| **Mobile (Flux)** | Swift 5 · SwiftUI · Combine · async/await · iOS 18.2+ · 3 targets (app/monitor/widgets) |
| **Backend Flux** | FastAPI · SQLModel · Pydantic v2 · SQLite (dev) · roadmap PostgreSQL + Celery + Redis |
| **Reportes** | reportlab |
| **Tooling** | xcodegen · Gradle · Vite + React 19 (landing en branch develop) · Tailwind |
| **DevOps** | gunicorn · Render Blueprint (roadmap) · Docker (roadmap) |

---

## 🚀 Quick start

### Backend Django + ML

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

python manage.py migrate
python manage.py runserver
# http://localhost:8000
```

### Probar el clasificador end-to-end

```bash
python test_use_ml.py                # carga narco_model.pkl y clasifica un sample
python ver_json_clasificacion.py     # muestra clasificación cruda
python ver_indicadores.py            # métricas agregadas
python debug_clasificacion.py        # debug de features y predicción
```

### Buddy (Flutter Android)

```bash
cd Buddy/buddy-flutter
flutter pub get
flutter run -d <android-device>
# Desde la home, tocar el botón del notch para activar el overlay sobre el punch-hole.
```

### Flux (iOS)

```bash
cd Flux/flux-ios
xcodegen generate
open flux.xcodeproj      # ⌘R en Xcode
```

### Backend FastAPI de Flux (mock data)

```bash
cd Flux/backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python seed.py
uvicorn main:app --reload --port 8000
# Swagger UI: http://localhost:8000/docs
```

### Regenerar sprites / diálogos de Buddy

```bash
cd Buddy/tools
python generate_phrases.py 80
python generate_sprites_flutter.py
python generate_garfield_emotions.py
```

---

## 🔄 Flujo end-to-end

```
TikTok URL
    ↓
[Agente B · Traductor]   yt-dlp / TikTokApi → JSON → CSV
    ↓
[ml_engine · Clasificador]   TF-IDF + StandardScaler + RandomForest → label + score
    ↓
[Agente D · Intérprete]   label + score → recomendación pedagógica
    ↓
        ┌───────────────────────────┬───────────────────────────┐
        ↓                           ↓                           ↓
   [Flux · iOS]              [Buddy · Flutter]            [Dashboard Django]
   risk score + signals      mascota reacciona            métricas + auditoría
   foro anónimo padres       speech bubble + emoción      indicadores agregados
```

---

## 🧠 IA en cada capa

| Capa | Modelo / Técnica | Por qué importa |
|---|---|---|
| Clasificación de contenido | RandomForest + TF-IDF (sklearn) sobre 10k samples sintéticos | Inferencia en milisegundos, sin dependencia de API externa, auditable y depurable |
| Generación de sprites | Gemini 2.5 Flash Image | Pixel art pixel-perfect transparente, parametrizable por prompt |
| Generación de diálogos | Gemini 2.5 Flash | Frases ultra-cortas con personalidad, en español, controladas por filtros de longitud |
| Interpretación pedagógica | Agente D (lógica determinista + niveles) | Traduce señales técnicas a recomendaciones que un menor entiende |
| Asistencia al desarrollo | Claude Code (Opus 4.7 · 1M ctx) | Pair-programming, refactors, debugging, tooling |

---

## 📐 Convenciones de ingeniería

- **Una funcionalidad a la vez** · no se batchean features.
- **Mobile-first** sin excepciones.
- **`async/await` y Combine** sobre callbacks en Swift.
- **VStack siempre `.leading`** salvo decisión explícita.
- **GSAP** por defecto en web (no Framer Motion, no CSS transitions).
- **RealityKit** para AR (no Quick Look).
- Commits en español, concisos.

---

## 👥 Equipo

**Equipo HCKMX26 · 1774367935**

Lead dev / arquitectura: **Emilio Cruz V.** — [@mrKOmbo](https://github.com/mrKOmbo)

---

## 📄 Licencia

MIT — ver [`LICENSE`](LICENSE).
