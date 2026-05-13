from enum import StrEnum

from sqlalchemy import Column, DateTime, Integer, String
from sqlalchemy.orm import relationship

from app.db.database import Base
from app.utils.datetime_utils import utc_now_naive


class UserRole(StrEnum):
    STUDENT = "student"
    TEACHER = "teacher"


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, nullable=True, unique=True, index=True)
    nisn = Column(String(10), nullable=True, unique=True, index=True)
    nip = Column(String(18), nullable=True, unique=True, index=True)
    password = Column(String, nullable=False)
    role = Column(String, nullable=False)
    created_at = Column(DateTime, nullable=False, default=utc_now_naive)

    tasks = relationship("Task", back_populates="creator")
    submissions = relationship("Submission", back_populates="user")
