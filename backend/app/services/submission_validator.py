from __future__ import annotations

from enum import StrEnum

from fastapi import HTTPException, status

class SubmissionStatus(StrEnum):
    SUBMITTED = "submitted"
    RESUBMITTED = "resubmitted"
    GRADED = "graded"
    LOCKED = "locked"


class SubmissionValidator:
    @staticmethod
    def validate_grade_value(grade: int) -> None:
        if grade < 0 or grade > 100:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Nilai harus berada di antara 0 dan 100.",
            )

    @staticmethod
    def validate_status_filter(value: str) -> str:
        normalized = value.lower().strip()
        allowed = {s.value for s in SubmissionStatus}
        if normalized not in allowed:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Status harus salah satu dari: {', '.join(sorted(allowed))}.",
            )
        return normalized

