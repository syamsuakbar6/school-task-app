from __future__ import annotations

from sqlalchemy.orm import Session

from app.models.class_model import Class
from app.models.user import User
from app.services.class_access_service import ClassAccessService


class ClassService:
    @staticmethod
    def get_classes(
        db: Session,
        *,
        current_user: User,
        include_history: bool = False,
        academic_year_id: int | None = None,
    ) -> list[Class]:
        statement = (
            ClassAccessService.build_accessible_classes_statement(
                current_user=current_user,
                include_history=include_history,
                academic_year_id=academic_year_id,
            )
            .order_by(Class.created_at.desc(), Class.id.desc())
            .distinct()
        )
        return list(db.scalars(statement).all())
