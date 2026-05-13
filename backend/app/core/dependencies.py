from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import ExpiredSignatureError, JWTError
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.db.database import get_db
from app.models.user import User, UserRole
from app.services.auth_service import AuthService
from app.services.class_access_service import ClassAccessService


bearer_scheme = HTTPBearer(auto_error=False)
DBSession = Annotated[Session, Depends(get_db)]


def get_current_user(
    db: DBSession,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if credentials is None:
        raise credentials_exception

    try:
        payload = decode_access_token(credentials.credentials)
    except ExpiredSignatureError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
    except JWTError as exc:
        raise credentials_exception from exc

    subject = payload.get("sub")
    role = payload.get("role")

    if subject is None or role is None:
        raise credentials_exception

    try:
        user_id = int(subject)
    except (TypeError, ValueError) as exc:
        raise credentials_exception from exc

    user = AuthService.get_user_by_id(db, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )

    user_role = UserRole(ClassAccessService.normalize_role(user.role))
    token_role = UserRole(ClassAccessService.normalize_role(role))

    if user_role != token_role:
        raise credentials_exception

    return user


def require_teacher(current_user: Annotated[User, Depends(get_current_user)]) -> User:
    ClassAccessService.assert_user_role(
        current_user,
        expected_role=UserRole.TEACHER,
        detail="Teacher access is required.",
    )
    return current_user


def require_student(current_user: Annotated[User, Depends(get_current_user)]) -> User:
    ClassAccessService.assert_user_role(
        current_user,
        expected_role=UserRole.STUDENT,
        detail="Student access is required.",
    )
    return current_user
