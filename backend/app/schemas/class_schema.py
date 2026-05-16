from datetime import datetime

from pydantic import BaseModel, ConfigDict


class ClassResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    code: str | None
    grade_level: str | None = None
    major: str | None = None
    section: str | None = None
    academic_year_id: int | None = None
    academic_year_name: str | None = None
    teacher_id: int
    created_at: datetime | None
    is_archived: bool = False
    archived_at: datetime | None = None
