from fastapi import APIRouter, Depends

from app.core.dependencies import DBSession, get_current_user
from app.schemas.class_schema import ClassResponse
from app.services.class_service import ClassService


router = APIRouter(prefix="/classes", tags=["Classes"])


@router.get("", response_model=list[ClassResponse])
def list_classes(db: DBSession, current_user=Depends(get_current_user)) -> list[ClassResponse]:
    classes = ClassService.get_classes(db, current_user=current_user)
    return [ClassResponse.model_validate(clazz) for clazz in classes]
