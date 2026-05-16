from __future__ import annotations

from typing import TYPE_CHECKING

from fastapi import HTTPException, status
from sqlalchemy import or_, select, text
from sqlalchemy.orm import Session

from app.models.class_model import AcademicYear, Class, ClassMembership, TeacherClassAssignment
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
        allowed = {UserRole.TEACHER.value, UserRole.STUDENT.value, "admin"}
        if normalized not in allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Role pengguna tidak didukung.",
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
    def _active_year_sql_filter() -> str:
        return (
            "(classes.academic_year_id IS NULL OR classes.academic_year_id IN "
            "(SELECT id FROM academic_years WHERE is_active = TRUE))"
        )

    @staticmethod
    def is_teacher_assigned(
        db: Session,
        *,
        teacher_id: int,
        class_id: int,
        include_history: bool = False,
    ) -> bool:
        active_filter = (
            ""
            if include_history
            else (
                "AND COALESCE(classes.is_archived, FALSE) = FALSE "
                f"AND {ClassAccessService._active_year_sql_filter()} "
            )
        )
        row = db.execute(
            text(
                "SELECT 1 FROM teacher_class_assignments "
                "JOIN classes ON classes.id = teacher_class_assignments.class_id "
                "WHERE teacher_class_assignments.class_id = :class_id "
                "AND teacher_class_assignments.teacher_id = :teacher_id "
                f"{active_filter}LIMIT 1"
            ),
            {"class_id": class_id, "teacher_id": teacher_id},
        ).first()
        return row is not None

    @staticmethod
    def is_student_member(
        db: Session,
        *,
        student_id: int,
        class_id: int,
        include_history: bool = False,
    ) -> bool:
        active_filter = (
            ""
            if include_history
            else (
                "AND COALESCE(classes.is_archived, FALSE) = FALSE "
                f"AND {ClassAccessService._active_year_sql_filter()} "
            )
        )
        row = db.execute(
            text(
                "SELECT 1 FROM class_memberships "
                "JOIN classes ON classes.id = class_memberships.class_id "
                "WHERE class_memberships.class_id = :class_id "
                "AND class_memberships.student_id = :student_id "
                f"{active_filter}LIMIT 1"
            ),
            {"class_id": class_id, "student_id": student_id},
        ).first()
        return row is not None

    @staticmethod
    def assert_teacher_assigned(
        db: Session,
        *,
        teacher_id: int,
        class_id: int,
        include_history: bool = False,
    ) -> None:
        if not ClassAccessService.class_exists(db, class_id=class_id):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Kelas tidak ditemukan.",
            )
        if not ClassAccessService.is_teacher_assigned(
            db,
            teacher_id=teacher_id,
            class_id=class_id,
            include_history=include_history,
        ):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Kamu tidak memiliki akses ke kelas ini.",
            )

    @staticmethod
    def assert_student_member(
        db: Session,
        *,
        student_id: int,
        class_id: int,
        include_history: bool = False,
    ) -> None:
        if not ClassAccessService.class_exists(db, class_id=class_id):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Kelas tidak ditemukan.",
            )
        if not ClassAccessService.is_student_member(
            db,
            student_id=student_id,
            class_id=class_id,
            include_history=include_history,
        ):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Kamu belum terdaftar di kelas ini.",
            )

    @staticmethod
    def assert_class_access(
        db: Session,
        *,
        current_user: User,
        class_id: int,
        include_history: bool = False,
    ) -> None:
        role = ClassAccessService.normalize_role(current_user.role)
        if role == UserRole.TEACHER.value:
            ClassAccessService.assert_teacher_assigned(
                db,
                teacher_id=current_user.id,
                class_id=class_id,
                include_history=include_history,
            )
            return

        ClassAccessService.assert_student_member(
            db,
            student_id=current_user.id,
            class_id=class_id,
            include_history=include_history,
        )

    @staticmethod
    def can_access_class(
        db: Session,
        *,
        current_user: User,
        class_id: int,
        include_history: bool = False,
    ) -> bool:
        role = ClassAccessService.normalize_role(current_user.role)
        if role == UserRole.TEACHER.value:
            return ClassAccessService.is_teacher_assigned(
                db,
                teacher_id=current_user.id,
                class_id=class_id,
                include_history=include_history,
            )
        return ClassAccessService.is_student_member(
            db,
            student_id=current_user.id,
            class_id=class_id,
            include_history=include_history,
        )

    @staticmethod
    def get_teacher_class_ids(
        db: Session,
        *,
        teacher_id: int,
        include_history: bool = False,
        academic_year_id: int | None = None,
    ) -> list[int]:
        active_filter = (
            ""
            if include_history or academic_year_id is not None
            else (
                "AND COALESCE(classes.is_archived, FALSE) = FALSE "
                f"AND {ClassAccessService._active_year_sql_filter()} "
            )
        )
        year_filter = (
            "AND classes.academic_year_id = :academic_year_id "
            if academic_year_id is not None
            else ""
        )
        rows = db.execute(
            text(
                "SELECT teacher_class_assignments.class_id FROM teacher_class_assignments "
                "JOIN classes ON classes.id = teacher_class_assignments.class_id "
                "WHERE teacher_class_assignments.teacher_id = :teacher_id "
                f"{year_filter}"
                f"{active_filter}"
            ),
            {"teacher_id": teacher_id, "academic_year_id": academic_year_id},
        ).all()
        return sorted({int(row[0]) for row in rows})

    @staticmethod
    def get_student_class_ids(
        db: Session,
        *,
        student_id: int,
        include_history: bool = False,
        academic_year_id: int | None = None,
    ) -> list[int]:
        active_filter = (
            ""
            if include_history or academic_year_id is not None
            else (
                "AND COALESCE(classes.is_archived, FALSE) = FALSE "
                f"AND {ClassAccessService._active_year_sql_filter()} "
            )
        )
        year_filter = (
            "AND classes.academic_year_id = :academic_year_id "
            if academic_year_id is not None
            else ""
        )
        rows = db.execute(
            text(
                "SELECT class_memberships.class_id FROM class_memberships "
                "JOIN classes ON classes.id = class_memberships.class_id "
                "WHERE class_memberships.student_id = :student_id "
                f"{year_filter}"
                f"{active_filter}"
            ),
            {"student_id": student_id, "academic_year_id": academic_year_id},
        ).all()
        return sorted({int(row[0]) for row in rows})

    @staticmethod
    def get_user_classes(
        db: Session,
        *,
        user_id: int,
        role: str | None = None,
        include_history: bool = False,
        academic_year_id: int | None = None,
    ) -> list[int]:
        normalized_role = ClassAccessService.normalize_role(role)
        if normalized_role == UserRole.TEACHER.value:
            return ClassAccessService.get_teacher_class_ids(
                db,
                teacher_id=user_id,
                include_history=include_history,
                academic_year_id=academic_year_id,
            )
        return ClassAccessService.get_student_class_ids(
            db,
            student_id=user_id,
            include_history=include_history,
            academic_year_id=academic_year_id,
        )

    @staticmethod
    def build_accessible_classes_statement(
        *,
        current_user: User,
        include_history: bool = False,
        academic_year_id: int | None = None,
    ):
        role = ClassAccessService.normalize_role(current_user.role)
        if role == UserRole.TEACHER.value:
            statement = (
                select(Class)
                .join(
                    TeacherClassAssignment,
                    TeacherClassAssignment.class_id == Class.id,
                )
                .where(TeacherClassAssignment.teacher_id == current_user.id)
            )
        else:
            statement = (
                select(Class)
                .join(
                    ClassMembership,
                    ClassMembership.class_id == Class.id,
                )
                .where(ClassMembership.student_id == current_user.id)
            )

        if academic_year_id is not None:
            return statement.where(Class.academic_year_id == academic_year_id)
        if include_history:
            return statement
        return (
            statement
            .where(Class.is_archived.is_(False))
            .where(ClassAccessService._active_year_expression())
        )

    @staticmethod
    def build_accessible_academic_years_statement(*, current_user: User):
        role = ClassAccessService.normalize_role(current_user.role)
        if role == UserRole.TEACHER.value:
            return (
                select(AcademicYear)
                .join(Class, Class.academic_year_id == AcademicYear.id)
                .join(
                    TeacherClassAssignment,
                    TeacherClassAssignment.class_id == Class.id,
                )
                .where(TeacherClassAssignment.teacher_id == current_user.id)
                .distinct()
            )
        return (
            select(AcademicYear)
            .join(Class, Class.academic_year_id == AcademicYear.id)
            .join(
                ClassMembership,
                ClassMembership.class_id == Class.id,
            )
            .where(ClassMembership.student_id == current_user.id)
            .distinct()
        )

    @staticmethod
    def _active_year_expression():
        return or_(
            Class.academic_year_id.is_(None),
            Class.academic_year_id.in_(
                select(AcademicYear.id).where(AcademicYear.is_active.is_(True))
            ),
        )

    @staticmethod
    def get_task_access_class_id(db: Session, *, task_class_id: int) -> int:
        if not ClassAccessService.class_exists(db, class_id=task_class_id):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Data kelas pada tugas tidak konsisten.",
            )
        return int(task_class_id)

    @staticmethod
    def get_submission_access_class_id(submission: Submission) -> int:
        if submission.task is None or submission.class_id != submission.task.class_id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Data kelas pada pengumpulan tidak konsisten.",
            )
        return int(submission.task.class_id)

