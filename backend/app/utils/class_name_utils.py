from __future__ import annotations

import re


VALID_GRADE_LEVELS = {"X", "XI", "XII"}


def normalize_class_name(value: str) -> str:
    return " ".join(value.strip().split())


def normalize_grade_level(value: str) -> str:
    normalized = value.strip().upper()
    if normalized not in VALID_GRADE_LEVELS:
        raise ValueError("Tingkat kelas harus X, XI, atau XII.")
    return normalized


def normalize_class_part(value: str) -> str:
    return " ".join(value.strip().upper().split())


def build_class_name(*, grade_level: str, major: str, section: str) -> str:
    normalized_grade = normalize_grade_level(grade_level)
    normalized_major = normalize_class_part(major)
    normalized_section = normalize_class_part(section)
    if not normalized_major:
        raise ValueError("Jurusan wajib diisi.")
    if not normalized_section:
        raise ValueError("Nomor kelas wajib diisi.")
    return f"{normalized_grade} {normalized_major} {normalized_section}"


def build_class_code(class_name: str) -> str:
    return re.sub(r"[^A-Z0-9]", "", normalize_class_name(class_name).upper())


def parse_class_name(class_name: str) -> tuple[str, str, str] | None:
    parts = normalize_class_name(class_name).split(" ")
    if len(parts) < 3:
        return None
    grade_level = parts[0].upper()
    if grade_level not in VALID_GRADE_LEVELS:
        return None
    section = parts[-1].upper()
    major = " ".join(parts[1:-1]).upper()
    if not major or not section:
        return None
    return grade_level, major, section
