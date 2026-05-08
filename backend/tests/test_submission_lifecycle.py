from __future__ import annotations

import io

import pytest
from fastapi import HTTPException

from app.services.submission_service import SubmissionService


class _UploadFile:
    """
    Minimal UploadFile-like object for FileHandler.save_upload_file().
    """

    def __init__(self, filename: str, content: bytes):
        self.filename = filename
        self._content = content

    async def read(self) -> bytes:
        return self._content

    async def close(self) -> None:
        return None


@pytest.mark.asyncio
async def test_submit_task_success(db, student, open_task, membership):
    upload = _UploadFile("a.pdf", b"hello")
    submission = await SubmissionService.submit_task(db, task_id=open_task.id, student=student, file=upload)
    assert submission.id > 0
    assert submission.task_id == open_task.id
    assert submission.user_id == student.id
    assert submission.grade is None


@pytest.mark.asyncio
async def test_resubmit_allowed_before_graded(db, student, open_task, membership):
    upload1 = _UploadFile("a.pdf", b"hello")
    first = await SubmissionService.submit_task(db, task_id=open_task.id, student=student, file=upload1)
    first_path = first.file_path

    upload2 = _UploadFile("b.pdf", b"changed")
    second = await SubmissionService.submit_task(db, task_id=open_task.id, student=student, file=upload2)

    # Should replace, not create a new submission row
    assert second.id == first.id
    assert second.file_path != first_path


@pytest.mark.asyncio
async def test_resubmit_blocked_after_graded(db, student, teacher, open_task, membership):
    upload1 = _UploadFile("a.pdf", b"hello")
    submission = await SubmissionService.submit_task(db, task_id=open_task.id, student=student, file=upload1)

    SubmissionService.grade_submission(db, submission_id=submission.id, grade=80, teacher=teacher)

    upload2 = _UploadFile("b.pdf", b"changed")
    with pytest.raises(HTTPException) as exc:
        await SubmissionService.submit_task(db, task_id=open_task.id, student=student, file=upload2)
    assert exc.value.status_code == 409


@pytest.mark.asyncio
async def test_deadline_rejection(db, student, expired_task):
    upload = _UploadFile("a.pdf", b"late")
    with pytest.raises(HTTPException) as exc:
        await SubmissionService.submit_task(db, task_id=expired_task.id, student=student, file=upload)
    assert exc.value.status_code == 403


@pytest.mark.asyncio
async def test_grading_success_and_blocked_regrade(db, student, teacher, open_task, membership):
    upload = _UploadFile("a.pdf", b"hello")
    submission = await SubmissionService.submit_task(db, task_id=open_task.id, student=student, file=upload)

    graded = SubmissionService.grade_submission(db, submission_id=submission.id, grade=90, teacher=teacher)
    assert graded.grade == 90

    with pytest.raises(HTTPException) as exc:
        SubmissionService.grade_submission(db, submission_id=submission.id, grade=95, teacher=teacher)
    assert exc.value.status_code == 409

