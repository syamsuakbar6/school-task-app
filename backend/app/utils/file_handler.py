from dataclasses import dataclass
from pathlib import Path
from uuid import uuid4

from fastapi import HTTPException, UploadFile, status

from app.core.config import settings


@dataclass(slots=True)
class StoredFile:
    original_name: str
    relative_path: str
    absolute_path: Path


class FileHandler:
    @staticmethod
    def _resolve_within_storage_root(relative_path: str = "") -> Path:
        storage_root = settings.storage_root.resolve()
        destination = (storage_root / relative_path).resolve() if relative_path else storage_root

        if storage_root not in destination.parents and destination != storage_root:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid file path.",
            )

        return destination

    @staticmethod
    def ensure_storage_dir(subdirectory: str = "") -> Path:
        destination = FileHandler._resolve_within_storage_root(subdirectory)
        destination.mkdir(parents=True, exist_ok=True)
        return destination

    @staticmethod
    def _sanitize_extension(file: UploadFile) -> str:
        if not file.filename:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Uploaded file must include a filename.",
            )

        suffix = Path(file.filename).suffix.lower()
        if suffix not in settings.allowed_upload_extensions:
            allowed = ", ".join(sorted(settings.allowed_upload_extensions))
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported file type. Allowed extensions: {allowed}.",
            )
        return suffix

    @staticmethod
    async def save_upload_file(file: UploadFile, subdirectory: str = "") -> StoredFile:
        suffix = FileHandler._sanitize_extension(file)
        destination_dir = FileHandler.ensure_storage_dir(subdirectory)

        contents = await file.read()
        await file.close()

        if not contents:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Uploaded file is empty.",
            )

        max_size_in_bytes = settings.MAX_UPLOAD_SIZE_MB * 1024 * 1024
        if len(contents) > max_size_in_bytes:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"File exceeds the {settings.MAX_UPLOAD_SIZE_MB} MB size limit.",
            )

        file_name = f"{uuid4().hex}{suffix}"
        absolute_path = destination_dir / file_name
        absolute_path.write_bytes(contents)

        relative_path = absolute_path.relative_to(settings.storage_root).as_posix()
        return StoredFile(
            original_name=file.filename,
            relative_path=relative_path,
            absolute_path=absolute_path,
        )

    @staticmethod
    async def save_submission_upload(
        file: UploadFile,
        *,
        task_id: int,
        user_id: int,
    ) -> StoredFile:
        safe_subdirectory = f"submissions/task_{int(task_id)}/user_{int(user_id)}"
        return await FileHandler.save_upload_file(file, subdirectory=safe_subdirectory)

    @staticmethod
    def resolve_file_path(file_path: str) -> Path:
        resolved_path = FileHandler._resolve_within_storage_root(file_path)

        if resolved_path.exists():
            return resolved_path

        legacy_relative = Path(file_path)
        if not legacy_relative.is_absolute() and ".." not in legacy_relative.parts:
            legacy_candidates = [
                settings.storage_path / legacy_relative.name,
                settings.storage_path.parent / legacy_relative,
                settings.storage_path.parent.parent / "app" / "storage" / legacy_relative,
            ]
            for candidate in legacy_candidates:
                candidate = candidate.resolve()
                if candidate.exists():
                    print(f"FILE RESOLVE LEGACY HIT: {file_path} -> {candidate}")
                    return candidate

        print(f"FILE RESOLVE MISS: {file_path} -> {resolved_path}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Stored file was not found.",
        )

    @staticmethod
    def delete_file(file_path: str | None) -> bool:
        if not file_path:
            return False

        try:
            target = FileHandler.resolve_file_path(file_path)
        except HTTPException:
            return False

        target.unlink(missing_ok=True)
        return True
