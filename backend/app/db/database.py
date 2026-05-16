import os
from collections.abc import Generator
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import inspect, text, create_engine
from sqlalchemy.orm import Session, declarative_base, sessionmaker, configure_mappers

from app.utils.academic_year_utils import default_academic_year_name


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


def ensure_production_schema() -> None:
    """
    Lightweight forward-only schema guard for deployments without Alembic.
    Safe to run repeatedly during Railway startup.
    """
    inspector = inspect(engine)
    existing_tables = set(inspector.get_table_names())
    existing_columns = (
        {column["name"] for column in inspector.get_columns("classes")}
        if "classes" in existing_tables
        else set()
    )
    existing_user_columns = (
        {column["name"] for column in inspector.get_columns("users")}
        if "users" in existing_tables
        else set()
    )
    with engine.begin() as connection:
        if "is_alumni" not in existing_user_columns:
            connection.execute(
                text(
                    "ALTER TABLE users "
                    "ADD COLUMN is_alumni BOOLEAN NOT NULL DEFAULT FALSE"
                )
            )
            connection.execute(
                text(
                    "CREATE INDEX IF NOT EXISTS ix_users_is_alumni "
                    "ON users (is_alumni)"
                )
            )
        if "alumni_at" not in existing_user_columns:
            connection.execute(
                text("ALTER TABLE users ADD COLUMN alumni_at TIMESTAMP NULL")
            )

        connection.execute(
            text(
                "CREATE TABLE IF NOT EXISTS academic_years ("
                "id SERIAL PRIMARY KEY, "
                "name VARCHAR NOT NULL UNIQUE, "
                "starts_at DATE NULL, "
                "ends_at DATE NULL, "
                "is_active BOOLEAN NOT NULL DEFAULT FALSE, "
                "created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP"
                ")"
            )
        )
        if "is_archived" not in existing_columns:
            connection.execute(
                text(
                    "ALTER TABLE classes "
                    "ADD COLUMN is_archived BOOLEAN NOT NULL DEFAULT FALSE"
                )
            )
        if "archived_at" not in existing_columns:
            connection.execute(
                text(
                    "ALTER TABLE classes "
                    "ADD COLUMN archived_at TIMESTAMP NULL"
                )
            )
        if "grade_level" not in existing_columns:
            connection.execute(
                text("ALTER TABLE classes ADD COLUMN grade_level VARCHAR NULL")
            )
            connection.execute(
                text(
                    "CREATE INDEX IF NOT EXISTS ix_classes_grade_level "
                    "ON classes (grade_level)"
                )
            )
        if "major" not in existing_columns:
            connection.execute(
                text("ALTER TABLE classes ADD COLUMN major VARCHAR NULL")
            )
            connection.execute(
                text(
                    "CREATE INDEX IF NOT EXISTS ix_classes_major "
                    "ON classes (major)"
                )
            )
        if "section" not in existing_columns:
            connection.execute(
                text("ALTER TABLE classes ADD COLUMN section VARCHAR NULL")
            )
        if "academic_year_id" not in existing_columns:
            connection.execute(
                text(
                    "ALTER TABLE classes "
                    "ADD COLUMN academic_year_id INTEGER NULL"
                )
            )
            connection.execute(
                text(
                    "CREATE INDEX IF NOT EXISTS ix_classes_academic_year_id "
                    "ON classes (academic_year_id)"
                )
            )
            connection.execute(
                text(
                    "DO $$ BEGIN "
                    "IF NOT EXISTS ("
                    "SELECT 1 FROM pg_constraint "
                    "WHERE conname = 'fk_classes_academic_year_id'"
                    ") THEN "
                    "ALTER TABLE classes ADD CONSTRAINT fk_classes_academic_year_id "
                    "FOREIGN KEY (academic_year_id) REFERENCES academic_years(id); "
                    "END IF; "
                    "END $$;"
                )
            )

        connection.execute(
            text(
                "INSERT INTO academic_years (name, is_active, created_at) "
                "SELECT :name, TRUE, CURRENT_TIMESTAMP "
                "WHERE NOT EXISTS (SELECT 1 FROM academic_years)"
            ),
            {"name": default_academic_year_name()},
        )
        connection.execute(
            text(
                "UPDATE academic_years SET is_active = TRUE "
                "WHERE id = (SELECT id FROM academic_years ORDER BY id ASC LIMIT 1) "
                "AND NOT EXISTS (SELECT 1 FROM academic_years WHERE is_active = TRUE)"
            )
        )
        active_year_id = connection.execute(
            text(
                "SELECT id FROM academic_years "
                "WHERE is_active = TRUE ORDER BY id ASC LIMIT 1"
            )
        ).scalar()
        if active_year_id is not None and "classes" in existing_tables:
            connection.execute(
                text(
                    "UPDATE classes SET academic_year_id = :academic_year_id "
                    "WHERE academic_year_id IS NULL"
                ),
                {"academic_year_id": int(active_year_id)},
            )


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
