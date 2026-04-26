"""
flux backend · engine SQLite + session dependency

SQLite local para simular el backend real. En producción sería PostgreSQL
en Render (ver CLAUDE.md del proyecto).
"""

from pathlib import Path
from sqlmodel import SQLModel, Session, create_engine

DB_PATH = Path(__file__).parent / "data" / "flux.db"
DB_PATH.parent.mkdir(exist_ok=True)

DATABASE_URL = f"sqlite:///{DB_PATH}"

engine = create_engine(
    DATABASE_URL,
    echo=False,
    connect_args={"check_same_thread": False},
)


def init_db() -> None:
    """Crea todas las tablas si no existen."""
    SQLModel.metadata.create_all(engine)


def get_session():
    """Dependency injection para FastAPI."""
    with Session(engine) as session:
        yield session
