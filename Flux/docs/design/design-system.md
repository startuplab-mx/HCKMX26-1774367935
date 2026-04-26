# flux · Design System v1

Sistema visual cerrado. No se renegocia durante el hackathon salvo excepción justificada.

## Color — Paleta B "Calm Sanctuary"

Light-first. Dark mode como variante auto (iOS `colorScheme`).

### Tokens base (light)

| Token | Hex | Uso |
|---|---|---|
| `base` | `#FAF8F5` | Fondo de pantalla |
| `surface` | `#FFFFFF` | Cards, sheets, modales |
| `surface-alt` | `#F4F0E9` | Secciones, agrupadores |
| `ink` | `#1A1D23` | Texto primario, títulos |
| `ink-muted` | `#57534E` | Texto secundario, labels |
| `ink-faint` | `#A8A29E` | Placeholder, deshabilitado |
| `line` | `#E7E5E4` | Bordes, separadores |

### Semánticos

| Token | Hex | Uso |
|---|---|---|
| `primary` | `#0F766E` | CTA, links activos, score neutral, brand |
| `primary-soft` | `rgba(15,118,110,0.1)` | Fondo de pills, badges |
| `accent` | `#FB7185` | Destaque secundario, highlights emocionales |
| `safe` | `#059669` | Score bajo, señales resueltas, estado OK |
| `warn` | `#D97706` | Score medio, atención no urgente |
| `danger` | `#DC2626` | Score alto, alerta activa |

### Dark mode (auto)

| Token | Hex |
|---|---|
| `base` | `#1A1D23` |
| `surface` | `#23262D` |
| `surface-alt` | `#2C2F36` |
| `ink` | `#FAF8F5` |
| `ink-muted` | `#A8A29E` |
| `line` | `#3A3D44` |
| `primary` | `#2DD4BF` (brighter teal for dark) |

## Tipografía

| Rol | Familia | Uso |
|---|---|---|
| Display | **Geist** | Títulos, scores grandes, CTAs grandes |
| Body | **Inter** | Texto funcional, cards, listas, formularios |
| Mono | **Geist Mono** | Timestamps, IDs de señal, confidence, datos técnicos |

### Escala (SwiftUI `Font`)

| Rol | Size | Weight | Letter-spacing |
|---|---|---|---|
| `display-xl` | 56 | 800 | -0.04em |
| `display-lg` | 40 | 700 | -0.03em |
| `title-1` | 28 | 700 | -0.02em |
| `title-2` | 22 | 600 | -0.01em |
| `title-3` | 18 | 600 | 0 |
| `body` | 16 | 400 | 0 |
| `body-medium` | 16 | 500 | 0 |
| `callout` | 14 | 500 | 0 |
| `caption` | 12 | 500 | 0.05em |
| `mono-sm` | 11 | 500 | 0.1em (uppercase) |

## Spacing scale (pt)

`2 · 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48 · 64 · 80`

## Radii

| Token | Valor |
|---|---|
| `r-sm` | 8 |
| `r-md` | 12 |
| `r-lg` | 16 |
| `r-xl` | 20 |
| `r-2xl` | 28 (cards grandes) |
| `r-pill` | 100 |

## Shadows

Sutiles, cálidas. No abusar.

- `shadow-sm` · `rgba(26,29,35,0.04) 0 1px 2px`
- `shadow-md` · `rgba(26,29,35,0.06) 0 4px 12px`
- `shadow-lg` · `rgba(26,29,35,0.08) 0 12px 32px -8px`

## Iconos

SF Symbols (nativo iOS). Peso `.regular` por defecto, `.semibold` en estados activos.

Claves: `shield`, `waveform.path.ecg`, `chart.line.uptrend.xyaxis`, `bell.badge`, `moon.stars`, `person.crop.circle`, `clock.arrow.circlepath`, `sparkles`, `info.circle`.

## Principios

1. **Transparencia como feature** — cada pantalla que procesa datos del menor muestra visualmente qué se lee y qué NO.
2. **Calma antes que alarma** — el estado default es tranquilo; la alerta es excepción visible, no ruido constante.
3. **Datos explicables** — nunca un score sin razón. El mono y las listas de señales cuentan la historia.
4. **Mobile-first, una mano** — targets mínimos 44pt, acciones críticas en la mitad inferior.
5. **Sin emojis en UI** — salvo ícono de sistema. Seriedad institucional.

## WeProtect — el asistente IA

Todas las capacidades de IA dentro de flux se agrupan bajo el nombre **WeProtect**. Unifica marca y evita confusión al usuario.

Responsabilidades de WeProtect:
- **Recomendaciones de conversación** (modo padre, frame 06) — 3 abordajes con tono distinto.
- **Análisis de archivos** (frame 07) — OCR + detección de patrones de riesgo en imágenes/PDFs/URLs.
- **Asistencia pasiva del menor** (frame 11) — sugerencias de acción sin presión, desde el buzón silencioso.

Tono de WeProtect:
- No alarmista. No paternalista. No jerga técnica.
- Siempre explica **por qué** dice lo que dice, con referencias a las señales que disparó.
- En modo menor: voz de "alguien que escucha", nunca "alguien que resuelve por ti".

## Modo menor — "flux voz"

Variante del mismo binario con tokens suavizados. Misma paleta base, pero:

| Diferencia | Modo padre | Modo menor |
|---|---|---|
| Density | Alta (dashboards, datos) | Baja (una idea por pantalla) |
| Uppercase labels | Sí (mono) | No |
| Color danger | `#DC2626` visible | Nunca. Solo ink + primary. |
| Radii | `r-md/lg` | `r-xl/2xl` (más redondeado) |
| Botones | CTA con fondo sólido | Preferir texto + link suave |
| Emojis/iconos | Sólo SF Symbols | Permitido un set limitado de ilustraciones calmas |
| Voz | Precisa, técnica | Cercana, sin apuro, sin juicio |

### Tokens específicos modo menor

- `voz-bg` · `#FAF6EE` (más cálido que base)
- `voz-ink` · `#2D2A26` (warm black)
- `voz-accent` · `#0F766E` (mismo primary)
- `voz-muted` · `#8B867D`

## Foro de patrones · "huellas de comportamiento"

Sistema de inmunidad colectiva. Nunca nombres reales. Nunca identidades. Solo **huellas** — patrones despersonalizados extraídos de los casos que las víctimas acuerdan compartir (opt-in explícito tras resolver su caso).

### Qué es una huella

Registro anónimo que contiene:

- **Emojis recurrentes** — ej. `😍 🤫 🎁`
- **Frases típicas** — ej. "no le digas a tu mamá", "tengo un regalo"
- **Plataformas** — TikTok, Discord, Roblox, Telegram
- **Patrón horario** — noche, madrugada
- **Método de abordaje** — elogio físico, oferta económica, compromiso falso, aislamiento
- **Rango de edad que aborda** — 10–12 / 13–15 / 16–17
- **Estado del caso** — pendiente · revisado · derivado · resuelto
- **Contador** — "me pasó también: N"

### Qué NO contiene una huella

- Nombres reales o apodos
- @handles de redes sociales
- Números de teléfono, emails
- Ubicación específica
- Edad exacta
- Fotos o screenshots identificables
- Info personal de la víctima que subió el caso

### Censura automática (WeProtect · moderación en tiempo real)

Todo contenido que entra al foro o al chat anónimo entre víctimas pasa por un filtro en tiempo real:

- Regex layer — teléfonos, emails, @handles, URLs
- NLP layer (WeProtect) — nombres propios, ubicaciones, institutos, info identificable

Reemplazo visual: `[censurado]` con tooltip "WeProtect oculta datos personales automáticamente".

### Match contra foro

Tras cualquier análisis (archivo del padre o entrada del menor en buzón), WeProtect compara las features extraídas contra el foro. Si hay coincidencia:

- **Modo menor** → notificación pasiva: "alguien más pasó por esto. no estás sola."
- **Modo padre** → chip en el resultado del análisis: "coincide con N casos del foro".

### Estados de un caso

| Estado | Color | Significado |
|---|---|---|
| pendiente | `ink-muted` | acabado de subir, sin revisar |
| revisado | `primary` | WeProtect + moderador lo vieron |
| derivado | `warn` | se pasó a autoridad (089, CEAV, FGR) |
| resuelto | `safe` | cerrado por moderación |

### Contacto anónimo entre víctimas

- Es opt-in desde el caso propio.
- Es chat directo, pero cada mensaje pasa por la capa de censura en tiempo real antes de mostrarse al otro lado.
- Los mensajes con `[censurado]` se entregan igual, sin el dato personal.
- Moderadores profesionales tienen acceso al log para intervenir si detectan abuso del canal.

## Vista escáner

El escáner es un **tab central destacado** (tipo FAB sobresalido) en el tab bar, no un formulario escondido en un menú. Es la manera principal de alimentar WeProtect — foto, captura, archivo, URL — y dispara el flujo de análisis.

### Por qué tab central, no formulario

- Conversión mucho mayor: si es escondido, el padre no lo usa. Si es central, se ve siempre.
- Coherencia con apps de uso masivo: Instagram, Snapchat, Cash App, banca mexicana.
- El escáner **es** el producto. Sin datos que analizar, flux no tiene qué decir.

### Vista escáner (estructura común ambos modos)

1. **Cámara full-screen** con overlay oscuro translúcido.
2. **Marco de escaneo central** con 4 esquinas marcadas (L-shapes), como QR.
3. **Selector de tipo** arriba: `chat · doc · perfil · link`.
4. **Dock inferior** con 3 opciones principales: `galería · [captura] · archivo`.
5. **Tag superior** con el nombre del asistente: "WeProtect revisa lo que subas".
6. **Botón cerrar** (×) arriba izquierda.

### Diferencia padre vs menor

| Elemento | Padre | Menor (flux voz) |
|---|---|---|
| Overlay fondo | Neutro oscuro | Cálido + transparente |
| Tag superior | "WeProtect analizará" | "solo tú vas a ver esto" |
| Instrucción | "Apunta a una conversación" | "escanea lo que te incomoda" |
| Post-captura | Resultado técnico + CTA reporte | Guardado silencioso + opt-in análisis |

### Flujo post-análisis

Tras la captura y análisis, ambos modos desembocan en **"hacer reporte"** — pantalla con las mismas 4 opciones con tono adaptado:

1. **Aportar huellas al foro** (opt-in) — ayuda a próximas víctimas.
2. **Línea 089** — 24h, anónimo, gratis.
3. **Compartir con adulto de confianza** (menor) / **Derivar a profesional** (padre).
4. **Reporte anónimo INAI/FGR**.

Guardar y cerrar también es válido. Ninguna acción es obligatoria.
