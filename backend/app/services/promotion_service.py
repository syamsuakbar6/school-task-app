from __future__ import annotations

from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.class_model import AcademicYear, Class, ClassMembership, TeacherClassAssignment
from app.models.user import User, UserRole
from app.schemas.promotion_schema import (
    PromotionAcademicYearResponse,
    PromotionCommitRequest,
    PromotionCommitResponse,
    PromotionPreviewClassResponse,
    PromotionPreviewRequest,
    PromotionPreviewResponse,
    PromotionPreviewStudentResponse,
)
from app.services.academic_year_service import AcademicYearService
from app.utils.class_name_utils import build_class_code, build_class_name, parse_class_name


class PromotionService:
    @staticmethod
    def preview(db: Session, payload: PromotionPreviewRequest) -> PromotionPreviewResponse:
        source_year, target_year = PromotionService._validate_years(db, payload)
        preview_classes: list[PromotionPreviewClassResponse] = []
        student_count = 0
        alumni_count = 0
        review_count = 0

        for source_class in PromotionService._source_classes(db, source_year.id):
            grade_level, major, section = PromotionService._class_parts(source_class)
            class_plan = PromotionService._class_plan(
                grade_level=grade_level,
                major=major,
                section=section,
            )
            if class_plan["default_action"] == "needs_review":
                review_count += 1

            preview_students: list[PromotionPreviewStudentResponse] = []
            for student in PromotionService._class_students(db, source_class.id):
                student_count += 1
                if class_plan["will_be_alumni"]:
                    alumni_count += 1
                preview_students.append(PromotionPreviewStudentResponse(
                    student_id=student.id,
                    name=student.name,
                    nisn=student.nisn,
                    selected=True,
                    default_action=str(class_plan["default_action"]),
                    will_be_alumni=bool(class_plan["will_be_alumni"]),
                    promoted_target_class_name=class_plan["promoted_target_class_name"],
                    retained_target_class_name=class_plan["retained_target_class_name"],
                ))

            preview_classes.append(PromotionPreviewClassResponse(
                source_class_id=source_class.id,
                source_class_name=source_class.name,
                source_grade_level=grade_level,
                source_major=major,
                source_section=section,
                default_action=str(class_plan["default_action"]),
                promoted_target_class_name=class_plan["promoted_target_class_name"],
                retained_target_class_name=class_plan["retained_target_class_name"],
                warning=class_plan["warning"],
                students=preview_students,
            ))

        return PromotionPreviewResponse(
            source_academic_year=PromotionAcademicYearResponse.model_validate(source_year),
            target_academic_year=PromotionAcademicYearResponse.model_validate(target_year),
            classes=preview_classes,
            student_count=student_count,
            alumni_count=alumni_count,
            review_count=review_count,
        )

    @staticmethod
    def commit(db: Session, payload: PromotionCommitRequest) -> PromotionCommitResponse:
        source_year, target_year = PromotionService._validate_years(db, payload)
        not_promoted_ids = set(payload.not_promoted_student_ids)
        created_class_count = 0
        reused_class_count = 0
        membership_created_count = 0
        membership_existing_count = 0
        alumni_count = 0
        archived_class_count = 0
        skipped_count = 0
        warnings: list[str] = []
        now = datetime.now(timezone.utc).replace(tzinfo=None)

        for source_class in PromotionService._source_classes(db, source_year.id):
            grade_level, major, section = PromotionService._class_parts(source_class)
            class_plan = PromotionService._class_plan(
                grade_level=grade_level,
                major=major,
                section=section,
            )
            if class_plan["default_action"] == "needs_review":
                skipped_count += 1
                warnings.append(
                    f"Kelas {source_class.name} dilewati karena format kelas belum valid."
                )
                continue

            target_classes_by_name: dict[str, Class] = {}
            for student in PromotionService._class_students(db, source_class.id):
                is_not_promoted = student.id in not_promoted_ids
                should_graduate = (
                    class_plan["default_action"] == "graduate"
                    and not is_not_promoted
                )
                if should_graduate:
                    if not bool(getattr(student, "is_alumni", False)):
                        student.is_alumni = True
                        student.alumni_at = now
                        db.add(student)
                    alumni_count += 1
                    continue

                target_class_name = (
                    class_plan["retained_target_class_name"]
                    if is_not_promoted
                    else class_plan["promoted_target_class_name"]
                )
                if target_class_name is None:
                    skipped_count += 1
                    warnings.append(
                        f"Siswa {student.name} dilewati karena target kelas belum valid."
                    )
                    continue

                target_class = target_classes_by_name.get(str(target_class_name))
                if target_class is None:
                    target_class, created = PromotionService._get_or_create_target_class(
                        db,
                        source_class=source_class,
                        target_academic_year_id=target_year.id,
                        target_class_name=str(target_class_name),
                        fallback_grade_level=grade_level,
                        fallback_major=major,
                        fallback_section=section,
                    )
                    target_classes_by_name[str(target_class_name)] = target_class
                    if created:
                        created_class_count += 1
                    else:
                        reused_class_count += 1

                PromotionService._copy_teacher_assignments(
                    db,
                    source_class_id=source_class.id,
                    target_class_id=target_class.id,
                )

                existing_membership = db.scalar(
                    select(ClassMembership).where(
                        ClassMembership.class_id == target_class.id,
                        ClassMembership.student_id == student.id,
                    )
                )
                if existing_membership is None:
                    db.add(ClassMembership(
                        class_id=target_class.id,
                        student_id=student.id,
                    ))
                    membership_created_count += 1
                else:
                    membership_existing_count += 1

                if bool(getattr(student, "is_alumni", False)):
                    student.is_alumni = False
                    student.alumni_at = None
                    db.add(student)

            if not source_class.is_archived:
                source_class.is_archived = True
                source_class.archived_at = now
                db.add(source_class)
                archived_class_count += 1

        db.query(AcademicYear).update(
            {AcademicYear.is_active: False},
            synchronize_session=False,
        )
        source_year.is_active = False
        target_year.is_active = True
        db.add(source_year)
        db.add(target_year)
        db.commit()

        return PromotionCommitResponse(
            source_academic_year=PromotionAcademicYearResponse.model_validate(source_year),
            target_academic_year=PromotionAcademicYearResponse.model_validate(target_year),
            created_class_count=created_class_count,
            reused_class_count=reused_class_count,
            membership_created_count=membership_created_count,
            membership_existing_count=membership_existing_count,
            alumni_count=alumni_count,
            archived_class_count=archived_class_count,
            skipped_count=skipped_count,
            warnings=warnings,
        )

    @staticmethod
    def _validate_years(db: Session, payload) -> tuple[AcademicYear, AcademicYear]:
        if payload.source_academic_year_id == payload.target_academic_year_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Tahun ajaran asal dan tujuan harus berbeda.",
            )
        source_year = AcademicYearService.get_academic_year_or_404(
            db,
            payload.source_academic_year_id,
        )
        target_year = AcademicYearService.get_academic_year_or_404(
            db,
            payload.target_academic_year_id,
        )
        return source_year, target_year

    @staticmethod
    def _source_classes(db: Session, source_academic_year_id: int) -> list[Class]:
        return list(db.scalars(
            select(Class)
            .where(Class.academic_year_id == source_academic_year_id)
            .where(Class.is_archived.is_(False))
            .order_by(Class.name.asc(), Class.id.asc())
        ).all())

    @staticmethod
    def _class_students(db: Session, class_id: int) -> list[User]:
        return list(db.scalars(
            select(User)
            .join(ClassMembership, ClassMembership.student_id == User.id)
            .where(ClassMembership.class_id == class_id)
            .where(User.role == UserRole.STUDENT.value)
            .order_by(User.name.asc(), User.id.asc())
        ).all())

    @staticmethod
    def _class_parts(cls: Class | None) -> tuple[str | None, str | None, str | None]:
        if cls is None:
            return None, None, None
        if cls.grade_level and cls.major and cls.section:
            return cls.grade_level, cls.major, cls.section
        parsed = parse_class_name(cls.name)
        if parsed is None:
            return cls.grade_level, cls.major, cls.section
        return parsed

    @staticmethod
    def _class_plan(
        *,
        grade_level: str | None,
        major: str | None,
        section: str | None,
    ) -> dict[str, str | bool | None]:
        if not grade_level or not major or not section:
            return {
                "default_action": "needs_review",
                "will_be_alumni": False,
                "promoted_target_class_name": None,
                "retained_target_class_name": None,
                "warning": "Format kelas belum lengkap. Periksa tingkat, jurusan, dan nomor kelas.",
            }

        normalized_grade = grade_level.upper()
        try:
            retained_target_class_name = build_class_name(
                grade_level=normalized_grade,
                major=major,
                section=section,
            )
        except ValueError:
            return {
                "default_action": "needs_review",
                "will_be_alumni": False,
                "promoted_target_class_name": None,
                "retained_target_class_name": None,
                "warning": "Format kelas belum valid untuk preview naik kelas.",
            }

        if normalized_grade == "XII":
            return {
                "default_action": "graduate",
                "will_be_alumni": True,
                "promoted_target_class_name": None,
                "retained_target_class_name": retained_target_class_name,
                "warning": None,
            }

        next_grade = {"X": "XI", "XI": "XII"}.get(normalized_grade)
        if next_grade is None:
            return {
                "default_action": "needs_review",
                "will_be_alumni": False,
                "promoted_target_class_name": None,
                "retained_target_class_name": retained_target_class_name,
                "warning": "Tingkat kelas harus X, XI, atau XII.",
            }

        return {
            "default_action": "promote",
            "will_be_alumni": False,
            "promoted_target_class_name": build_class_name(
                grade_level=next_grade,
                major=major,
                section=section,
            ),
            "retained_target_class_name": retained_target_class_name,
            "warning": None,
        }

    @staticmethod
    def _get_or_create_target_class(
        db: Session,
        *,
        source_class: Class,
        target_academic_year_id: int,
        target_class_name: str,
        fallback_grade_level: str | None,
        fallback_major: str | None,
        fallback_section: str | None,
    ) -> tuple[Class, bool]:
        existing = db.scalar(
            select(Class).where(
                func.lower(Class.name) == target_class_name.lower(),
                Class.academic_year_id == target_academic_year_id,
            )
        )
        if existing is not None:
            if existing.is_archived:
                existing.is_archived = False
                existing.archived_at = None
                db.add(existing)
            return existing, False

        parsed = parse_class_name(target_class_name)
        grade_level = parsed[0] if parsed is not None else fallback_grade_level
        major = parsed[1] if parsed is not None else fallback_major
        section = parsed[2] if parsed is not None else fallback_section
        target_class = Class(
            name=target_class_name,
            code=build_class_code(target_class_name),
            grade_level=grade_level,
            major=major,
            section=section,
            academic_year_id=target_academic_year_id,
            teacher_id=source_class.teacher_id,
        )
        db.add(target_class)
        db.flush()
        return target_class, True

    @staticmethod
    def _copy_teacher_assignments(
        db: Session,
        *,
        source_class_id: int,
        target_class_id: int,
    ) -> None:
        assignments = db.scalars(
            select(TeacherClassAssignment).where(
                TeacherClassAssignment.class_id == source_class_id,
            )
        ).all()
        for assignment in assignments:
            existing = db.scalar(
                select(TeacherClassAssignment).where(
                    TeacherClassAssignment.class_id == target_class_id,
                    TeacherClassAssignment.teacher_id == assignment.teacher_id,
                )
            )
            if existing is None:
                db.add(TeacherClassAssignment(
                    class_id=target_class_id,
                    teacher_id=assignment.teacher_id,
                ))
