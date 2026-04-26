"""
flux backend · generador de datos aleatorios para testeo

Uso:
    python seed.py             # seed limpio (borra y regenera todo)
    python seed.py --append    # solo añade (no borra)

Genera:
    5 perfiles (3 padres, 2 menores)
    20 señales activas + 60 históricas
    30 huellas de patrones en el foro
    25 hilos de comunidad
    40 entries de buzón voz
"""

import argparse
import base64
import os
import random
import sys
from datetime import datetime, timedelta
from uuid import uuid4

from faker import Faker
from sqlmodel import Session, delete, select

from database import engine, init_db
from models import (
    AgeRange, CaseStatus, ChildMonitor, CommunityThread,
    PatternFootprint, Profile, ProfileRole, Severity, Signal,
    SignalKind, ThreadStatus, TimeWindow, VozEntry,
)

fake = Faker("es_MX")
random.seed(42)
Faker.seed(42)


# =============================================================================
# Catálogos realistas
# =============================================================================

PARENT_NAMES = [
    ("Camila Vega", "#0F766E"),
    ("Roberto Méndez", "#7C3AED"),
    ("Sofía Torres", "#D97706"),
]

CHILD_NAMES = [
    ("Lucía Vega", 13, "#8B5E3C"),
    ("Mateo Méndez", 11, "#FB7185"),
]

BASELINE_APPS = ["TikTok", "Instagram", "WhatsApp", "YouTube", "Spotify", "Snapchat"]

SIGNAL_TEMPLATES = {
    SignalKind.platform_transition: [
        ("Transición TikTok → Discord", "3 veces esta semana entre 2 y 4 AM", "P-07"),
        ("Transición Instagram → Snapchat", "Movimientos inusuales hacia privado", "P-07"),
        ("Transición TikTok → Telegram", "Instalación reciente + transición inmediata", "P-08"),
    ],
    SignalKind.atypical_hours: [
        ("Horario atípico · 3.2h", "Actividad entre 1 y 4 AM", "P-11"),
        ("Madrugada activa", "Uso de Discord 02:00-03:30", "P-11"),
        ("Ruptura de patrón nocturno", "Línea base: 22:30 apagado; detectado: 03:45", "P-12"),
    ],
    SignalKind.reactive_install: [
        ("App nueva · Telegram", "Instalada tras 40 min de TikTok", "P-03"),
        ("App nueva · Discord", "Instalada tras contacto reciente", "P-03"),
        ("App nueva · Snapchat", "Post uso intenso de Instagram", "P-04"),
    ],
    SignalKind.digital_isolation: [
        ("Disminución de Instagram", "Uso bajó 30% repentinamente", "P-09"),
        ("Aislamiento digital", "Abandonó apps sociales habituales", "P-10"),
    ],
    SignalKind.grooming_pattern: [
        ("Patrón detectado en captura", "3 fragmentos de alto riesgo", "P-22"),
        ("Coincidencia con foro · 7 casos", "Emojis 😍🎁🤫 y frases típicas", "P-22"),
    ],
}

FORUM_EMOJIS = [
    ["😍", "🎁", "🤫"],
    ["💕"],
    ["📸"],
    ["🎮"],
    ["💸", "🎂"],
    ["😘"],
    [],
]

FORUM_PHRASES = [
    ["no le digas a tu mamá", "tengo un regalo"],
    ["tenemos algo especial tú y yo"],
    ["foto de buenas noches"],
    ["amigo especial"],
    ["es sorpresa para tu cumpleaños"],
    ["soy de tu edad, te lo juro"],
    [],
]

FORUM_APPROACHES = [
    ["elogio", "regalo", "secreto"],
    ["compromiso", "aislamiento"],
    ["elogio", "secreto"],
    ["moneda virtual", "elogio"],
    ["regalo", "secreto", "compromiso"],
    ["perfil falso", "edad alterada"],
]

FORUM_PLATFORMS = [
    ["TikTok", "Discord"],
    ["Snapchat", "WhatsApp"],
    ["Discord", "Telegram"],
    ["Roblox"],
    ["TikTok", "Telegram"],
    ["Instagram"],
    ["WhatsApp"],
]

FORUM_SUMMARIES = [
    "empezó con cumplidos, después pidió fotos. al final lo denuncié.",
    "me hacía sentir única. después quería alejarme de mis amigas.",
    "pedía una foto mía antes de dormir, cada noche.",
    "me ofreció robux si le mandaba fotos.",
    "me decía que tenía una sorpresa, pero nunca podía contarle a nadie.",
    "decía tener 16, después supe que era alguien del colegio.",
    "quería que me agregara en otra app más privada.",
    "me mandaba stickers románticos y preguntas personales.",
]

THREAD_TITLES = [
    "Me pasó igual con mi hij@ ({age})",
    "Cómo abordé la conversación sin que se cerrara",
    "Al final era un grupo del colegio",
    "Mi nieta me pidió ayuda por flux voz",
    "¿Cuándo es momento de revisar personalmente?",
    "Enseñé a mi hij@ cómo funciona WeProtect",
    "Urgente · usuario reportado por varias familias",
    "Falso positivo resuelto en 2 días",
    "La Opción 2 del coach funcionó perfecto",
    "Conecté con otra mamá por flux voz",
]

THREAD_PREVIEWS = [
    "flux me marcó el mismo patrón en enero. Al principio entré en pánico, pero después de leer las sugerencias del coach empecé con la Opción 2...",
    "La Opción 2 del WeProtect coach funcionó mejor de lo esperado. Lo que hice distinto fue esperar a que ella misma sacara el tema...",
    "Falso positivo real. Dejen que la conversación respire antes de actuar. flux solo detecta patrones — el contexto siempre lo pone la familia...",
    "Mi nieta activó flux voz desde la escuela y me pidió hablar conmigo antes de contarle a sus papás. La app nos dio el espacio que necesitábamos...",
    "Le mostré al niño cómo funciona el análisis on-device y por qué nada sale del teléfono. Entender la tecnología construye confianza...",
    "flux detectó el mismo patrón en 7 familias del mismo código postal. Lo reportamos juntas al INAI...",
]

VOZ_ENTRIES_SAMPLE = [
    "me escribió otra vez hoy, me da miedo pero no sé si decirle a alguien",
    "guardé la captura de la conversación por si acaso",
    "hoy en la escuela pasó algo raro, después cuento",
    "[nota de voz 1:24]",
    "ayer pedí un consejo al asistente y me sirvió",
]


# =============================================================================
# Seed functions
# =============================================================================

def seed_profiles(session: Session) -> tuple[list[Profile], list[ChildMonitor]]:
    """Crea 3 padres + 2 menores + sus monitores."""
    parents = []
    for name, color in PARENT_NAMES:
        p = Profile(
            role=ProfileRole.parent,
            display_name=name,
            avatar_color=color,
            biometric_enabled=True,
        )
        session.add(p)
        parents.append(p)

    # Commit para obtener IDs
    session.commit()
    for p in parents:
        session.refresh(p)

    # Crear menores como ChildMonitor asociados a padres
    children_monitors = []
    for i, (cname, age, ccolor) in enumerate(CHILD_NAMES):
        parent = parents[i % len(parents)]
        cm = ChildMonitor(
            parent_profile_id=parent.id,
            name=cname.split()[0],
            age=age,
            baseline_apps=random.sample(BASELINE_APPS, k=4),
        )
        session.add(cm)
        children_monitors.append(cm)

        # Actualizar lista de hijos en el perfil padre
        parent.monitored_child_ids = parent.monitored_child_ids + [str(cm.id)]

    session.commit()
    for cm in children_monitors:
        session.refresh(cm)

    # Crear también perfiles tipo "child" (el menor tiene su propio device)
    child_profiles = []
    for (cname, age, ccolor), cm in zip(CHILD_NAMES, children_monitors):
        parent = next(p for p in parents if str(cm.id) in p.monitored_child_ids)
        cp = Profile(
            role=ProfileRole.child,
            display_name=cname,
            avatar_color=ccolor,
            biometric_enabled=True,
            case_id=uuid4(),
            paired_with_parent_name=parent.display_name,
        )
        session.add(cp)
        child_profiles.append(cp)

    session.commit()
    return parents + child_profiles, children_monitors


def seed_signals(session: Session, children: list[ChildMonitor]) -> None:
    """Genera 20 activas + 60 históricas."""
    now = datetime.utcnow()

    # Activas: últimas 48h, mezcla de severidades
    for _ in range(20):
        cm = random.choice(children)
        kind = random.choice(list(SignalKind))
        templates = SIGNAL_TEMPLATES.get(kind, [])
        if not templates:
            continue
        title, summary, pid = random.choice(templates)
        severity = random.choices(
            [Severity.low, Severity.medium, Severity.high],
            weights=[1, 3, 2],
        )[0]
        s = Signal(
            child_id=cm.id,
            kind=kind,
            severity=severity,
            title=title,
            summary=summary,
            pattern_id=pid,
            confidence=round(random.uniform(0.55, 0.95), 2),
            detected_at=now - timedelta(hours=random.randint(1, 48)),
            is_active=True,
        )
        session.add(s)

    # Históricas: últimas 2 semanas, resueltas
    for _ in range(60):
        cm = random.choice(children)
        kind = random.choice(list(SignalKind))
        templates = SIGNAL_TEMPLATES.get(kind, [])
        if not templates:
            continue
        title, summary, pid = random.choice(templates)
        severity = random.choice(list(Severity))
        detected = now - timedelta(days=random.randint(2, 14), hours=random.randint(0, 23))
        resolved = detected + timedelta(hours=random.randint(2, 72))
        s = Signal(
            child_id=cm.id,
            kind=kind,
            severity=severity,
            title=title,
            summary=summary,
            pattern_id=pid,
            confidence=round(random.uniform(0.4, 0.95), 2),
            detected_at=detected,
            is_active=False,
            resolved_at=resolved,
            resolution_note=random.choice([
                "Falso positivo · contexto identificado",
                "Resuelto tras conversación",
                "Derivado a línea 089",
                "Patrón aislado · no se repitió",
            ]),
        )
        session.add(s)

    session.commit()


def seed_forum(session: Session) -> None:
    """Genera 30 huellas anónimas."""
    for i in range(30):
        case_id = f"#{random.randint(40, 300)}"
        fp = PatternFootprint(
            id=case_id,
            emojis=random.choice(FORUM_EMOJIS),
            phrases=random.choice(FORUM_PHRASES),
            platforms=random.choice(FORUM_PLATFORMS),
            approach=random.choice(FORUM_APPROACHES),
            time_window=random.choice(list(TimeWindow)),
            age_range=random.choice(list(AgeRange)),
            status=random.choices(
                [CaseStatus.resolved, CaseStatus.reviewed, CaseStatus.escalated, CaseStatus.pending],
                weights=[3, 3, 2, 1],
            )[0],
            match_count=random.randint(1, 25),
            summary=random.choice(FORUM_SUMMARIES),
            created_at=datetime.utcnow() - timedelta(days=random.randint(1, 120)),
        )
        # upsert manual: solo agrega si el ID no existe
        existing = session.exec(select(PatternFootprint).where(PatternFootprint.id == case_id)).first()
        if not existing:
            session.add(fp)
    session.commit()


def seed_threads(session: Session) -> None:
    """Genera 25 hilos comunitarios."""
    signal_filters = [
        "Transición TikTok → Discord",
        "Horario atípico nocturno",
        "Instalación reactiva Telegram",
        "Aislamiento digital",
        None, None,  # hilos sin filtro
    ]
    status_weights = [ThreadStatus.none, ThreadStatus.resolved, ThreadStatus.false_positive, ThreadStatus.urgent]

    for i in range(25):
        nickname = random.choice([
            "mamá_anónima", "papá_de_2", "tutora_reciente", "abuela_cuidadora",
            "madre_primeriza", "papá_programador", "tía_soltera", "padre_viudo",
            "mamá_adoptiva", "tutor_legal",
        ]) + f"_{random.randint(10, 99)}"
        initial = nickname[0].upper()

        age = random.choice([11, 12, 13, 14, 15, 16])
        title_tmpl = random.choice(THREAD_TITLES)
        title = title_tmpl.format(age=age) if "{age}" in title_tmpl else title_tmpl

        t = CommunityThread(
            author_nickname=nickname,
            author_initial=initial,
            title=title,
            preview=random.choice(THREAD_PREVIEWS),
            body=random.choice(THREAD_PREVIEWS) + " " + fake.paragraph(nb_sentences=3),
            replies_count=random.randint(0, 50),
            status_tag=random.choices(status_weights, weights=[4, 2, 1, 1])[0],
            signal_filter=random.choice(signal_filters),
            created_at=datetime.utcnow() - timedelta(days=random.randint(1, 21)),
        )
        session.add(t)
    session.commit()


def seed_voz_entries(session: Session, child_profiles: list[Profile]) -> None:
    """Genera 40 entries del buzón voz distribuidas entre los menores."""
    menors = [p for p in child_profiles if p.role == ProfileRole.child and p.case_id]
    if not menors:
        return
    for _ in range(40):
        menor = random.choice(menors)
        kind = random.choices(
            ["text", "voice", "photo", "file"],
            weights=[5, 2, 2, 1],
        )[0]
        text_content = random.choice(VOZ_ENTRIES_SAMPLE) if kind == "text" else None
        reviewed = random.random() < 0.6
        risk = random.choice(list(Severity)) if reviewed else None
        e = VozEntry(
            case_id=menor.case_id,
            kind=kind,
            text_content=text_content,
            weprotect_reviewed=reviewed,
            weprotect_risk=risk,
            contributed_to_forum=reviewed and random.random() < 0.3,
            created_at=datetime.utcnow() - timedelta(days=random.randint(0, 30), hours=random.randint(0, 23)),
        )
        session.add(e)
    session.commit()


def clear_all(session: Session) -> None:
    session.exec(delete(VozEntry))
    session.exec(delete(CommunityThread))
    session.exec(delete(PatternFootprint))
    session.exec(delete(Signal))
    session.exec(delete(ChildMonitor))
    session.exec(delete(Profile))
    session.commit()


# =============================================================================
# Main
# =============================================================================

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--append", action="store_true", help="No borra datos existentes")
    args = parser.parse_args()

    print("[seed] init db...")
    init_db()

    with Session(engine) as session:
        if not args.append:
            print("[seed] limpiando tablas...")
            clear_all(session)

        print("[seed] generando perfiles (3 padres + 2 menores)...")
        profiles, children = seed_profiles(session)

        print("[seed] generando señales (20 activas + 60 históricas)...")
        seed_signals(session, children)

        print("[seed] generando foro (30 huellas)...")
        seed_forum(session)

        print("[seed] generando comunidad (25 hilos)...")
        seed_threads(session)

        print("[seed] generando voz entries (40)...")
        seed_voz_entries(session, profiles)

        print("\n[seed] ✓ listo · ejecuta `uvicorn main:app --reload` para arrancar el backend")


if __name__ == "__main__":
    main()
