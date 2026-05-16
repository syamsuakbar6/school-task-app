from __future__ import annotations

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.db.database import Base
from app.utils.datetime_utils import utc_now_naive


class Class(Base):
    __tablename__ = "classes"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    code = Column(String, nullable=True, index=True)
    # Legacy column kept for schema compatibility only; access control must use teacher_class_assignments.
    teacher_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    created_at = Column(DateTime, nullable=True, default=utc_now_naive)
    is_archived = Column(Boolean, nullable=False, default=False, index=True)
    archived_at = Column(DateTime, nullable=True)

    teacher = relationship("User")


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

