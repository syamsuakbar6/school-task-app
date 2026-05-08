from __future__ import annotations

from sqlalchemy import Column, DateTime, Integer, String

from app.db.database import Base
from app.utils.datetime_utils import utc_now_naive


class SubmissionState(Base):
    """
    Non-destructive state tracking table.
    Keeps submission lifecycle without altering existing `submissions` schema.
    """

    __tablename__ = "submission_states"

    submission_id = Column(Integer, primary_key=True, index=True)
    status = Column(String, nullable=False, index=True)  # submitted/resubmitted/graded/locked
    version = Column(Integer, nullable=False, default=1)
    updated_at_utc = Column(DateTime, nullable=False, default=utc_now_naive)
    locked_at_utc = Column(DateTime, nullable=True)

