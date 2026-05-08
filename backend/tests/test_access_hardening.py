from __future__ import annotations

import pytest
from fastapi import HTTPException

from app.models.class_model import Class
from app.models.submission import Submission
from app.models.user import User
from app.services.class_service import ClassService
from app.services.submission_service import SubmissionService
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
    submission = await SubmissionService.submit_task(db, task_id=open_task.id, student=student, file=upload)

    with pytest.raises(HTTPException) as exc:
        SubmissionService.grade_submission(
            db,
            submission_id=submission.id,
            grade=88,
            teacher=other_teacher,
        )

    assert exc.value.status_code == 403


def test_corrupted_submission_returns_409(db, teacher, student, open_task, membership):
    corrupted_class = Class(name="Corrupted Class", code="BROKEN", teacher_id=teacher.id)
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
    user = User(name="Mystery", email="mystery@example.com", password="x", role="admin")
    db.add(user)
    db.commit()
    db.refresh(user)

    with pytest.raises(HTTPException) as exc:
        ClassService.get_classes(db, current_user=user)

    assert exc.value.status_code == 403


def test_class_service_returns_empty_list_when_no_access(db, other_teacher):
    assert ClassService.get_classes(db, current_user=other_teacher) == []


def test_submission_list_returns_empty_for_unknown_class_filter(db, teacher):
    submissions = SubmissionService.get_submissions(
        db,
        current_user=teacher,
        class_id=999999,
    )

    assert submissions == []
