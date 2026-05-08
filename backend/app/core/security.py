from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from typing import Any

import bcrypt
from jose import jwt
from passlib.context import CryptContext

from app.core.config import settings


def _patch_bcrypt_metadata() -> None:
    if not hasattr(bcrypt, "__about__"):
        bcrypt.__about__ = SimpleNamespace(
            __version__=getattr(bcrypt, "__version__", "4.3.0")
        )


_patch_bcrypt_metadata()


pwd_context = CryptContext(
    schemes=["bcrypt_sha256", "bcrypt"],
    deprecated="auto",
)


def hash_password(password: str) -> str:
    normalized_password = _normalize_password(password)
    return pwd_context.hash(normalized_password, scheme="bcrypt_sha256")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    if not hashed_password:
        return False

    normalized_password = _normalize_password(plain_password)
    try:
        return pwd_context.verify(normalized_password, hashed_password)
    except (TypeError, ValueError):
        return False


def create_access_token(
    data: dict[str, Any], expires_delta: timedelta | None = None
) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta
        if expires_delta
        else timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_access_token(token: str) -> dict[str, Any]:
    return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])


def _normalize_password(password: str) -> str:
    if not isinstance(password, str):
        raise TypeError("Password must be a string.")
    return password
