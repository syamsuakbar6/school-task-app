from datetime import datetime, timezone

from fastapi import HTTPException, UploadFile, status
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.submission import Submission
from app.models.task import Task
from app.models.user import User, UserRole
from app.services.audit_service import AuditService
from app.services.class_access_service import ClassAccessService
from app.services.grading_service import GradingService
from app.services.submission_validator import SubmissionStatus, SubmissionValidator
from app.services.task_service import TaskService
from app.utils.file_handler import FileHandler


class SubmissionService:
    @staticmethod
    def can_view_submission(db: Session, *, current_user: User, submission: Submission) -> bool:
        class_id = ClassAccessService.get_submission_access_class_id(submission)
        role = ClassAccessService.normalize_role(current_user.role)
        if role == UserRole.TEACHER.value:
            return ClassAccessService.is_teacher_assigned(
                db,
                teacher_id=current_user.id,
                class_id=class_id,
            )

        if submission.user_id != current_user.id:
            return False
        return ClassAccessService.is_student_member(
            db,
            student_id=current_user.id,
            class_id=class_id,
        )

    @staticmethod
    def can_submit(db: Session, *, student: User, task: Task) -> bool:
        if ClassAccessService.normalize_role(student.role) != UserRole.STUDENT.value:
            return False
        return ClassAccessService.is_student_member(
            db,
            student_id=student.id,
            class_id=task.class_id,
        )

    @staticmethod
    def can_resubmit(existing: Submission) -> bool:
        return not (existing.grade is not None or str(existing.status or "").lower() == SubmissionStatus.LOCKED.value)

    @staticmethod
    def get_submissions(
        db: Session,
        current_user: User,
        class_id: int | None = None,
        task_id: int | None = None,
        student_id: int | None = None,
        submission_status: str | None = None,
    ) -> list[Submission]:
        role = ClassAccessService.normalize_role(current_user.role)
        statement = (
            select(Submission)
            .join(Task, Submission.task_id == Task.id)
            .options(
                joinedload(Submission.task),
                joinedload(Submission.user),
            )
            .where(Submission.class_id == Task.class_id)
            .order_by(Submission.submitted_at.desc())
        )

        # Always filter by class_id first for performance / isolation.
        if class_id is not None:
            statement = statement.where(Submission.class_id == class_id)

        if task_id is not None:
            statement = statement.where(Submission.task_id == task_id)
            # If caller didn't pass class_id, derive it from the task for performance.
            if class_id is None:
                task = db.scalar(select(Task).where(Task.id == task_id))
                if task is not None:
                    statement = statement.where(Submission.class_id == task.class_id)

        if role == UserRole.STUDENT.value:
            # Student can only access their memberships (or explicit class filter if provided).
            if class_id is not None:
                if not ClassAccessService.class_exists(db, class_id=class_id):
                    return []
                ClassAccessService.assert_student_member(
                    db,
                    student_id=current_user.id,
                    class_id=class_id,
                )
            else:
                class_ids = ClassAccessService.get_user_classes(
                    db,
                    user_id=current_user.id,
                    role=current_user.role,
                )
                if not class_ids:
                    return []
                statement = statement.where(Submission.class_id.in_(class_ids))

            if student_id is not None and student_id != current_user.id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Students can only view their own submissions.",
                )
            statement = statement.where(Submission.user_id == current_user.id)
        else:
            # Teacher access: only within their assigned classes.
            if class_id is not None:
                if not ClassAccessService.class_exists(db, class_id=class_id):
                    return []
                ClassAccessService.assert_teacher_assigned(
                    db,
                    teacher_id=current_user.id,
                    class_id=class_id,
                )
            else:
                class_ids = ClassAccessService.get_user_classes(
                    db,
                    user_id=current_user.id,
                    role=current_user.role,
                )
                if not class_ids:
                    return []
                statement = statement.where(Submission.class_id.in_(class_ids))

            if student_id is not None:
                statement = statement.where(Submission.user_id == student_id)

        submissions = list(db.scalars(statement).all())
        if submission_status is None:
            return submissions

        normalized = SubmissionValidator.validate_status_filter(submission_status)

        if not submissions:
            return submissions

        def compute_status(submission: Submission) -> str:
            if submission.status:
                return str(submission.status).lower()
            if submission.grade is not None:
                return SubmissionStatus.GRADED.value
            return SubmissionStatus.SUBMITTED.value

        return [s for s in submissions if compute_status(s) == normalized]

    @staticmethod
    def get_submission_by_id(db: Session, submission_id: int, current_user: User) -> Submission:
        submission = SubmissionService._fetch_submission_or_404(db, submission_id)
        SubmissionService._assert_can_access(db, submission, current_user)
        return submission

    @staticmethod
    async def submit_task(db: Session, task_id: int, student: User, file: UploadFile) -> Submission:
        # Submission rules owner: SubmissionService
        ClassAccessService.assert_user_role(
            student,
            expected_role=UserRole.STUDENT,
            detail="Hanya siswa yang bisa mengumpulkan tugas.",
        )

        task = SubmissionService._get_task_or_404(db, task_id)
        task_class_id = ClassAccessService.get_task_access_class_id(db, task_class_id=task.class_id)
        TaskService.assert_task_open(task)
        if not SubmissionService.can_submit(db, student=student, task=task):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Kamu belum terdaftar di kelas ini.",
            )

        existing = db.scalar(
            select(Submission)
            .where(
                Submission.class_id == task_class_id,
                Submission.task_id == task.id,
                Submission.user_id == student.id,
            )
            .order_by(Submission.submitted_at.desc())
        )
        if existing is not None:
            if not SubmissionService.can_resubmit(existing):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Pengumpulan sudah dinilai. Pengumpulan ulang tidak tersedia.",
                )

        previous_file_path = existing.file_path if existing is not None else None

        stored_file = await FileHandler.save_submission_upload(
            file,
            task_id=task.id,
            user_id=student.id,
        )
        now_utc = datetime.now(timezone.utc).replace(tzinfo=None)

        try:
            if existing is None:
                submission = Submission(
                    task_id=task.id,
                    class_id=task_class_id,
                    user_id=student.id,
                    file_path=stored_file.relative_path,
                    submitted_at=now_utc,
                    status=SubmissionStatus.SUBMITTED.value,
                    version=1,
                )
                db.add(submission)
                db.flush()

                AuditService.log(
                    db,
                    user_id=student.id,
                    action="submission.created",
                    target_type="submission",
                    target_id=submission.id,
                    detail=f"task_id={task.id};class_id={task_class_id}",
                )
                AuditService.log(
                    db,
                    user_id=student.id,
                    action="submission.status_changed",
                    target_type="submission",
                    target_id=submission.id,
                    detail=f"to={SubmissionStatus.SUBMITTED.value}",
                )

                db.commit()
                db.refresh(submission)
                return SubmissionService._fetch_submission_or_404(db, submission.id)

            # Resubmission path: replace the file (no new row) while still ungraded.
            existing.file_path = stored_file.relative_path
            existing.submitted_at = now_utc
            existing.class_id = task_class_id
            existing.status = SubmissionStatus.RESUBMITTED.value
            existing.version = int(existing.version or 1) + 1
            db.add(existing)
            db.flush()

            AuditService.log(
                db,
                user_id=student.id,
                action="submission.updated",
                target_type="submission",
                target_id=existing.id,
                detail=f"task_id={task.id};class_id={task_class_id}",
            )
            AuditService.log(
                db,
                user_id=student.id,
                action="submission.status_changed",
                target_type="submission",
                target_id=existing.id,
                detail=f"to={SubmissionStatus.RESUBMITTED.value}",
            )

            db.commit()
            db.refresh(existing)
            if previous_file_path and previous_file_path != stored_file.relative_path:
                FileHandler.delete_file(previous_file_path)
            return SubmissionService._fetch_submission_or_404(db, existing.id)
        except SQLAlchemyError:
            db.rollback()
            FileHandler.delete_file(stored_file.relative_path)
            raise

    @staticmethod
    def get_submission_file(
        db: Session,
        submission_id: int,
        current_user: User,
    ) -> tuple[Submission, str]:
        submission = SubmissionService.get_submission_by_id(db, submission_id, current_user)
        if not submission.file_path:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No file attached to this submission.",
            )

        file_path = FileHandler.resolve_file_path(submission.file_path)
        return submission, str(file_path)

    @staticmethod
    def grade_submission(
        db: Session,
        submission_id: int,
        grade: int,
        teacher: User,
    ) -> Submission:
        submission = GradingService.grade_submission(
            db,
            submission_id=submission_id,
            grade=grade,
            teacher=teacher,
        )
        return SubmissionService._fetch_submission_or_404(db, submission.id)

    @staticmethod
    def _fetch_submission_or_404(db: Session, submission_id: int) -> Submission:
        statement = (
            select(Submission)
            .options(
                joinedload(Submission.task),
                joinedload(Submission.user),
            )
            .where(Submission.id == submission_id)
        )
        submission = db.scalar(statement)
        if submission is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Pengumpulan tidak ditemukan.",
            )
        return submission

    @staticmethod
    def _get_task_or_404(db: Session, task_id: int) -> Task:
        task = db.scalar(select(Task).where(Task.id == task_id))
        if task is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Tugas tidak ditemukan.",
            )
        return task

    @staticmethod
    def _assert_can_access(db: Session, submission: Submission, current_user: User) -> None:
        ClassAccessService.get_submission_access_class_id(submission)

        if not SubmissionService.can_view_submission(db, current_user=current_user, submission=submission):
            # Preserve existing error messaging for student cross-access.
            if (
                ClassAccessService.normalize_role(current_user.role) != UserRole.TEACHER.value
                and submission.user_id != current_user.id
            ):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Kamu tidak memiliki akses ke pengumpulan ini.",
                )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Kamu tidak memiliki akses ke kelas ini.",
            )
