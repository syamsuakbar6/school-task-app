from __future__ import annotations

from datetime import datetime
from pathlib import Path

from pydantic import BaseModel, ConfigDict, Field

from app.models.submission import Submission
from app.schemas.task_schema import TaskSummary
from app.schemas.user_schema import UserSummary


class SubmissionCreate(BaseModel):
    task_id: int = Field(gt=0)


class SubmissionGradeRequest(BaseModel):
    submission_id: int
    grade: int


class SubmissionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    task_id: int
    user_id: int
    grade: int | None
    submitted_at: datetime
    has_file: bool
    file_name: str | None
    download_url: str | None
    status: str | None
    version: int | None
    task: TaskSummary
    user: UserSummary

    @classmethod
    def from_submission(cls, submission: Submission) -> "SubmissionResponse":
        file_name = Path(submission.file_path).name if submission.file_path else None
        download_url = (
            f"/submissions/{submission.id}/download" if submission.file_path else None
        )
        print(
            "SUBMISSION RESPONSE FILE URL: "
            f"id={submission.id}; file_path={submission.file_path}; "
            f"file_name={file_name}; download_url={download_url}; "
            f"status={submission.status}; version={submission.version}"
        )
        return cls(
            id=submission.id,
            task_id=submission.task_id,
            user_id=submission.user_id,
            grade=submission.grade,
            submitted_at=submission.submitted_at,
            has_file=bool(submission.file_path),
            file_name=file_name,
            download_url=download_url,
            status=submission.status,
            version=submission.version,
            task=TaskSummary.from_task(submission.task),
            user=UserSummary.model_validate(submission.user),
        )
