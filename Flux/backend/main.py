"""
flux backend · FastAPI app

Simula el backend que la app iOS consume. Todo in-memory + SQLite local.
En producción esto vive en Render con PostgreSQL, Redis y Celery (ver CLAUDE.md).

Correr:
    uvicorn main:app --reload --host 0.0.0.0 --port 8000

Docs interactivas:
    http://localhost:8000/docs
"""

import base64
import os
import secrets
from datetime import datetime, timedelta
from uuid import UUID, uuid4
from typing import Optional

from fastapi import Depends, FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from sqlmodel import Session, select

from database import engine, get_session, init_db
from detectors import classify, run_detection
from models import (
    AnalyzeTextRequest, ApproachesRequest, ApproachesResponse,
    BaselineResponse, CaseStatus, ChildMonitor, CommunityThread,
    ConversationApproach, DetectionRunResponse, HealthResponse,
    PairingInvitation, PairingRequest, PatternFootprint, Profile,
    ProfileRole, RiskAnalysisResponse, RiskScoreResponse, Severity, Signal,
    SignalKind, UsageBatchRequest, UsageBatchResponse, UsageEvent,
    VozEntry, VozEntryCreate, WeProtectInsight,
)


# =============================================================================
# App setup
# =============================================================================

app = FastAPI(
    title="flux backend",
    description="API que alimenta la app iOS de flux · Hackathon 404 CDMX 2026",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # en prod: restringir a dominios de flux
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup() -> None:
    init_db()


# =============================================================================
# Health
# =============================================================================

@app.get("/api/v1/health", response_model=HealthResponse, tags=["system"])
def health(session: Session = Depends(get_session)) -> HealthResponse:
    profiles_count = len(session.exec(select(Profile)).all())
    signals_active = len(session.exec(select(Signal).where(Signal.is_active == True)).all())
    forum_cases = len(session.exec(select(PatternFootprint)).all())
    return HealthResponse(
        status="ok",
        timestamp=datetime.utcnow(),
        profiles_count=profiles_count,
        signals_active=signals_active,
        forum_cases=forum_cases,
    )


# =============================================================================
# Profiles
# =============================================================================

@app.get("/api/v1/profiles", response_model=list[Profile], tags=["profiles"])
def list_profiles(
    role: Optional[ProfileRole] = None,
    session: Session = Depends(get_session),
) -> list[Profile]:
    """Lista todos los perfiles registrados. Filtrar por rol con `?role=parent|child`."""
    stmt = select(Profile)
    if role is not None:
        stmt = stmt.where(Profile.role == role)
    return session.exec(stmt).all()


@app.get("/api/v1/profiles/{profile_id}", response_model=Profile, tags=["profiles"])
def get_profile(profile_id: UUID, session: Session = Depends(get_session)) -> Profile:
    profile = session.get(Profile, profile_id)
    if not profile:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "profile not found")
    return profile


@app.get(
    "/api/v1/profiles/{profile_id}/children",
    response_model=list[ChildMonitor],
    tags=["profiles"],
)
def list_monitored_children(
    profile_id: UUID,
    session: Session = Depends(get_session),
) -> list[ChildMonitor]:
    """Lista los menores que este padre monitorea."""
    stmt = select(ChildMonitor).where(ChildMonitor.parent_profile_id == profile_id)
    return session.exec(stmt).all()


# =============================================================================
# Risk score + signals (modo padre)
# =============================================================================

@app.get(
    "/api/v1/children/{child_id}/risk-score",
    response_model=RiskScoreResponse,
    tags=["risk"],
)
def get_risk_score(child_id: UUID, session: Session = Depends(get_session)) -> RiskScoreResponse:
    """Score 0-100 del menor + tendencia de 7 días."""
    signals = session.exec(
        select(Signal).where(Signal.child_id == child_id, Signal.is_active == True)
    ).all()

    weights = {Severity.low: 8, Severity.medium: 22, Severity.high: 38}
    raw = sum(weights.get(s.severity, 0) * s.confidence for s in signals)
    value = max(0, min(100, int(raw)))

    band = "safe" if value < 30 else ("moderate" if value < 65 else "elevated")

    # Generar tendencia de 7 días (con el valor actual al final)
    trend = [max(0, value - (6 - i) * 9 + (hash(str(child_id)) % 5)) for i in range(7)]
    trend[-1] = value

    return RiskScoreResponse(
        value=value,
        band=band,
        trend_7d=[float(x) for x in trend],
        active_signal_count=len(signals),
        last_updated=datetime.utcnow(),
    )


@app.get(
    "/api/v1/children/{child_id}/signals",
    response_model=list[Signal],
    tags=["risk"],
)
def list_signals(
    child_id: UUID,
    active: Optional[bool] = Query(True, description="True=activas, False=histórico"),
    limit: int = Query(50, le=200),
    session: Session = Depends(get_session),
) -> list[Signal]:
    stmt = select(Signal).where(Signal.child_id == child_id)
    if active is not None:
        stmt = stmt.where(Signal.is_active == active)
    stmt = stmt.order_by(Signal.detected_at.desc()).limit(limit)
    return session.exec(stmt).all()


@app.get("/api/v1/signals/{signal_id}", response_model=Signal, tags=["risk"])
def get_signal(signal_id: UUID, session: Session = Depends(get_session)) -> Signal:
    s = session.get(Signal, signal_id)
    if not s:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "signal not found")
    return s


@app.post(
    "/api/v1/signals/{signal_id}/resolve",
    response_model=Signal,
    tags=["risk"],
)
def resolve_signal(
    signal_id: UUID,
    note: str = Query("Revisado por el padre"),
    session: Session = Depends(get_session),
) -> Signal:
    s = session.get(Signal, signal_id)
    if not s:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "signal not found")
    s.is_active = False
    s.resolved_at = datetime.utcnow()
    s.resolution_note = note
    session.add(s)
    session.commit()
    session.refresh(s)
    return s


@app.get(
    "/api/v1/children/{child_id}/baseline",
    response_model=BaselineResponse,
    tags=["risk"],
)
def get_baseline(child_id: UUID, session: Session = Depends(get_session)) -> BaselineResponse:
    """Línea base del menor · 'día normal'."""
    cm = session.get(ChildMonitor, child_id)
    if not cm:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "child not found")

    # Mock determinístico basado en el UUID del menor
    seed = abs(hash(str(child_id))) % 10
    hourly = [
        0, 0, 0, 0, 0, 0,
        5 + seed, 12, 28, 15, 10, 18,
        22, 35, 30, 24, 20, 25 + seed,
        40, 55, 42, 30 + seed, 18, 8,
    ]
    top_apps = [
        {"name": app, "icon": "play.rectangle.fill", "minutes": random_minutes(i, seed)}
        for i, app in enumerate(cm.baseline_apps[:5])
    ]
    return BaselineResponse(
        child_id=child_id,
        hourly_usage_minutes=[float(h) for h in hourly],
        top_apps=top_apps,
        days_of_data=30,
        observation="Los últimos 30 días su patrón ha sido estable. El cambio reciente es lo que genera alerta.",
    )


def random_minutes(i: int, seed: int) -> int:
    base = [134, 62, 48, 32, 24]
    return base[i % len(base)] + seed


# =============================================================================
# WeProtect · análisis AI
# =============================================================================

HIGH_PATTERNS = {
    "no le digas a tu": ("Secreto explícito ante padres", 3),
    "no le digas a nadie": ("Aislamiento por secreto", 3),
    "mándame fotos": ("Solicitud de imágenes · grooming", 1),
    "mi amor": ("Elogio romántico inapropiado", 1),
    "tengo un regalo": ("Oferta engañosa", 1),
    "dónde vives": ("Solicitud de ubicación", 1),
    "es sorpresa": ("Secreto explícito ante padres", 3),
}

MEDIUM_PATTERNS = {
    "robux": ("Oferta económica virtual", 1),
    "dinero": ("Oferta económica", 1),
    "tú y yo": ("Compromiso falso", 3),
    "algo especial": ("Compromiso falso", 3),
}


@app.post(
    "/api/v1/weprotect/analyze",
    response_model=RiskAnalysisResponse,
    tags=["weprotect"],
)
def analyze_text(req: AnalyzeTextRequest) -> RiskAnalysisResponse:
    """Analiza texto y detecta patrones de riesgo (simula Foundation Models on-device)."""
    text = req.text.lower()
    insights: list[WeProtectInsight] = []
    matched_forum: list[str] = []

    for trigger, (pattern, pillar) in HIGH_PATTERNS.items():
        if trigger in text:
            insights.append(WeProtectInsight(
                pattern=pattern,
                excerpt=extract_excerpt(req.text, trigger),
                severity=Severity.high,
                pillar=pillar,
            ))
            matched_forum.append(f"#{hash(trigger) % 150 + 40}")

    for trigger, (pattern, pillar) in MEDIUM_PATTERNS.items():
        if trigger in text:
            insights.append(WeProtectInsight(
                pattern=pattern,
                excerpt=extract_excerpt(req.text, trigger),
                severity=Severity.medium,
                pillar=pillar,
            ))

    if any(i.severity == Severity.high for i in insights):
        overall = Severity.high
    elif any(i.severity == Severity.medium for i in insights):
        overall = Severity.medium
    else:
        overall = Severity.low

    confidence = min(0.95, 0.7 + 0.05 * len(insights))

    return RiskAnalysisResponse(
        overall_risk=overall,
        confidence=confidence,
        insights=insights,
        matches_forum_patterns=list(set(matched_forum)),
        backend_used="rules",  # en app iOS real usa Foundation Models si está disponible
    )


def extract_excerpt(text: str, trigger: str, window: int = 30) -> str:
    idx = text.lower().find(trigger)
    if idx < 0:
        return trigger
    start = max(0, idx - window)
    end = min(len(text), idx + len(trigger) + window)
    prefix = "" if start == 0 else "…"
    suffix = "" if end == len(text) else "…"
    return prefix + text[start:end].strip() + suffix


@app.post(
    "/api/v1/weprotect/approaches",
    response_model=ApproachesResponse,
    tags=["weprotect"],
)
def generate_approaches(req: ApproachesRequest) -> ApproachesResponse:
    """Genera 3 abordajes de conversación para el padre."""
    name = req.child_name
    return ApproachesResponse(
        approaches=[
            ConversationApproach(
                label="Opción 1 · Directa",
                estimated_time="3 min",
                script=f"Oye, {name}, vi que has estado usando Discord de noche. No quiero invadir tu espacio, pero me preocupa que no duermas bien. ¿Todo OK con las personas con las que hablas ahí?",
                tags=["sin acusar", "cuidado"],
            ),
            ConversationApproach(
                label="Opción 2 · Contexto",
                estimated_time="5 min",
                script=f"Leí algo sobre cómo mucha gente nueva se conoce por Discord ahora. ¿Tú cómo lo usas, {name}? Me gustaría entenderlo...",
                tags=["curiosidad", "apertura"],
            ),
            ConversationApproach(
                label="Opción 3 · Espejo",
                estimated_time="2 min",
                script=f"Yo también me desvelo viendo videos. Me gustó mucho este de X. ¿Qué ves tú a esa hora, {name}?",
                tags=["vínculo", "ligero"],
            ),
        ],
        backend_used="rules",
    )


# =============================================================================
# Ingesta de eventos + detección (agente iOS → backend)
# =============================================================================

@app.post(
    "/api/v1/children/{child_id}/events",
    response_model=UsageBatchResponse,
    tags=["ingest"],
    status_code=status.HTTP_201_CREATED,
)
def ingest_events(
    child_id: UUID,
    batch: UsageBatchRequest,
    run_detectors: bool = Query(True, description="Correr detectores tras ingestar"),
    session: Session = Depends(get_session),
) -> UsageBatchResponse:
    """
    Recibe un batch de eventos desde el agente iOS (DeviceActivityMonitor).
    Clasifica la categoría si no vino, persiste, y opcionalmente corre detectores.
    """
    if not session.get(ChildMonitor, child_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "child not found")

    for ev in batch.events:
        session.add(UsageEvent(
            child_id=child_id,
            kind=ev.kind,
            app_bundle=ev.app_bundle,
            app_name=ev.app_name,
            category=ev.category or classify(ev.app_bundle),
            ts=ev.ts,
            duration_s=ev.duration_s,
        ))
    session.commit()

    new_signals = run_detection(session, child_id) if run_detectors else []
    return UsageBatchResponse(
        accepted=len(batch.events),
        signals_generated=len(new_signals),
        signal_ids=[s.id for s in new_signals],
    )


@app.post(
    "/api/v1/children/{child_id}/detect",
    response_model=DetectionRunResponse,
    tags=["ingest"],
)
def trigger_detection(
    child_id: UUID,
    lookback_days: int = Query(14, ge=1, le=60),
    session: Session = Depends(get_session),
) -> DetectionRunResponse:
    """Corre detectores manualmente sobre los eventos ya almacenados del menor."""
    if not session.get(ChildMonitor, child_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "child not found")

    events_scanned = len(session.exec(
        select(UsageEvent).where(UsageEvent.child_id == child_id)
    ).all())
    new_signals = run_detection(session, child_id, lookback_days=lookback_days)
    return DetectionRunResponse(
        child_id=child_id,
        events_scanned=events_scanned,
        signals_generated=len(new_signals),
        signal_ids=[s.id for s in new_signals],
    )


@app.get(
    "/api/v1/children/{child_id}/events",
    response_model=list[UsageEvent],
    tags=["ingest"],
)
def list_events(
    child_id: UUID,
    limit: int = Query(200, le=1000),
    session: Session = Depends(get_session),
) -> list[UsageEvent]:
    stmt = (
        select(UsageEvent)
        .where(UsageEvent.child_id == child_id)
        .order_by(UsageEvent.ts.desc())
        .limit(limit)
    )
    return session.exec(stmt).all()


# =============================================================================
# Forum (huellas anónimas)
# =============================================================================

@app.get("/api/v1/forum/footprints", response_model=list[PatternFootprint], tags=["forum"])
def list_footprints(
    platform: Optional[str] = None,
    status_filter: Optional[CaseStatus] = Query(None, alias="status"),
    limit: int = Query(50, le=200),
    session: Session = Depends(get_session),
) -> list[PatternFootprint]:
    """Lista huellas anónimas del foro."""
    stmt = select(PatternFootprint)
    if status_filter is not None:
        stmt = stmt.where(PatternFootprint.status == status_filter)
    stmt = stmt.order_by(PatternFootprint.match_count.desc()).limit(limit)
    result = session.exec(stmt).all()
    if platform:
        result = [fp for fp in result if platform in fp.platforms]
    return result


@app.get("/api/v1/forum/footprints/{footprint_id}", response_model=PatternFootprint, tags=["forum"])
def get_footprint(footprint_id: str, session: Session = Depends(get_session)) -> PatternFootprint:
    fp = session.get(PatternFootprint, footprint_id)
    if not fp:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "footprint not found")
    return fp


@app.post(
    "/api/v1/forum/footprints/{footprint_id}/me-too",
    response_model=PatternFootprint,
    tags=["forum"],
)
def mark_me_too(footprint_id: str, session: Session = Depends(get_session)) -> PatternFootprint:
    """'me pasó también' — incrementa el contador anónimo."""
    fp = session.get(PatternFootprint, footprint_id)
    if not fp:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "footprint not found")
    fp.match_count += 1
    session.add(fp)
    session.commit()
    session.refresh(fp)
    return fp


# =============================================================================
# Community threads
# =============================================================================

@app.get("/api/v1/community/threads", response_model=list[CommunityThread], tags=["community"])
def list_threads(
    signal_filter: Optional[str] = None,
    limit: int = Query(50, le=200),
    session: Session = Depends(get_session),
) -> list[CommunityThread]:
    stmt = select(CommunityThread)
    if signal_filter is not None:
        stmt = stmt.where(CommunityThread.signal_filter == signal_filter)
    stmt = stmt.order_by(CommunityThread.created_at.desc()).limit(limit)
    return session.exec(stmt).all()


@app.get("/api/v1/community/threads/{thread_id}", response_model=CommunityThread, tags=["community"])
def get_thread(thread_id: UUID, session: Session = Depends(get_session)) -> CommunityThread:
    t = session.get(CommunityThread, thread_id)
    if not t:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "thread not found")
    return t


# =============================================================================
# Voz · buzón silencioso (modo menor)
# =============================================================================

@app.get("/api/v1/voz/{case_id}/entries", response_model=list[VozEntry], tags=["voz"])
def list_voz_entries(
    case_id: UUID,
    limit: int = Query(50, le=200),
    session: Session = Depends(get_session),
) -> list[VozEntry]:
    stmt = select(VozEntry).where(VozEntry.case_id == case_id)
    stmt = stmt.order_by(VozEntry.created_at.desc()).limit(limit)
    return session.exec(stmt).all()


@app.post("/api/v1/voz/{case_id}/entries", response_model=VozEntry, tags=["voz"])
def create_voz_entry(
    case_id: UUID,
    req: VozEntryCreate,
    session: Session = Depends(get_session),
) -> VozEntry:
    """El menor guarda una entrada en su buzón. Optionally pide review de WeProtect."""
    risk = None
    reviewed = False
    if req.request_weprotect_review and req.text_content:
        analysis = analyze_text(AnalyzeTextRequest(text=req.text_content, source="voz-buzon"))
        risk = analysis.overall_risk
        reviewed = True

    entry = VozEntry(
        case_id=case_id,
        kind=req.kind,
        text_content=req.text_content,
        weprotect_reviewed=reviewed,
        weprotect_risk=risk,
    )
    session.add(entry)
    session.commit()
    session.refresh(entry)
    return entry


# =============================================================================
# Pairing · invitación flux voz (NearbyInteraction + BLE en el device)
# =============================================================================

@app.post("/api/v1/pairing/invitation", response_model=PairingInvitation, tags=["pairing"])
def create_pairing_invitation(req: PairingRequest) -> PairingInvitation:
    """
    Genera una invitación firmada para pairing por proximidad.
    En producción el payload lo genera el device del padre localmente y
    lo envía al menor por BLE + UWB. Este endpoint es para tracking del
    backend si queremos analítica de uso.
    """
    shared_secret = secrets.token_bytes(32)
    now = datetime.utcnow()
    return PairingInvitation(
        invitation_id=uuid4(),
        parent_device_name="iPhone de " + req.child_name[:5],
        child_name=req.child_name,
        child_age=req.child_age,
        case_id=uuid4(),
        shared_secret_b64=base64.b64encode(shared_secret).decode(),
        issued_at=now,
        expires_at=now + timedelta(minutes=2),
    )


# =============================================================================
# Root
# =============================================================================

@app.get("/", tags=["system"])
def root() -> dict:
    return {
        "service": "flux backend",
        "docs": "/docs",
        "health": "/api/v1/health",
    }
