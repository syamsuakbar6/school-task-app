from __future__ import annotations

from datetime import date

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.class_model import AcademicYear, Class
from app.utils.academic_year_utils import default_academic_year_name


class AcademicYearService:
    @staticmethod
    def list_academic_years(db: Session) -> list[AcademicYear]:
        return list(
            db.scalars(
                select(AcademicYear).order_by(
                    AcademicYear.is_active.desc(),
                    AcademicYear.created_at.desc(),
                    AcademicYear.id.desc(),
                )
            ).all()
        )

    @staticmethod
    def get_active_academic_year(db: Session) -> AcademicYear | None:
        return db.scalar(
            select(AcademicYear)
            .where(AcademicYear.is_active.is_(True))
            .order_by(AcademicYear.id.asc())
        )

    @staticmethod
    def get_academic_year_or_404(db: Session, academic_year_id: int) -> AcademicYear:
        academic_year = db.scalar(
            select(AcademicYear).where(AcademicYear.id == academic_year_id)
        )
        if academic_year is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Tahun ajaran tidak ditemukan.",
            )
        return academic_year

    @staticmethod
    def ensure_default_academic_year(db: Session) -> AcademicYear:
        active = AcademicYearService.get_active_academic_year(db)
        if active is None:
            existing = db.scalar(select(AcademicYear).order_by(AcademicYear.id.asc()))
            if existing is None:
                existing = AcademicYear(
                    name=default_academic_year_name(),
                    is_active=True,
                )
                db.add(existing)
                db.flush()
            else:
                existing.is_active = True
                db.add(existing)
                db.flush()
            active = existing

        db.query(Class).filter(Class.academic_year_id.is_(None)).update(
            {Class.academic_year_id: active.id},
            synchronize_session=False,
        )
        db.commit()
        db.refresh(active)
        return active

    @staticmethod
    def create_academic_year(
        db: Session,
        *,
        name: str,
        starts_at: date | None = None,
        ends_at: date | None = None,
        is_active: bool = False,
    ) -> AcademicYear:
        normalized_name = " ".join(name.strip().split())
        if not normalized_name:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Nama tahun ajaran wajib diisi.",
            )
        if starts_at is not None and ends_at is not None and starts_at > ends_at:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Tanggal mulai tidak boleh setelah tanggal selesai.",
            )
        existing = db.scalar(
            select(AcademicYear).where(func.lower(AcademicYear.name) == normalized_name.lower())
        )
        if existing is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Tahun ajaran sudah ada.",
            )

        if is_active:
            db.query(AcademicYear).update(
                {AcademicYear.is_active: False},
                synchronize_session=False,
            )

        academic_year = AcademicYear(
            name=normalized_name,
            starts_at=starts_at,
            ends_at=ends_at,
            is_active=is_active,
        )
        db.add(academic_year)
        db.commit()
        db.refresh(academic_year)
        return academic_year

    @staticmethod
    def set_active_academic_year(db: Session, *, academic_year_id: int) -> AcademicYear:
        academic_year = AcademicYearService.get_academic_year_or_404(
            db,
            academic_year_id,
        )
        db.query(AcademicYear).update(
            {AcademicYear.is_active: False},
            synchronize_session=False,
        )
        academic_year.is_active = True
        db.add(academic_year)
        db.commit()
        db.refresh(academic_year)
        return academic_year
