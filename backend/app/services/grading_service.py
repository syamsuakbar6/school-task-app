from __future__ import annotations

from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.grade import Grade
from app.models.submission import Submission
from app.models.user import User, UserRole
from app.services.audit_service import AuditService
from app.services.class_access_service import ClassAccessService
from app.services.submission_validator import SubmissionStatus, SubmissionValidator


class GradingService:
    @staticmethod
    def can_grade_submission(db: Session, *, teacher: User, submission: Submission) -> bool:
        class_id = ClassAccessService.get_submission_access_class_id(submission)
        return ClassAccessService.is_teacher_assigned(
            db,
            teacher_id=teacher.id,
            class_id=class_id,
        )

    @staticmethod
    def can_view_grade(db: Session, *, current_user: User, submission: Submission) -> bool:
        class_id = ClassAccessService.get_submission_access_class_id(submission)
        role = ClassAccessService.normalize_role(current_user.role)
        if role == UserRole.TEACHER.value:
            return ClassAccessService.is_teacher_assigned(
                db,
                teacher_id=current_user.id,
                class_id=class_id,
            )
        return submission.user_id == current_user.id and ClassAccessService.is_student_member(
            db,
            student_id=current_user.id,
            class_id=class_id,
        )

    @staticmethod
    def grade_submission(db: Session, *, submission_id: int, grade: int, teacher: User) -> Submission:
        # Grading rules owner: GradingService
        ClassAccessService.assert_user_role(
            teacher,
            expected_role=UserRole.TEACHER,
            detail="Teacher access is required.",
        )
        SubmissionValidator.validate_grade_value(grade)
        if submission_id <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="submission_id must be a positive integer.",
            )

        submission = db.scalar(
            select(Submission)
            .options(
                joinedload(Submission.task),
                joinedload(Submission.user),
            )
            .where(Submission.id == submission_id)
        )
        if submission is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Submission not found.",
            )

        class_id = ClassAccessService.get_submission_access_class_id(submission)

        # Teacher can only grade within their class assignment.
        ClassAccessService.assert_teacher_assigned(
            db,
            teacher_id=teacher.id,
            class_id=class_id,
        )

        existing_grade = db.scalar(select(Grade).where(Grade.submission_id == submission.id))
        if existing_grade is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Submission has already been graded.",
            )

        if submission.file_path is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot grade a submission without an attached file.",
            )
        if ClassAccessService.normalize_role(submission.user.role) != UserRole.STUDENT.value:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Only student submissions can be graded.",
            )
        if submission.grade is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Submission has already been graded.",
            )

        now_utc = datetime.now(timezone.utc).replace(tzinfo=None)
        grade_row = Grade(
            submission_id=submission.id,
            teacher_id=teacher.id,
            score=grade,
            feedback=None,
            graded_at=now_utc,
        )
        db.add(grade_row)

        # Keep `submissions.grade` in sync for backward-compatible responses.
        submission.grade = grade
        submission.status = SubmissionStatus.LOCKED.value
        submission.version = int(submission.version or 1)
        db.add(submission)

        AuditService.log(
            db,
            user_id=teacher.id,
            action="grading.performed",
            target_type="submission",
            target_id=submission.id,
            detail=f"grade={grade}",
        )
        AuditService.log(
            db,
            user_id=teacher.id,
            action="submission.status_changed",
            target_type="submission",
            target_id=submission.id,
            detail=f"to={SubmissionStatus.LOCKED.value}",
        )

        db.commit()
        db.refresh(submission)
        return submission

