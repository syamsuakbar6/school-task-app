from __future__ import annotations

from datetime import datetime, timezone

from pydantic import BaseModel, ConfigDict, Field

from app.models.task import Task
from app.schemas.user_schema import UserSummary


class TaskBase(BaseModel):
    title: str = Field(min_length=3, max_length=255)
    description: str | None = Field(default=None, max_length=5000)
    deadline: datetime | None = None


class TaskCreate(TaskBase):
    class_id: int = Field(gt=0)


class TaskSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    deadline: datetime | None

    @classmethod
    def from_task(cls, task: Task) -> "TaskSummary":
        return cls(
            id=task.id,
            title=task.title,
            deadline=_normalize_deadline_for_output(task.deadline),
        )


class TaskResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    description: str | None
    deadline: datetime | None
    is_closed: bool
    created_by: int
    created_at: datetime
    creator: UserSummary


def _normalize_deadline_for_output(deadline: datetime | None) -> datetime | None:
    if deadline is None:
        return None
    if deadline.tzinfo is None or deadline.utcoffset() is None:
        return deadline.replace(tzinfo=timezone.utc)
    return deadline.astimezone(timezone.utc)
