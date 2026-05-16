from __future__ import annotations

from datetime import date, datetime

from pydantic import BaseModel, Field


class PromotionAcademicYearResponse(BaseModel):
    id: int
    name: str
    starts_at: date | None = None
    ends_at: date | None = None
    is_active: bool = False
    created_at: datetime | None = None

    class Config:
        from_attributes = True


class PromotionPreviewRequest(BaseModel):
    source_academic_year_id: int
    target_academic_year_id: int


class PromotionPreviewStudentResponse(BaseModel):
    student_id: int
    name: str
    nisn: str | None = None
    selected: bool = True
    default_action: str
    will_be_alumni: bool = False
    promoted_target_class_name: str | None = None
    retained_target_class_name: str | None = None


class PromotionPreviewClassResponse(BaseModel):
    source_class_id: int
    source_class_name: str
    source_grade_level: str | None = None
    source_major: str | None = None
    source_section: str | None = None
    default_action: str
    promoted_target_class_name: str | None = None
    retained_target_class_name: str | None = None
    warning: str | None = None
    students: list[PromotionPreviewStudentResponse] = Field(default_factory=list)


class PromotionPreviewResponse(BaseModel):
    source_academic_year: PromotionAcademicYearResponse
    target_academic_year: PromotionAcademicYearResponse
    classes: list[PromotionPreviewClassResponse] = Field(default_factory=list)
    student_count: int = 0
    alumni_count: int = 0
    review_count: int = 0


class PromotionCommitRequest(BaseModel):
    source_academic_year_id: int
    target_academic_year_id: int
    not_promoted_student_ids: list[int] = Field(default_factory=list)


class PromotionCommitResponse(BaseModel):
    source_academic_year: PromotionAcademicYearResponse
    target_academic_year: PromotionAcademicYearResponse
    created_class_count: int = 0
    reused_class_count: int = 0
    membership_created_count: int = 0
    membership_existing_count: int = 0
    alumni_count: int = 0
    archived_class_count: int = 0
    skipped_count: int = 0
    warnings: list[str] = Field(default_factory=list)
