from fastapi import APIRouter, Depends, status

from app.core.dependencies import DBSession, get_current_user, require_teacher
from app.schemas.task_schema import TaskCreate, TaskResponse
from app.services.task_service import TaskService


router = APIRouter(prefix="/tasks", tags=["Tasks"])


@router.get("", response_model=list[TaskResponse])
def list_tasks(
    db: DBSession,
    current_user=Depends(get_current_user),
    class_id: int | None = None,
    academic_year_id: int | None = None,
    mine_only: bool = False,
) -> list[TaskResponse]:
    tasks = TaskService.get_all_tasks(
        db,
        current_user=current_user,
        class_id=class_id,
        academic_year_id=academic_year_id,
        mine_only=mine_only,
    )
    return [TaskService.to_response(task) for task in tasks]


@router.get("/{task_id}", response_model=TaskResponse)
def get_task(task_id: int, db: DBSession, current_user=Depends(get_current_user)) -> TaskResponse:
    task = TaskService.get_task_by_id(db, task_id, current_user=current_user)
    return TaskService.to_response(task)


@router.post("", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
def create_task(
    task_in: TaskCreate,
    db: DBSession,
    current_teacher=Depends(require_teacher),
) -> TaskResponse:
    task = TaskService.create_task(db, task_in, current_teacher)
    return TaskService.to_response(task)
