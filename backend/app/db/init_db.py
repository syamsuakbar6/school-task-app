from __future__ import annotations

from sqlalchemy import inspect
from sqlalchemy.engine import Engine

from app.models.audit_log import AuditLog


def create_non_destructive_tables(engine: Engine) -> None:
    """
    Create new tables used by upgrade features, without touching existing schema.
    Uses checkfirst=True so it is safe on existing databases.
    """

    inspector = inspect(engine)
    existing_tables = set(inspector.get_table_names())

    if AuditLog.__tablename__ not in existing_tables:
        AuditLog.__table__.create(bind=engine, checkfirst=True)

    # Database schema is considered final; do not create additional tables beyond audit logs.

