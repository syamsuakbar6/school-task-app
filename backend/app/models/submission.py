from sqlalchemy import Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.db.database import Base
from app.utils.datetime_utils import utc_now_naive


class Submission(Base):
    __tablename__ = "submissions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id"), nullable=False, index=True)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False, index=True)
    file_path = Column(String, nullable=False)
    submitted_at = Column(DateTime, nullable=False, default=utc_now_naive)
    grade = Column(Integer, nullable=True)
    status = Column(String, nullable=True, index=True)
    version = Column(Integer, nullable=True)

    user = relationship("User", back_populates="submissions")
    task = relationship("Task", back_populates="submissions")
