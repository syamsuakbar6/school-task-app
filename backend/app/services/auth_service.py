from datetime import timedelta

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import create_access_token, hash_password, verify_password
from app.models.user import User, UserRole
from app.schemas.user_schema import UserCreate


class AuthService:
    @staticmethod
    def get_user_by_id(db: Session, user_id: int) -> User | None:
        return db.scalar(select(User).where(User.id == user_id))

    @staticmethod
    def get_user_by_identifier(db: Session, identifier: str) -> User | None:
        """Cari user berdasarkan NISN (10 digit) atau NIP (18 digit)."""
        identifier = identifier.strip()
        if len(identifier) == 10 and identifier.isdigit():
            return db.scalar(select(User).where(User.nisn == identifier))
        if len(identifier) == 18 and identifier.isdigit():
            return db.scalar(select(User).where(User.nip == identifier))
        return None

    @staticmethod
    def register_user(db: Session, user_in: UserCreate) -> User:
        role = AuthService._normalize_role(user_in.role)

        # Cek duplikat NISN
        if user_in.nisn:
            existing = db.scalar(select(User).where(User.nisn == user_in.nisn))
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="NISN sudah terdaftar.",
                )

        # Cek duplikat NIP
        if user_in.nip:
            existing = db.scalar(select(User).where(User.nip == user_in.nip))
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="NIP sudah terdaftar.",
                )

        # Cek duplikat email kalau diisi
        if user_in.email:
            email = user_in.email.lower().strip()
            existing = db.scalar(select(User).where(User.email == email))
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Email sudah terdaftar.",
                )
        else:
            email = None

        user = User(
            name=user_in.name.strip(),
            email=email,
            nisn=user_in.nisn,
            nip=user_in.nip,
            role=role.value,
            password=hash_password(user_in.password),
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    @staticmethod
    def authenticate_user(db: Session, identifier: str, password: str) -> User:
        user = AuthService.get_user_by_identifier(db, identifier)
        if user is None or not verify_password(password, user.password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="NISN/NIP atau password salah.",
            )
        return user

    @staticmethod
    def build_login_response(user: User) -> dict[str, str]:
        access_token = create_access_token(
            data={
                "sub": str(user.id),
                "role": user.role,
                "nisn": user.nisn,
                "nip": user.nip,
            },
            expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        )
        return {
            "access_token": access_token,
            "token_type": "bearer",
        }

    @staticmethod
    def _normalize_role(role: UserRole | str) -> UserRole:
        normalized = str(role).lower()
        try:
            return UserRole(normalized)
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Role harus 'student' atau 'teacher'.",
            ) from exc
