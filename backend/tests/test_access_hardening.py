from __future__ import annotations

import pytest
from fastapi import HTTPException

from app.models.class_model import Class, TeacherClassAssignment
from app.models.submission import Submission
from app.models.task import Task
from app.models.user import User
from app.routers.admin import CreateClassRequest, create_class
from app.services.class_service import ClassService
from app.services.submission_service import SubmissionService
from app.services.task_service import TaskService
from app.utils.datetime_utils import utc_now_naive


class _UploadFile:
    def __init__(self, filename: str, content: bytes):
        self.filename = filename
        self._content = content

    async def read(self) -> bytes:
        return self._content

    async def close(self) -> None:
        return None


@pytest.mark.asyncio
async def test_teacher_cannot_grade_outside_assigned_class(db, student, other_teacher, open_task, membership):
    upload = _UploadFile("grade-me.pdf", b"hello")
    submission = await SubmissionService.submit_task(
        db,
        task_id=open_task.id,
        student=student,
        file=upload,
    )

    with pytest.raises(HTTPException) as exc:
        SubmissionService.grade_submission(
            db,
            submission_id=submission.id,
            grade=88,
            teacher=other_teacher,
        )

    assert exc.value.status_code == 403


@pytest.mark.asyncio
async def test_assigned_teacher_cannot_grade_task_created_by_another_teacher(
    db,
    student,
    other_teacher,
    open_task,
    membership,
):
    db.add(
        TeacherClassAssignment(
            teacher_id=other_teacher.id,
            class_id=open_task.class_id,
        )
    )
    db.commit()

    upload = _UploadFile("same-class.pdf", b"hello")
    submission = await SubmissionService.submit_task(
        db,
        task_id=open_task.id,
        student=student,
        file=upload,
    )

    with pytest.raises(HTTPException) as exc:
        SubmissionService.grade_submission(
            db,
            submission_id=submission.id,
            grade=88,
            teacher=other_teacher,
        )

    assert exc.value.status_code == 403
    assert exc.value.detail == "Hanya guru pembuat tugas yang bisa memberi nilai."


def test_corrupted_submission_returns_409(db, teacher, student, open_task, membership):
    corrupted_class = Class(
        name="Corrupted Class",
        code="BROKEN",
        teacher_id=teacher.id,
    )
    db.add(corrupted_class)
    db.commit()
    db.refresh(corrupted_class)

    submission = Submission(
        user_id=student.id,
        task_id=open_task.id,
        class_id=corrupted_class.id,
        file_path="submissions/broken.txt",
        submitted_at=utc_now_naive(),
    )
    db.add(submission)
    db.commit()
    db.refresh(submission)

    with pytest.raises(HTTPException) as exc:
        SubmissionService.get_submission_by_id(db, submission.id, teacher)

    assert exc.value.status_code == 409


def test_unknown_role_returns_403(db):
    user = User(name="Mystery", email="mystery@example.com", password="x", role="mystery")
    db.add(user)
    db.commit()
    db.refresh(user)

    with pytest.raises(HTTPException) as exc:
        ClassService.get_classes(db, current_user=user)

    assert exc.value.status_code == 403


def test_class_service_returns_empty_list_when_no_access(db, other_teacher):
    assert ClassService.get_classes(db, current_user=other_teacher) == []


def test_archived_class_is_hidden_from_teacher_access(db, teacher, open_task):
    open_task_class = db.get(Class, open_task.class_id)
    open_task_class.is_archived = True
    db.add(open_task_class)
    db.commit()

    assert ClassService.get_classes(db, current_user=teacher) == []


def test_create_class_rejects_duplicate_active_name(db, open_task):
    admin = User(name="Admin", email="admin@example.com", password="x", role="admin")
    db.add(admin)
    db.commit()
    db.refresh(admin)

    with pytest.raises(HTTPException) as exc:
        create_class(
            payload=CreateClassRequest(name=" Class   1 ", code="CNEW"),
            db=db,
            current_admin=admin,
        )

    assert exc.value.status_code == 400
    assert exc.value.detail == "Nama kelas sudah digunakan."


def test_submission_list_returns_empty_for_unknown_class_filter(db, teacher):
    submissions = SubmissionService.get_submissions(
        db,
        current_user=teacher,
        class_id=999999,
    )

    assert submissions == []


def test_teacher_mine_only_tasks_filters_to_created_tasks(db, teacher, other_teacher, open_task):
    db.add(
        TeacherClassAssignment(
            teacher_id=other_teacher.id,
            class_id=open_task.class_id,
        )
    )
    other_task = Task(
        title="Other Teacher Task",
        description="Same class",
        deadline=utc_now_naive(),
        created_by=other_teacher.id,
        class_id=open_task.class_id,
    )
    db.add(other_task)
    db.commit()
    db.refresh(other_task)

    all_tasks = TaskService.get_all_tasks(
        db,
        current_user=teacher,
        class_id=open_task.class_id,
        mine_only=False,
    )
    mine_only_tasks = TaskService.get_all_tasks(
        db,
        current_user=teacher,
        class_id=open_task.class_id,
        mine_only=True,
    )

    assert {task.id for task in all_tasks} == {open_task.id, other_task.id}
    assert [task.id for task in mine_only_tasks] == [open_task.id]
