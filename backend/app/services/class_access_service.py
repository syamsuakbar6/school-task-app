from __future__ import annotations

from typing import TYPE_CHECKING

from fastapi import HTTPException, status
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.models.class_model import Class, ClassMembership, TeacherClassAssignment
from app.models.user import User, UserRole

if TYPE_CHECKING:
    from app.models.submission import Submission


class ClassAccessService:
    """
    Shared access-control primitives.

    New service code should prefer these helpers over inline role checks,
    raw class lookups, or direct trust in relationship foreign keys.
    """

    @staticmethod
    def normalize_role(role: str | None) -> str:
        normalized = str(role).strip().lower() if role is not None else ""
        if normalized not in {UserRole.TEACHER.value, UserRole.STUDENT.value}:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Unsupported user role.",
            )
        return normalized

    @staticmethod
    def assert_user_role(
        user: User,
        *,
        expected_role: UserRole,
        detail: str,
    ) -> None:
        if ClassAccessService.normalize_role(user.role) != expected_role.value:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=detail,
            )

    @staticmethod
    def class_exists(db: Session, *, class_id: int) -> bool:
        row = db.execute(
            text("SELECT 1 FROM classes WHERE id = :class_id LIMIT 1"),
            {"class_id": class_id},
        ).first()
        return row is not None

    @staticmethod
    def is_teacher_assigned(db: Session, *, teacher_id: int, class_id: int) -> bool:
        row = db.execute(
            text(
                "SELECT 1 FROM teacher_class_assignments "
                "WHERE class_id = :class_id AND teacher_id = :teacher_id LIMIT 1"
            ),
            {"class_id": class_id, "teacher_id": teacher_id},
        ).first()
        return row is not None

    @staticmethod
    def is_student_member(db: Session, *, student_id: int, class_id: int) -> bool:
        row = db.execute(
            text(
                "SELECT 1 FROM class_memberships "
                "WHERE class_id = :class_id AND student_id = :student_id LIMIT 1"
            ),
            {"class_id": class_id, "student_id": student_id},
        ).first()
        return row is not None

    @staticmethod
    def assert_teacher_assigned(db: Session, *, teacher_id: int, class_id: int) -> None:
        if not ClassAccessService.class_exists(db, class_id=class_id):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Class not found.",
            )
        if not ClassAccessService.is_teacher_assigned(
            db,
            teacher_id=teacher_id,
            class_id=class_id,
        ):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have access to this class.",
            )

    @staticmethod
    def assert_student_member(db: Session, *, student_id: int, class_id: int) -> None:
        if not ClassAccessService.class_exists(db, class_id=class_id):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Class not found.",
            )
        if not ClassAccessService.is_student_member(
            db,
            student_id=student_id,
            class_id=class_id,
        ):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You are not a member of this class.",
            )

    @staticmethod
    def assert_class_access(db: Session, *, current_user: User, class_id: int) -> None:
        role = ClassAccessService.normalize_role(current_user.role)
        if role == UserRole.TEACHER.value:
            ClassAccessService.assert_teacher_assigned(
                db,
                teacher_id=current_user.id,
                class_id=class_id,
            )
            return

        ClassAccessService.assert_student_member(
            db,
            student_id=current_user.id,
            class_id=class_id,
        )

    @staticmethod
    def can_access_class(db: Session, *, current_user: User, class_id: int) -> bool:
        role = ClassAccessService.normalize_role(current_user.role)
        if role == UserRole.TEACHER.value:
            return ClassAccessService.is_teacher_assigned(
                db,
                teacher_id=current_user.id,
                class_id=class_id,
            )
        return ClassAccessService.is_student_member(
            db,
            student_id=current_user.id,
            class_id=class_id,
        )

    @staticmethod
    def get_teacher_class_ids(db: Session, *, teacher_id: int) -> list[int]:
        rows = db.execute(
            text(
                "SELECT class_id FROM teacher_class_assignments "
                "WHERE teacher_id = :teacher_id"
            ),
            {"teacher_id": teacher_id},
        ).all()
        return sorted({int(row[0]) for row in rows})

    @staticmethod
    def get_student_class_ids(db: Session, *, student_id: int) -> list[int]:
        rows = db.execute(
            text("SELECT class_id FROM class_memberships WHERE student_id = :student_id"),
            {"student_id": student_id},
        ).all()
        return sorted({int(row[0]) for row in rows})

    @staticmethod
    def get_user_classes(db: Session, *, user_id: int, role: str | None = None) -> list[int]:
        normalized_role = ClassAccessService.normalize_role(role)
        if normalized_role == UserRole.TEACHER.value:
            return ClassAccessService.get_teacher_class_ids(db, teacher_id=user_id)
        return ClassAccessService.get_student_class_ids(db, student_id=user_id)

    @staticmethod
    def build_accessible_classes_statement(*, current_user: User):
        role = ClassAccessService.normalize_role(current_user.role)
        if role == UserRole.TEACHER.value:
            return (
                select(Class)
                .join(
                    TeacherClassAssignment,
                    TeacherClassAssignment.class_id == Class.id,
                )
                .where(TeacherClassAssignment.teacher_id == current_user.id)
            )

        return (
            select(Class)
            .join(
                ClassMembership,
                ClassMembership.class_id == Class.id,
            )
            .where(ClassMembership.student_id == current_user.id)
        )

    @staticmethod
    def get_task_access_class_id(db: Session, *, task_class_id: int) -> int:
        if not ClassAccessService.class_exists(db, class_id=task_class_id):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Data inconsistency detected for task class_id.",
            )
        return int(task_class_id)

    @staticmethod
    def get_submission_access_class_id(submission: Submission) -> int:
        if submission.task is None or submission.class_id != submission.task.class_id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Data inconsistency detected for submission class_id.",
            )
        return int(submission.task.class_id)

