from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.audit_log import AuditLog


class AuditService:
    @staticmethod
    def log(
        db: Session,
        *,
        user_id: int | None,
        action: str,
        target_type: str,
        target_id: int | None,
        detail: str | None = None,
    ) -> None:
        entry = AuditLog(
            user_id=user_id,
            action=action,
            target_type=target_type,
            target_id=target_id,
            timestamp=datetime.now(timezone.utc).replace(tzinfo=None),
            detail=detail,
        )
        db.add(entry)

