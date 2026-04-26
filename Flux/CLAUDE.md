# CLAUDE.md Template

Plantilla para el archivo `CLAUDE.md` en la raíz de cada proyecto nuevo. Claude Code lo lee automáticamente y obtiene contexto desde el commit 1.

---

## Qué incluir (y qué NO)

**SÍ**:
- Estructura de carpetas con una línea explicando cada una
- Stack: qué frameworks, versiones mínimas, por qué esas decisiones
- Rutas API / entry points principales
- Variables de entorno críticas (nombres, no valores)
- Comandos habituales (run dev, tests, deploy)
- Convenciones: estilo, idioma, git user
- Secretos: qué NO commitear

**NO**:
- Explicaciones de qué es Django/Swift/etc. (Claude ya lo sabe)
- Historial de decisiones (eso es `git log`)
- Documentación de producto (eso va en otros `.md`)

Mantenerlo **denso y actualizado**. Si crece más de 200 líneas, algo está mal.

---

## Plantilla — copiar y reemplazar `<placeholders>`

````markdown
# <NombreProyecto> — <descripción de 1 línea>

<1-2 frases sobre qué hace el proyecto y su contexto> (ej: "Monorepo con app iOS + backend Django + pipeline ML para <problema>").

## Estructura del repo

```
<proyecto>/
├── frontend/                      # <tecnología>
│   ├── <Proyecto>.xcodeproj       # bundle id: <bundle_id>
│   ├── <Proyecto>/                # App iOS principal
│   │   ├── Core/                  # App, Managers, Services, Models
│   │   ├── Features/              # <lista de features>
│   │   └── Shared/                # Cross-cutting
│   └── <Proyecto>Watch Watch App/ # watchOS (si aplica)
│
├── backend-api/                   # Django 5.1 + DRF · hexagonal
│   ├── src/
│   │   ├── core/                  # settings, urls, celery
│   │   ├── adapters/              # I/O externo
│   │   ├── application/           # lógica de negocio
│   │   └── interfaces/api/        # vistas DRF
│   └── models/                    # *.pkl (si ML)
│
├── scripts/                       # <propósito>
└── render.yaml                    # Blueprint deploy
```

## Stack

**Frontend** · <Swift/React/etc.> <versión>, <frameworks clave>. Mínimos: <iOS X+ / Node X+>.

**Backend** · Django 5.1 + DRF, Celery + Redis, PostgreSQL / SQLite fallback, Gunicorn, Docker.

**ML** (si aplica) · <XGBoost/sklearn>, pandas, <librerías clave>.

**Fuentes de datos** · <APIs externas usadas>.

## Rutas API

Todas bajo `/api/v1/`, incluidas desde `core/urls.py`:

| Prefijo | App | Responsabilidad |
|---|---|---|
| `<prefijo>/` | `interfaces/api/<app>` | <qué hace> |

Health check: `/api/v1/<health_endpoint>`.

## Features principales

- **<Feature A>** · `Features/<A>/Views/<View>.swift` · <qué hace>
- **<Feature B>** · `Features/<B>/...` · <qué hace>

## Variables de entorno

Configuración vía `.env` (ver `.env.example`). Claves relevantes:
- `<API_KEY_1>`, `<API_KEY_2>`
- `DATABASE_URL` (Render) o `DB_*` (docker-compose local)
- `DEBUG`, `ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS`, `SECRET_KEY`
- `REDIS_URL` (opcional)

El `.env` con secretos **no** se commitea. Solo `.env.example`.

## Comandos habituales

**Backend local (Docker)**
```bash
cd backend-api && docker compose up --build
# → http://localhost:8000/api/v1/…
```

**Backend local (sin Docker)**
```bash
cd backend-api && source venv/bin/activate
pip install -r requirements.txt
cd src && python manage.py runserver
```

**Frontend iOS**
```bash
open frontend/<Proyecto>.xcodeproj    # ⌘R en Xcode
```

**Entrenar modelos ML** (si aplica)
```bash
python scripts/download_training_data.py
python scripts/train_model.py
python scripts/export_coreml.py
```

## Deploy

`render.yaml` declara:
- `<proyecto>-api` (web, Docker, plan starter)
- `<proyecto>-postgres` (Postgres starter)
- Secretos `sync: false` → configurar en dashboard

Autodeploy en `git push`. Dockerfile compila con <deps especiales si las hay>.

## Convenciones

- **Git user**: `<usuario>`. Rama principal: `main`. Commits en <idioma> con prefijos `feat(...): ...`, `fix: ...`, `chore: ...`.
- **Idioma**: <el código está en inglés / comentarios en español / etc.>.
- **Secretos**: nunca commitear `.env`, `xcuserstate`, archivos `*.pkl` si pesan >50MB.

## Documentación adicional

`.md` con contexto — útiles para entender decisiones, no leer de corrido:
- `<archivo1>.md` — <qué contiene>
- `<archivo2>.md` — <qué contiene>
````

---

## Checklist al crear un proyecto nuevo

- [ ] Copiar esta plantilla a `<proyecto>/CLAUDE.md`
- [ ] Reemplazar todos los `<placeholders>`
- [ ] Borrar secciones que no apliquen (ML, Watch, etc.)
- [ ] Primera iteración: llenar con lo que SÍ existe, dejar lo futuro fuera
- [ ] Commit junto al primer push (para que Claude Code lo tenga desde el principio)

---

## Mantenimiento

- Actualizar cuando:
  - Se añade/quita una app Django
  - Se cambia el stack
  - Se añaden variables de entorno críticas
  - Se crea un feature mayor en iOS
- NO actualizar por cambios pequeños: si son cosas que Claude puede derivar leyendo el código, no tiene sentido duplicarlo.

---

## Ejemplo real

`CLAUDE.md` de AirWay: `/Users/main/Documents/develop/AirWay/CLAUDE.md` — úsalo como referencia de nivel de detalle.
