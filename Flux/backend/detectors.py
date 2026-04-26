"""
flux backend · detectores de comportamiento

Leen `UsageEvent`s del menor y generan `Signal`s accionables para el padre.
Cada detector es una función pura que recibe (child_id, eventos recientes, baseline)
y devuelve una lista de Signals nuevos.

Reglas implementadas (v0):
    1. atypical_hours      · uso sostenido entre 00:00–06:00
    2. platform_transition · alternancia gaming ↔ chat ≥3 veces en 1h
    3. reactive_install    · aparición de app en categoría sensible no vista antes
    4. digital_isolation   · caída >50% de uso social vs 7d previos

Añadir detectores nuevos: escribir una función `detect_*` y registrarla en ALL_DETECTORS.
"""

from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timedelta
from typing import Callable
from uuid import UUID, uuid4

from sqlmodel import Session, select

from models import (
    AppCategory, ChildMonitor, Severity, Signal, SignalKind,
    UsageEvent, UsageEventKind,
)


# =============================================================================
# Catálogo bundle_id → categoría
# =============================================================================
# En producción esto vive en una tabla o se carga de Cisco Umbrella / lista propia.
# Mantener corto y conservador: si no está, cae a AppCategory.other.

BUNDLE_CATEGORY: dict[str, AppCategory] = {
    # gaming
    "com.roblox.client": AppCategory.gaming,
    "com.innersloth.amongus": AppCategory.gaming,
    "com.mojang.minecraftpe": AppCategory.gaming,
    "com.epicgames.fortnite": AppCategory.gaming,
    # chat
    "com.hammerandchisel.discord": AppCategory.chat,
    "ph.telegra.Telegraph": AppCategory.chat,
    "net.whatsapp.WhatsApp": AppCategory.chat,
    "com.toyopagroup.picaboo": AppCategory.chat,  # Snapchat
    # social
    "com.zhiliaoapp.musically": AppCategory.social,  # TikTok
    "com.burbn.instagram": AppCategory.social,
    "com.atebits.Tweetie2": AppCategory.social,     # X/Twitter
    # video
    "com.google.ios.youtube": AppCategory.video,
    "com.netflix.Netflix": AppCategory.video,
    # vpn (evasión)
    "ch.protonvpn.ios": AppCategory.vpn,
    "com.nordvpn.NordVPN": AppCategory.vpn,
    "com.expressvpn.ExpressVpn": AppCategory.vpn,
}

SENSITIVE_NEW_APP_CATEGORIES = {AppCategory.chat, AppCategory.adult, AppCategory.vpn}


def classify(bundle_id: str) -> AppCategory:
    return BUNDLE_CATEGORY.get(bundle_id, AppCategory.other)


# =============================================================================
# Helpers
# =============================================================================

def _recent_events(
    session: Session, child_id: UUID, since: datetime,
) -> list[UsageEvent]:
    stmt = (
        select(UsageEvent)
        .where(UsageEvent.child_id == child_id, UsageEvent.ts >= since)
        .order_by(UsageEvent.ts)
    )
    return list(session.exec(stmt).all())


def _mk_signal(
    child_id: UUID,
    kind: SignalKind,
    severity: Severity,
    title: str,
    summary: str,
    confidence: float,
    pattern_id: str,
) -> Signal:
    return Signal(
        id=uuid4(),
        child_id=child_id,
        kind=kind,
        severity=severity,
        title=title,
        summary=summary,
        pattern_id=pattern_id,
        confidence=confidence,
        detected_at=datetime.utcnow(),
        is_active=True,
    )


# =============================================================================
# Detectores
# =============================================================================

def detect_atypical_hours(
    session: Session, child_id: UUID, events: list[UsageEvent],
) -> list[Signal]:
    """Uso sostenido en ventana nocturna 00:00–06:00 en las últimas 24h."""
    nightly_minutes = sum(
        e.duration_s / 60
        for e in events
        if e.kind == UsageEventKind.session_end
        and 0 <= e.ts.hour < 6
        and e.ts >= datetime.utcnow() - timedelta(hours=24)
    )
    if nightly_minutes < 30:
        return []

    severity = Severity.high if nightly_minutes >= 90 else Severity.medium
    return [_mk_signal(
        child_id=child_id,
        kind=SignalKind.atypical_hours,
        severity=severity,
        title="Uso nocturno inusual",
        summary=f"{int(nightly_minutes)} min de uso entre 00:00 y 06:00 en las últimas 24h.",
        confidence=min(0.95, 0.6 + nightly_minutes / 300),
        pattern_id="P-01",
    )]


def detect_platform_transition(
    session: Session, child_id: UUID, events: list[UsageEvent],
) -> list[Signal]:
    """Alternancia gaming ↔ chat ≥3 veces en una ventana de 60 min."""
    starts = [
        e for e in events
        if e.kind == UsageEventKind.session_start
        and e.category in (AppCategory.gaming, AppCategory.chat)
        and e.ts >= datetime.utcnow() - timedelta(hours=3)
    ]
    if len(starts) < 4:
        return []

    # contar transiciones gaming↔chat dentro de cualquier ventana de 60 min
    max_transitions = 0
    for i, anchor in enumerate(starts):
        window = [e for e in starts[i:] if e.ts - anchor.ts <= timedelta(minutes=60)]
        transitions = sum(
            1 for a, b in zip(window, window[1:]) if a.category != b.category
        )
        max_transitions = max(max_transitions, transitions)

    if max_transitions < 3:
        return []

    return [_mk_signal(
        child_id=child_id,
        kind=SignalKind.platform_transition,
        severity=Severity.high,
        title="Alternancia juego ↔ chat",
        summary=f"{max_transitions} saltos entre juego y chat en menos de 1h. Patrón asociado a contacto externo activo.",
        confidence=0.8,
        pattern_id="P-07",
    )]


def detect_reactive_install(
    session: Session, child_id: UUID, events: list[UsageEvent],
) -> list[Signal]:
    """Instalación de app en categoría sensible no presente en baseline."""
    child = session.get(ChildMonitor, child_id)
    if not child:
        return []
    baseline_bundles = set(child.baseline_apps or [])

    fresh_installs = [
        e for e in events
        if e.kind == UsageEventKind.app_install
        and e.category in SENSITIVE_NEW_APP_CATEGORIES
        and e.app_bundle not in baseline_bundles
        and e.ts >= datetime.utcnow() - timedelta(days=7)
    ]
    signals = []
    for e in fresh_installs:
        severity = Severity.high if e.category == AppCategory.vpn else Severity.medium
        signals.append(_mk_signal(
            child_id=child_id,
            kind=SignalKind.reactive_install,
            severity=severity,
            title=f"App nueva · {e.app_name}",
            summary=f"{e.app_name} ({e.category.value}) se instaló recientemente y no estaba en su baseline.",
            confidence=0.9,
            pattern_id="P-12",
        ))
    return signals


def detect_digital_isolation(
    session: Session, child_id: UUID, events: list[UsageEvent],
) -> list[Signal]:
    """Caída >50% de uso social (minutos/día) comparando últimos 3d vs 7d previos."""
    now = datetime.utcnow()
    last_3d_start = now - timedelta(days=3)
    prior_7d_start = now - timedelta(days=10)

    mins = defaultdict(float)
    for e in events:
        if e.kind != UsageEventKind.session_end or e.category != AppCategory.social:
            continue
        if prior_7d_start <= e.ts < last_3d_start:
            mins["prior"] += e.duration_s / 60
        elif e.ts >= last_3d_start:
            mins["recent"] += e.duration_s / 60

    prior_avg = mins["prior"] / 7
    recent_avg = mins["recent"] / 3
    if prior_avg < 15 or recent_avg >= prior_avg * 0.5:
        return []

    drop_pct = int((1 - recent_avg / prior_avg) * 100)
    return [_mk_signal(
        child_id=child_id,
        kind=SignalKind.digital_isolation,
        severity=Severity.medium,
        title="Caída en uso social",
        summary=f"Uso de apps sociales bajó {drop_pct}% vs. las 2 semanas previas.",
        confidence=0.75,
        pattern_id="P-18",
    )]


# =============================================================================
# Runner
# =============================================================================

Detector = Callable[[Session, UUID, list[UsageEvent]], list[Signal]]

ALL_DETECTORS: list[Detector] = [
    detect_atypical_hours,
    detect_platform_transition,
    detect_reactive_install,
    detect_digital_isolation,
]


def run_detection(
    session: Session, child_id: UUID, lookback_days: int = 14,
) -> list[Signal]:
    """
    Corre todos los detectores sobre los eventos recientes del menor y
    persiste cualquier Signal nuevo. Devuelve los Signals creados.
    """
    since = datetime.utcnow() - timedelta(days=lookback_days)
    events = _recent_events(session, child_id, since)
    if not events:
        return []

    # deduplicar: no crear una Signal igual si ya hay una activa del mismo pattern_id en 24h
    existing_active = session.exec(
        select(Signal).where(
            Signal.child_id == child_id,
            Signal.is_active == True,
            Signal.detected_at >= datetime.utcnow() - timedelta(hours=24),
        )
    ).all()
    recent_patterns = {s.pattern_id for s in existing_active}

    created: list[Signal] = []
    for detector in ALL_DETECTORS:
        for sig in detector(session, child_id, events):
            if sig.pattern_id in recent_patterns:
                continue
            session.add(sig)
            created.append(sig)
            recent_patterns.add(sig.pattern_id)

    if created:
        session.commit()
        for s in created:
            session.refresh(s)
    return created
