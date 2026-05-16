from datetime import date, datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select

from app.core.dependencies import DBSession, get_current_user
from app.models.class_model import AcademicYear
from app.schemas.class_schema import ClassResponse
from app.services.class_access_service import ClassAccessService
from app.services.class_service import ClassService


router = APIRouter(prefix="/classes", tags=["Classes"])


@router.get("", response_model=list[ClassResponse])
def list_classes(
    db: DBSession,
    current_user=Depends(get_current_user),
    include_history: bool = False,
    academic_year_id: int | None = None,
) -> list[ClassResponse]:
    classes = ClassService.get_classes(
        db,
        current_user=current_user,
        include_history=include_history,
        academic_year_id=academic_year_id,
    )
    return [ClassResponse.model_validate(clazz) for clazz in classes]


class AcademicYearOptionResponse(BaseModel):
    id: int
    name: str
    starts_at: date | None = None
    ends_at: date | None = None
    is_active: bool = False
    created_at: datetime | None = None

    class Config:
        from_attributes = True


@router.get("/academic-years", response_model=list[AcademicYearOptionResponse])
def list_accessible_academic_years(
    db: DBSession,
    current_user=Depends(get_current_user),
) -> list[AcademicYearOptionResponse]:
    academic_years = db.scalars(
        ClassAccessService.build_accessible_academic_years_statement(
            current_user=current_user,
        )
        .order_by(
            AcademicYear.is_active.desc(),
            AcademicYear.created_at.desc(),
            AcademicYear.id.desc(),
        )
    ).all()
    return [AcademicYearOptionResponse.model_validate(year) for year in academic_years]
