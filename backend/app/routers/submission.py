from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from fastapi.responses import FileResponse, RedirectResponse

from app.core.dependencies import DBSession, get_current_user, require_student, require_teacher
from app.core.config import settings
from app.schemas.submission_schema import SubmissionGradeRequest, SubmissionResponse
from app.services.submission_service import SubmissionService
from app.utils.file_handler import FileHandler


router = APIRouter(tags=["Submissions"])


@router.get("/submissions", response_model=list[SubmissionResponse])
def list_submissions(
    db: DBSession,
    current_user=Depends(get_current_user),
    class_id: int | None = None,
    task_id: int | None = None,
    student_id: int | None = None,
    status: str | None = None,
) -> list[SubmissionResponse]:
    submissions = SubmissionService.get_submissions(
        db,
        current_user=current_user,
        class_id=class_id,
        task_id=task_id,
        student_id=student_id,
        submission_status=status,
    )
    return [SubmissionResponse.from_submission(submission) for submission in submissions]


@router.post(
    "/submit",
    response_model=SubmissionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def submit_task(
    task_id: Annotated[int, Form()],
    file: Annotated[UploadFile, File(description="Submission file")],
    db: DBSession,
    current_student=Depends(require_student),
) -> SubmissionResponse:
    submission = await SubmissionService.submit_task(
        db,
        task_id=task_id,
        student=current_student,
        file=file,
    )
    return SubmissionResponse.from_submission(submission)


@router.get("/submissions/{submission_id}/download")
def download_submission(
    submission_id: int,
    db: DBSession,
    current_user=Depends(get_current_user),
):
    """
    Download file submission.
    - Kalau file ada di Supabase → redirect ke signed URL (1 jam).
    - Kalau file ada di local disk → stream langsung.
    """
    submission, file_path = SubmissionService.get_submission_file(
        db,
        submission_id=submission_id,
        current_user=current_user,
    )

    # Supabase path → generate signed URL lalu redirect
    if settings.supabase_enabled and FileHandler.is_supabase_path(file_path):
        signed_url = FileHandler.get_supabase_signed_url(
            file_path,
            expires_in=3600,  # URL valid 1 jam
        )
        return RedirectResponse(url=signed_url)

    # Local file → stream langsung
    file_name = Path(file_path).name if submission.file_path else f"submission-{submission.id}"
    return FileResponse(
        path=file_path,
        filename=file_name,
        media_type="application/octet-stream",
    )


@router.post("/grade", response_model=SubmissionResponse)
def grade_submission(
    payload: SubmissionGradeRequest,
    db: DBSession,
    current_teacher=Depends(require_teacher),
) -> SubmissionResponse:
    submission = SubmissionService.grade_submission(
        db,
        submission_id=payload.submission_id,
        grade=payload.grade,
        teacher=current_teacher,
    )
    return SubmissionResponse.from_submission(submission)
