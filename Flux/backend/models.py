"""
flux backend · schemas y modelos de datos

Define la forma de los datos que viajan entre backend y app iOS.
Los modelos `*Model` son tablas (persistencia). Los modelos `*Schema` son
para serialización API (request/response).
"""

from datetime import datetime
from enum import Enum
from typing import Optional
from uuid import UUID, uuid4

from pydantic import BaseModel, Field as PyField
from sqlmodel import Field, SQLModel, Column, JSON


# =============================================================================
# Enums
# =============================================================================

class ProfileRole(str, Enum):
    parent = "parent"
    child = "child"


class SignalKind(str, Enum):
    platform_transition = "platform_transition"
    atypical_hours = "atypical_hours"
    reactive_install = "reactive_install"
    digital_isolation = "digital_isolation"
    grooming_pattern = "grooming_pattern"


class Severity(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"


class CaseStatus(str, Enum):
    pending = "pending"
    reviewed = "reviewed"
    escalated = "escalated"
    resolved = "resolved"


class ThreadStatus(str, Enum):
    none = "none"
    resolved = "resolved"
    false_positive = "false_positive"
    urgent = "urgent"


class TimeWindow(str, Enum):
    morning = "morning"
    afternoon = "afternoon"
    night = "night"
    late_night = "late_night"


class AgeRange(str, Enum):
    preteen = "10-12"
    early_teen = "13-15"
    late_teen = "16-17"


class AppCategory(str, Enum):
    """Categoría funcional a la que pertenece una app."""
    gaming = "gaming"
    chat = "chat"
    social = "social"
    video = "video"
    adult = "adult"
    vpn = "vpn"
    education = "education"
    productivity = "productivity"
    other = "other"


class UsageEventKind(str, Enum):
    session_start = "session_start"
    session_end = "session_end"
    app_install = "app_install"
    app_uninstall = "app_uninstall"
    threshold_hit = "threshold_hit"


# =============================================================================
# DB Models (SQLModel tables)
# =============================================================================

class Profile(SQLModel, table=True):
    """Perfil de usuario: padre o menor."""
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    role: ProfileRole
    display_name: str
    avatar_color: str                       # hex "#0F766E"
    biometric_enabled: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)

    # Para padres: lista de IDs de los menores que monitorea
    monitored_child_ids: list[str] = Field(default_factory=list, sa_column=Column(JSON))

    # Para menores: ID del caso y nombre del padre vinculado
    case_id: Optional[UUID] = None
    paired_with_parent_name: Optional[str] = None


class ChildMonitor(SQLModel, table=True):
    """Datos del menor que un padre monitorea (línea base + metadata)."""
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    parent_profile_id: UUID = Field(foreign_key="profile.id")
    name: str
    age: int
    baseline_apps: list[str] = Field(default_factory=list, sa_column=Column(JSON))
    created_at: datetime = Field(default_factory=datetime.utcnow)


class UsageEvent(SQLModel, table=True):
    """
    Evento crudo de uso emitido por el agente iOS (DeviceActivityMonitor).
    El detector consume estos eventos y genera `Signal`s.
    """
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    child_id: UUID = Field(foreign_key="childmonitor.id", index=True)
    kind: UsageEventKind
    app_bundle: str                         # ej. "com.roblox.client"
    app_name: str                           # ej. "Roblox"
    category: AppCategory
    ts: datetime = Field(index=True)        # momento del evento (hora local del device)
    duration_s: int = 0                     # solo para session_end
    ingested_at: datetime = Field(default_factory=datetime.utcnow)


class Signal(SQLModel, table=True):
    """Señal de comportamiento detectada por flux."""
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    child_id: UUID = Field(foreign_key="childmonitor.id")
    kind: SignalKind
    severity: Severity
    title: str
    summary: str
    pattern_id: str                         # ej. "P-07"
    confidence: float
    detected_at: datetime
    is_active: bool = True                  # vs histórico resuelto
    resolved_at: Optional[datetime] = None
    resolution_note: Optional[str] = None


class PatternFootprint(SQLModel, table=True):
    """Huella anónima en el foro · sin nombres, sin identidades."""
    id: str = Field(primary_key=True)       # "#47", "#62" — legible
    emojis: list[str] = Field(default_factory=list, sa_column=Column(JSON))
    phrases: list[str] = Field(default_factory=list, sa_column=Column(JSON))
    platforms: list[str] = Field(default_factory=list, sa_column=Column(JSON))
    approach: list[str] = Field(default_factory=list, sa_column=Column(JSON))
    time_window: TimeWindow
    age_range: AgeRange
    status: CaseStatus
    match_count: int = 0                    # "me pasó también: N"
    summary: str
    created_at: datetime = Field(default_factory=datetime.utcnow)


class CommunityThread(SQLModel, table=True):
    """Hilo anónimo de padres."""
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    author_nickname: str                    # anonimizado: mamá_anónima_47
    author_initial: str
    title: str
    preview: str
    body: str
    replies_count: int = 0
    status_tag: ThreadStatus = ThreadStatus.none
    signal_filter: Optional[str] = None     # tipo de señal que filtra
    created_at: datetime = Field(default_factory=datetime.utcnow)


class VozEntry(SQLModel, table=True):
    """Entrada guardada por un menor en su buzón silencioso."""
    id: UUID = Field(default_factory=uuid4, primary_key=True)
    case_id: UUID                           # del perfil menor
    kind: str                               # text / voice / photo / file / drawing
    text_content: Optional[str] = None
    weprotect_reviewed: bool = False
    weprotect_risk: Optional[Severity] = None
    contributed_to_forum: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)


# =============================================================================
# API Schemas (request / response)
# =============================================================================

class RiskScoreResponse(BaseModel):
    """Respuesta del endpoint /risk-score."""
    value: int                              # 0-100
    band: str                               # safe / moderate / elevated
    trend_7d: list[float]                   # puntos para sparkline
    active_signal_count: int
    last_updated: datetime


class WeProtectInsight(BaseModel):
    pattern: str                            # "grooming · solicitud de imágenes"
    excerpt: str                            # fragmento del texto
    severity: Severity
    pillar: int = PyField(..., ge=1, le=4)  # pilar de la convocatoria


class RiskAnalysisResponse(BaseModel):
    """Análisis WeProtect de un texto."""
    overall_risk: Severity
    confidence: float
    insights: list[WeProtectInsight]
    matches_forum_patterns: list[str]
    backend_used: str                       # "foundation_models" | "rules"


class AnalyzeTextRequest(BaseModel):
    text: str
    source: str = "scanner"                 # scanner / voz-buzon / manual


class ConversationApproach(BaseModel):
    label: str
    estimated_time: str                     # "3 min"
    script: str
    tags: list[str]


class ApproachesRequest(BaseModel):
    child_name: str
    child_age: int
    context: str


class ApproachesResponse(BaseModel):
    approaches: list[ConversationApproach]
    backend_used: str


class BaselineResponse(BaseModel):
    """Línea base del menor — 'día normal'."""
    child_id: UUID
    hourly_usage_minutes: list[float]       # 24 horas
    top_apps: list[dict]                    # [{name, icon, minutes}]
    days_of_data: int
    observation: str


class VozEntryCreate(BaseModel):
    kind: str
    text_content: Optional[str] = None
    request_weprotect_review: bool = False


class PairingRequest(BaseModel):
    """Request del padre para generar una invitación de pairing."""
    parent_profile_id: UUID
    child_name: str
    child_age: int


class PairingInvitation(BaseModel):
    """Respuesta con la invitación firmada para el menor."""
    invitation_id: UUID
    parent_device_name: str
    child_name: str
    child_age: int
    case_id: UUID
    shared_secret_b64: str                  # 32 bytes base64
    issued_at: datetime
    expires_at: datetime


class UsageEventIn(BaseModel):
    """Payload de un evento individual que manda el agente iOS."""
    kind: UsageEventKind
    app_bundle: str
    app_name: str
    category: Optional[AppCategory] = None  # si no viene, el backend clasifica
    ts: datetime
    duration_s: int = 0


class UsageBatchRequest(BaseModel):
    """El agente iOS envía eventos en lotes (batch) para ahorrar batería."""
    events: list[UsageEventIn]


class UsageBatchResponse(BaseModel):
    accepted: int
    signals_generated: int
    signal_ids: list[UUID]


class DetectionRunResponse(BaseModel):
    child_id: UUID
    events_scanned: int
    signals_generated: int
    signal_ids: list[UUID]


class HealthResponse(BaseModel):
    status: str
    service: str = "flux-backend"
    version: str = "0.1.0"
    timestamp: datetime
    profiles_count: int
    signals_active: int
    forum_cases: int
