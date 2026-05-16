from __future__ import annotations

from datetime import date


def default_academic_year_name(today: date | None = None) -> str:
    current = today or date.today()
    start_year = current.year if current.month >= 7 else current.year - 1
    return f"{start_year}/{start_year + 1}"
