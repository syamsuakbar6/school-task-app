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
    def get_user_by_email(db: Session, email: str) -> User | None:
        return db.scalar(select(User).where(User.email == email))

    @staticmethod
    def register_user(db: Session, user_in: UserCreate) -> User:
        email = user_in.email.lower().strip()
        role = AuthService._normalize_role(user_in.role)

        existing_user = db.scalar(select(User).where(User.email == email))
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email is already registered.",
            )

        user = User(
            name=user_in.name.strip(),
            email=email,
            role=role.value,
            password=hash_password(user_in.password),
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    @staticmethod
    def authenticate_user(db: Session, email: str, password: str) -> User:
        user = db.scalar(select(User).where(User.email == email.lower().strip()))
        if user is None or not verify_password(password, user.password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password.",
            )
        return user

    @staticmethod
    def build_login_response(user: User) -> dict[str, str]:
        access_token = create_access_token(
            data={"sub": str(user.id), "role": user.role, "email": user.email},
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
                detail="Role must be either 'student' or 'teacher'.",
            ) from exc
