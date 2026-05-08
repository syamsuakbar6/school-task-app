from __future__ import annotations

from sqlalchemy import Column, DateTime, Integer, String, Text

from app.db.database import Base
from app.utils.datetime_utils import utc_now_naive


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=True, index=True)
    action = Column(String(50), nullable=False, index=True)
    target_type = Column(String(50), nullable=True, index=True)  # e.g. "task" / "submission"
    target_id = Column(Integer, nullable=True, index=True)
    timestamp = Column(DateTime, nullable=True, default=utc_now_naive, index=True)
    detail = Column(Text, nullable=True)

