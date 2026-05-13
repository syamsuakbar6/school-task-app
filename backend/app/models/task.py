from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from sqlalchemy.orm import relationship

from app.db.database import Base
from app.utils.datetime_utils import utc_now_naive


class Task(Base):
    __tablename__ = "tasks"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(String)

    creator_id = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime, default=utc_now_naive)

    creator = relationship("User", back_populates="tasks")