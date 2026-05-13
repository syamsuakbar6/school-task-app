import os
from collections.abc import Generator
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import text, create_engine
from sqlalchemy.orm import Session, declarative_base, sessionmaker, configure_mappers


BASE_DIR = Path(__file__).resolve().parents[2]
load_dotenv(BASE_DIR / ".env")


def _build_database_url() -> str:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL is not set. Add it to backend/.env before starting the app.")

    if database_url.startswith("postgresql://") and "+psycopg2" not in database_url:
        database_url = database_url.replace("postgresql://", "postgresql+psycopg2://", 1)

    return database_url


DATABASE_URL = _build_database_url()

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
)
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
    bind=engine,
)
Base = declarative_base()


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def check_database_connection(db: Session) -> dict[str, int | str]:
    db.execute(text("SELECT 1"))
    users_count = db.execute(text("SELECT COUNT(*) FROM users")).scalar_one()
    return {
        "status": "ok",
        "database": "connected",
        "users_count": int(users_count),
    }


# Import all models to register them with Base metadata
import app.models.user
import app.models.submission
import app.models.task
import app.models.grade
import app.models.class_model
import app.models.audit_log
import app.models.submission_state

# Eagerly resolve all relationships and mapper configurations
configure_mappers()
