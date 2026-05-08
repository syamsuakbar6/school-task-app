from datetime import datetime

from pydantic import BaseModel, ConfigDict


class ClassResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    code: str | None
    teacher_id: int
    created_at: datetime | None
