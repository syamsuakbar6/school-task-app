from datetime import datetime, timezone
from email_validator import EmailNotValidError, validate_email
from uuid import uuid4


def format_datetime(dt: datetime) -> str:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).isoformat()


def paginate(items: list, page: int = 1, page_size: int = 10) -> dict:
    safe_page = max(page, 1)
    safe_page_size = max(page_size, 1)
    start = (safe_page - 1) * safe_page_size
    end = start + safe_page_size
    return {
        "items": items[start:end],
        "page": safe_page,
        "page_size": safe_page_size,
        "total": len(items),
    }


def is_valid_email(email: str) -> bool:
    try:
        validate_email(email, check_deliverability=False)
    except EmailNotValidError:
        return False
    return True


def generate_unique_id() -> str:
    return uuid4().hex
