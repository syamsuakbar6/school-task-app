from __future__ import annotations

import mimetypes
from dataclasses import dataclass
from pathlib import Path
from uuid import uuid4

from fastapi import HTTPException, UploadFile, status
from fastapi.responses import StreamingResponse

from app.core.config import settings


@dataclass(slots=True)
class StoredFile:
    original_name: str
    relative_path: str       # path relatif (local) ATAU public URL (Supabase)
    absolute_path: Path | None  # None kalau pakai Supabase


# ── Supabase client (lazy init) ───────────────────────────────────────────────

_supabase_client = None


def _get_supabase():
    """Lazy init Supabase client — hanya dibuat sekali."""
    global _supabase_client
    if _supabase_client is None:
        from supabase import create_client
        _supabase_client = create_client(
            settings.SUPABASE_URL,
            settings.SUPABASE_SERVICE_ROLE_KEY,
        )
    return _supabase_client


# ── File Handler ──────────────────────────────────────────────────────────────

class FileHandler:

    # ── Validation ────────────────────────────────────────────────────────────

    @staticmethod
    def _sanitize_extension(file: UploadFile) -> str:
        if not file.filename:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="File harus memiliki nama.",
            )
        suffix = Path(file.filename).suffix.lower()
        if suffix not in settings.allowed_upload_extensions:
            allowed = ", ".join(sorted(settings.allowed_upload_extensions))
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Tipe file tidak didukung. Ekstensi yang diizinkan: {allowed}.",
            )
        return suffix

    @staticmethod
    def _validate_contents(contents: bytes) -> None:
        if not contents:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="File yang diunggah kosong.",
            )
        max_size = settings.MAX_UPLOAD_SIZE_MB * 1024 * 1024
        if len(contents) > max_size:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"Ukuran file melebihi batas {settings.MAX_UPLOAD_SIZE_MB} MB.",
            )

    # ── Upload ────────────────────────────────────────────────────────────────

    @staticmethod
    async def save_submission_upload(
        file: UploadFile,
        *,
        task_id: int,
        user_id: int,
    ) -> StoredFile:
        """
        Upload file submission.
        - Kalau Supabase dikonfigurasi → upload ke Supabase Storage.
        - Kalau tidak → fallback ke local disk.
        """
        suffix = FileHandler._sanitize_extension(file)
        contents = await file.read()
        await file.close()
        FileHandler._validate_contents(contents)

        file_name = f"{uuid4().hex}{suffix}"
        storage_path = f"submissions/task_{int(task_id)}/user_{int(user_id)}/{file_name}"

        if settings.supabase_enabled:
            return await FileHandler._upload_to_supabase(
                contents=contents,
                storage_path=storage_path,
                original_name=file.filename or file_name,
                suffix=suffix,
            )
        else:
            return FileHandler._save_to_local(
                contents=contents,
                storage_path=storage_path,
                original_name=file.filename or file_name,
            )

    @staticmethod
    async def _upload_to_supabase(
        *,
        contents: bytes,
        storage_path: str,
        original_name: str,
        suffix: str,
    ) -> StoredFile:
        """Upload ke Supabase Storage, return signed URL."""
        try:
            supabase = _get_supabase()
            content_type = mimetypes.types_map.get(suffix, "application/octet-stream")

            # Upload file ke bucket
            supabase.storage.from_(settings.SUPABASE_BUCKET).upload(
                path=storage_path,
                file=contents,
                file_options={"content-type": content_type, "upsert": "false"},
            )

            # Buat signed URL yang berlaku 1 tahun (untuk download)
            # Kita simpan path-nya saja di DB, generate signed URL saat download
            return StoredFile(
                original_name=original_name,
                relative_path=storage_path,  # simpan path, bukan URL
                absolute_path=None,
            )
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Gagal mengunggah file ke storage: {str(exc)}",
            ) from exc

    @staticmethod
    def _save_to_local(
        *,
        contents: bytes,
        storage_path: str,
        original_name: str,
    ) -> StoredFile:
        """Fallback: simpan ke local disk."""
        destination = settings.storage_path / Path(storage_path).name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(contents)

        relative = destination.relative_to(settings.storage_root).as_posix()
        return StoredFile(
            original_name=original_name,
            relative_path=relative,
            absolute_path=destination,
        )

    # ── Download / Resolve ────────────────────────────────────────────────────

    @staticmethod
    def resolve_file_path(file_path: str) -> Path:
        """
        Resolve file path untuk local storage.
        Hanya dipanggil kalau file_path bukan Supabase path.
        """
        storage_root = settings.storage_root.resolve()
        destination = (storage_root / file_path).resolve()

        if storage_root not in destination.parents and destination != storage_root:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid file path.",
            )

        if destination.exists():
            return destination

        # Legacy fallback
        legacy_relative = Path(file_path)
        if not legacy_relative.is_absolute() and ".." not in legacy_relative.parts:
            candidates = [
                settings.storage_path / legacy_relative.name,
                settings.storage_path.parent / legacy_relative,
            ]
            for candidate in candidates:
                candidate = candidate.resolve()
                if candidate.exists():
                    return candidate

        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="File tersimpan tidak ditemukan.",
        )

    @staticmethod
    def get_supabase_signed_url(file_path: str, expires_in: int = 3600) -> str:
        """
        Generate signed URL dari Supabase untuk download.
        expires_in: durasi dalam detik (default 1 jam).
        """
        try:
            supabase = _get_supabase()
            result = supabase.storage.from_(settings.SUPABASE_BUCKET).create_signed_url(
                path=file_path,
                expires_in=expires_in,
            )
            signed_url = result.get("signedURL") or result.get("signed_url")
            if not signed_url:
                raise ValueError("No signed URL in response")
            return signed_url
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Gagal membuat URL unduhan: {str(exc)}",
            ) from exc

    @staticmethod
    def is_supabase_path(file_path: str) -> bool:
        """
        Cek apakah file_path adalah Supabase storage path
        (bukan local path dan bukan URL lama).
        """
        if not file_path:
            return False
        # Supabase path kita selalu diawali 'submissions/'
        return file_path.startswith("submissions/") and not file_path.startswith("/")

    # ── Delete ────────────────────────────────────────────────────────────────

    @staticmethod
    def delete_file(file_path: str | None) -> bool:
        """Hapus file dari Supabase atau local disk."""
        if not file_path:
            return False

        if settings.supabase_enabled and FileHandler.is_supabase_path(file_path):
            return FileHandler._delete_from_supabase(file_path)

        try:
            target = FileHandler.resolve_file_path(file_path)
            target.unlink(missing_ok=True)
            return True
        except HTTPException:
            return False

    @staticmethod
    def _delete_from_supabase(file_path: str) -> bool:
        try:
            supabase = _get_supabase()
            supabase.storage.from_(settings.SUPABASE_BUCKET).remove([file_path])
            return True
        except Exception:
            return False
