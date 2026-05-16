from __future__ import annotations

from sqlalchemy import Boolean, Column, Date, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.db.database import Base
from app.utils.datetime_utils import utc_now_naive


class AcademicYear(Base):
    __tablename__ = "academic_years"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, unique=True, index=True)
    starts_at = Column(Date, nullable=True)
    ends_at = Column(Date, nullable=True)
    is_active = Column(Boolean, nullable=False, default=False, index=True)
    created_at = Column(DateTime, nullable=True, default=utc_now_naive)


class Class(Base):
    __tablename__ = "classes"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    code = Column(String, nullable=True, index=True)
    grade_level = Column(String, nullable=True, index=True)
    major = Column(String, nullable=True, index=True)
    section = Column(String, nullable=True)
    academic_year_id = Column(
        Integer,
        ForeignKey("academic_years.id"),
        nullable=True,
        index=True,
    )
    # Legacy column kept for schema compatibility only; access control must use teacher_class_assignments.
    teacher_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, nullable=True, default=utc_now_naive)
    is_archived = Column(Boolean, nullable=False, default=False, index=True)
    archived_at = Column(DateTime, nullable=True)

    academic_year = relationship("AcademicYear")
    teacher = relationship("User")

    @property
    def academic_year_name(self) -> str | None:
        if self.academic_year is None:
            return None
        return self.academic_year.name


class ClassMembership(Base):
    __tablename__ = "class_memberships"

    id = Column(Integer, primary_key=True, index=True)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False, index=True)
    student_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    joined_at = Column(DateTime, nullable=True, default=utc_now_naive)

    clazz = relationship("Class")
    student = relationship("User")


class TeacherClassAssignment(Base):
    __tablename__ = "teacher_class_assignments"

    teacher_id = Column(Integer, ForeignKey("users.id"), primary_key=True, index=True)
    class_id = Column(Integer, ForeignKey("classes.id"), primary_key=True, index=True)

    teacher = relationship("User")
    clazz = relationship("Class")

