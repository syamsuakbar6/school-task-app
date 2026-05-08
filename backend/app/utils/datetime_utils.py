from __future__ import annotations

from datetime import datetime, timezone


def utc_now_aware() -> datetime:
    return datetime.now(timezone.utc)


def utc_now_naive() -> datetime:
    # Existing schema stores naive UTC timestamps, so we normalize here explicitly.
    return utc_now_aware().replace(tzinfo=None)
