# flux backend

API que simula el backend real de flux durante el hackathon. Define la forma de los datos, cómo la app iOS los consume, y genera datos aleatorios para testeo.

**Stack**: FastAPI · SQLModel · SQLite local · Pydantic · Faker.
En producción (roadmap post-hackathon) migra a Django + DRF + PostgreSQL + Redis + Celery, como define el [CLAUDE.md](../CLAUDE.md) del repo.

## Setup

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# generar datos aleatorios (borra y reseed)
python seed.py

# arrancar el servidor
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

- API: http://localhost:8000
- **Swagger UI** (docs interactivas): http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- Health: http://localhost:8000/api/v1/health

## Qué genera el seed

| Tabla | Cantidad | Notas |
|---|---|---|
| `profile` | 5 | 3 padres + 2 menores |
| `childmonitor` | 2 | Lucía (13) y Mateo (11) |
| `signal` | 80 | 20 activas + 60 históricas con resolución |
| `patternfootprint` | 30 | huellas anónimas del foro |
| `communitythread` | 25 | hilos con mix de autores y status |
| `vozentry` | 40 | entries del buzón silencioso de los menores |

Seed determinístico (`random.seed(42)`) · siempre genera los mismos datos.

```bash
python seed.py           # limpia y reseed
python seed.py --append  # no borra, solo agrega
```

## Endpoints principales (lo que consume la app iOS)

### Sistema
- `GET /api/v1/health` — estado + conteo de tablas

### Perfiles
- `GET /api/v1/profiles?role=parent|child` — lista perfiles
- `GET /api/v1/profiles/{id}` — detalle
- `GET /api/v1/profiles/{id}/children` — menores que monitorea este padre

### Risk score + señales (modo padre — Dashboard)
- `GET /api/v1/children/{id}/risk-score` → `{ value, band, trend_7d, active_signal_count }`
- `GET /api/v1/children/{id}/signals?active=true&limit=50`
- `GET /api/v1/children/{id}/signals?active=false` — historial
- `GET /api/v1/signals/{id}` — detalle para la pantalla AlertDetail
- `POST /api/v1/signals/{id}/resolve?note=...` — marcar como revisada
- `GET /api/v1/children/{id}/baseline` — línea base para BaselineView

### WeProtect (análisis AI)
- `POST /api/v1/weprotect/analyze` — detecta patrones de riesgo en texto
  ```json
  { "text": "no le digas a tu mamá, es sorpresa", "source": "scanner" }
  ```
  Devuelve severidad, insights por pilar (1–4 de la convocatoria), y matches con el foro.

- `POST /api/v1/weprotect/approaches` — genera 3 scripts de conversación
  ```json
  { "child_name": "Lucía", "child_age": 13, "context": "..." }
  ```

### Foro (huellas anónimas)
- `GET /api/v1/forum/footprints?platform=TikTok&status=resolved`
- `GET /api/v1/forum/footprints/{id}`
- `POST /api/v1/forum/footprints/{id}/me-too` — incrementa contador anónimo

### Comunidad
- `GET /api/v1/community/threads?signal_filter=...&limit=50`
- `GET /api/v1/community/threads/{id}`

### Voz (modo menor)
- `GET /api/v1/voz/{case_id}/entries`
- `POST /api/v1/voz/{case_id}/entries` — crear entry, opcionalmente pedir review de WeProtect
  ```json
  { "kind": "text", "text_content": "...", "request_weprotect_review": true }
  ```

### Pairing (NearbyInteraction)
- `POST /api/v1/pairing/invitation` — genera `VozInvitation` firmada (tracking)
  En la app real el payload se intercambia device↔device vía BLE + UWB; este endpoint solo lo usamos para telemetría del backend.

## Schema de datos

Ver [`models.py`](models.py). Resumen:

```
Profile (role: parent|child)
  ├─ avatar_color, biometric_enabled, display_name
  ├─ monitored_child_ids       ← solo en padres
  └─ case_id, paired_with_parent_name  ← solo en menores

ChildMonitor
  └─ name, age, baseline_apps, parent_profile_id

Signal (is_active, severity, kind)
  ├─ title, summary, pattern_id (P-07, P-11...)
  ├─ confidence, detected_at
  └─ resolved_at, resolution_note

PatternFootprint (anónimo)
  ├─ emojis, phrases, platforms, approach
  ├─ time_window, age_range
  ├─ status (pending, reviewed, escalated, resolved)
  └─ match_count ("me pasó también")

CommunityThread
  ├─ author_nickname (anonimizado), author_initial
  ├─ title, preview, body, replies_count
  └─ status_tag, signal_filter

VozEntry
  ├─ case_id (del menor)
  ├─ kind (text | voice | photo | file | drawing)
  ├─ text_content, weprotect_reviewed, weprotect_risk
  └─ contributed_to_forum
```

## Cómo la app iOS consume esto

La app tiene un `WeProtectAI` manager que hoy corre **on-device** con Apple Intelligence o reglas locales. Cuando activamos backend remoto (flag en Ajustes), la misma interfaz hace `POST` a `/api/v1/weprotect/analyze` en vez de correr local. Esto es intencional: la seguridad del menor no depende de red, pero el backend nos permite:

1. **Agregación** — foro poblado con casos reales de múltiples familias
2. **Comunidad** — hilos persistentes entre usuarios
3. **Telemetría** — sin datos personales, solo conteo de patrones para mejorar el modelo
4. **Sync multi-dispositivo** — padre en iPad + iPhone ve el mismo estado
5. **Portal escuelas (roadmap Q4)** — dashboard agregado para colegios

## Ejemplos rápidos

```bash
# status del sistema
curl http://localhost:8000/api/v1/health | jq

# listar padres
curl "http://localhost:8000/api/v1/profiles?role=parent" | jq

# analizar texto
curl -X POST http://localhost:8000/api/v1/weprotect/analyze \
  -H 'content-type: application/json' \
  -d '{"text": "mi amor, no le digas a tu mamá, tengo un regalo", "source": "scanner"}' | jq

# primer menor + su risk score
CHILD_ID=$(curl -s "http://localhost:8000/api/v1/profiles?role=parent" | jq -r '.[0].monitored_child_ids[0]')
curl "http://localhost:8000/api/v1/children/$CHILD_ID/risk-score" | jq

# foro filtrado por plataforma
curl "http://localhost:8000/api/v1/forum/footprints?platform=TikTok" | jq '.[0:3]'
```

## Producción (roadmap post-hackathon)

Lo que hoy está en FastAPI migra a la stack del [CLAUDE.md](../CLAUDE.md):

- **Django 5.1 + DRF** · arquitectura hexagonal (`core/`, `adapters/`, `application/`, `interfaces/api/`)
- **PostgreSQL** en Render, SQLite local como fallback
- **Celery + Redis** para jobs de agregación del foro, moderación automática
- **Gunicorn + Docker** · blueprint en `render.yaml`
- **Ingesta real** de metadatos del SO — actualmente los signals se simulan con seed; en producción el cliente iOS envía eventos anonimizados

## Archivos

```
backend/
├── README.md              ← este archivo
├── requirements.txt
├── main.py                ← FastAPI app (endpoints)
├── models.py              ← SQLModel tables + pydantic schemas
├── database.py            ← engine SQLite + session DI
├── seed.py                ← generador de datos aleatorios
└── data/flux.db           ← SQLite (gitignored)
```
