from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.task import Task
from app.models.user import User, UserRole
from app.schemas.task_schema import TaskCreate, TaskResponse
from app.services.class_access_service import ClassAccessService


class TaskService:
    @staticmethod
    def can_view_task(db: Session, *, current_user: User, class_id: int) -> bool:
        return ClassAccessService.can_access_class(
            db,
            current_user=current_user,
            class_id=class_id,
        )

    @staticmethod
    def assert_can_view_task(db: Session, *, current_user: User, class_id: int) -> None:
        ClassAccessService.assert_class_access(
            db,
            current_user=current_user,
            class_id=class_id,
        )

    @staticmethod
    def can_create_task(db: Session, *, current_user: User, class_id: int) -> bool:
        if ClassAccessService.normalize_role(current_user.role) != UserRole.TEACHER.value:
            return False
        return ClassAccessService.is_teacher_assigned(
            db,
            teacher_id=current_user.id,
            class_id=class_id,
        )

    @staticmethod
    def assert_can_create_task(db: Session, *, current_user: User, class_id: int) -> None:
        ClassAccessService.assert_user_role(
            current_user,
            expected_role=UserRole.TEACHER,
            detail="Hanya guru yang bisa membuat tugas.",
        )
        ClassAccessService.assert_teacher_assigned(
            db,
            teacher_id=current_user.id,
            class_id=class_id,
        )

    @staticmethod
    def get_all_tasks(
        db: Session,
        *,
        current_user: User,
        class_id: int | None = None,
    ) -> list[Task]:
        statement = (
            select(Task)
            .options(joinedload(Task.creator))
            .order_by(Task.created_at.desc())
        )

        # Ambil semua kelas yang bisa diakses user ini
        class_ids = ClassAccessService.get_user_classes(
            db,
            user_id=current_user.id,
            role=current_user.role,
        )

        if not class_ids:
            return []

        if class_id is not None:
            # Kalau class_id diminta tapi user tidak punya akses ke kelas itu → return kosong
            if class_id not in class_ids:
                return []
            statement = statement.where(Task.class_id == class_id)
        else:
            # Tampilkan semua task dari semua kelas yang accessible
            statement = statement.where(Task.class_id.in_(class_ids))

        return list(db.scalars(statement).all())

    @staticmethod
    def get_task_by_id(db: Session, task_id: int, *, current_user: User | None = None) -> Task:
        statement = (
            select(Task)
            .options(joinedload(Task.creator))
            .where(Task.id == task_id)
        )
        task = db.scalar(statement)
        if task is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Tugas tidak ditemukan.",
            )
        if current_user is not None:
            class_id = ClassAccessService.get_task_access_class_id(db, task_class_id=task.class_id)
            TaskService.assert_can_view_task(db, current_user=current_user, class_id=class_id)
        return task

    @staticmethod
    def create_task(db: Session, task_in: TaskCreate, creator: User) -> Task:
        TaskService.assert_can_create_task(db, current_user=creator, class_id=task_in.class_id)

        stored_deadline = TaskService.prepare_deadline_for_storage(task_in.deadline)

        task = Task(
            title=task_in.title.strip(),
            description=task_in.description.strip() if task_in.description else None,
            deadline=stored_deadline,
            created_by=creator.id,
            class_id=task_in.class_id,
        )
        db.add(task)
        db.commit()
        db.refresh(task)
        return TaskService.get_task_by_id(db, task.id, current_user=creator)

    @staticmethod
    def to_response(task: Task) -> TaskResponse:
        return TaskResponse(
            id=task.id,
            title=task.title,
            description=task.description,
            deadline=TaskService.normalize_deadline(task.deadline, require_timezone=False),
            is_closed=TaskService.is_task_closed(task),
            created_by=task.created_by,
            created_at=task.created_at,
            creator=task.creator,
        )

    @staticmethod
    def assert_task_open(task: Task) -> None:
        if TaskService.is_task_closed(task):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Deadline sudah lewat. Pengumpulan tugas ditutup.",
            )

    @staticmethod
    def is_task_closed(task: Task) -> bool:
        deadline_epoch = TaskService.deadline_epoch_utc(task.deadline)
        if deadline_epoch is None:
            return False
        return TaskService.now_epoch_utc() >= deadline_epoch

    @staticmethod
    def prepare_deadline_for_storage(deadline: datetime | None) -> datetime | None:
        normalized_deadline = TaskService.validate_deadline_for_creation(deadline)
        if normalized_deadline is None:
            return None
        return normalized_deadline.replace(tzinfo=None)

    @staticmethod
    def validate_deadline_for_creation(deadline: datetime | None) -> datetime | None:
        if deadline is None:
            return None

        normalized_deadline = TaskService.normalize_deadline(deadline, require_timezone=True)
        if normalized_deadline <= TaskService.now_utc():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Deadline harus lebih besar dari waktu sekarang.",
            )
        return normalized_deadline

    @staticmethod
    def normalize_deadline(
        deadline: datetime | None,
        *,
        require_timezone: bool,
    ) -> datetime | None:
        if deadline is None:
            return None

        if deadline.tzinfo is None or deadline.utcoffset() is None:
            if require_timezone:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Deadline harus menyertakan timezone UTC.",
                )
            return deadline.replace(tzinfo=timezone.utc)

        return deadline.astimezone(timezone.utc)

    @staticmethod
    def now_utc() -> datetime:
        return datetime.now(timezone.utc)

    @staticmethod
    def now_epoch_utc() -> int:
        return int(TaskService.now_utc().timestamp())

    @staticmethod
    def deadline_epoch_utc(deadline: datetime | None) -> int | None:
        normalized = TaskService.normalize_deadline(deadline, require_timezone=False)
        if normalized is None:
            return None
        return int(normalized.timestamp())
