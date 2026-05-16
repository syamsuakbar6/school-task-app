from __future__ import annotations

from datetime import timedelta

import pytest
from sqlalchemy import create_engine
from sqlalchemy.pool import StaticPool
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings
from app.db.database import Base
from app.models.audit_log import AuditLog
from app.models.class_model import Class, ClassMembership, TeacherClassAssignment
from app.models.grade import Grade
from app.models.submission import Submission
from app.models.task import Task
from app.models.user import User
from app.utils.datetime_utils import utc_now_naive


@pytest.fixture(autouse=True)
def local_file_storage(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "STORAGE_BACKEND", "local")
    monkeypatch.setattr(settings, "STORAGE_DIR", str(tmp_path / "submissions"))


@pytest.fixture()
def db() -> Session:
    """
    Uses an isolated in-memory SQLite database for service-layer tests.
    This does not touch the local Postgres database.
    """

    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        future=True,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )

    # Ensure all models are imported before create_all
    _ = (User, Class, ClassMembership, TeacherClassAssignment, Task, Submission, Grade, AuditLog)
    Base.metadata.create_all(bind=engine)

    TestingSessionLocal = sessionmaker(
        autocommit=False,
        autoflush=False,
        expire_on_commit=False,
        bind=engine,
    )
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture()
def teacher(db: Session) -> User:
    user = User(name="Teacher", email="teacher@example.com", password="x", role="teacher")
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture()
def other_teacher(db: Session) -> User:
    user = User(name="Other Teacher", email="other-teacher@example.com", password="x", role="teacher")
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture()
def student(db: Session) -> User:
    user = User(name="Student", email="student@example.com", password="x", role="student")
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture()
def open_task(db: Session, teacher: User) -> Task:
    clazz = Class(name="Class 1", code="C1", teacher_id=teacher.id)
    db.add(clazz)
    db.commit()
    db.refresh(clazz)

    assignment = TeacherClassAssignment(teacher_id=teacher.id, class_id=clazz.id)
    db.add(assignment)
    db.commit()

    task = Task(
        title="Task 1",
        description="Test",
        # store naive timestamp (UTC) per production convention
        deadline=(utc_now_naive() + timedelta(hours=1)),
        created_by=teacher.id,
        class_id=clazz.id,
    )
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


@pytest.fixture()
def expired_task(db: Session, teacher: User) -> Task:
    clazz = Class(name="Class Expired", code="C2", teacher_id=teacher.id)
    db.add(clazz)
    db.commit()
    db.refresh(clazz)

    assignment = TeacherClassAssignment(teacher_id=teacher.id, class_id=clazz.id)
    db.add(assignment)
    db.commit()

    task = Task(
        title="Expired",
        description="Test",
        deadline=(utc_now_naive() - timedelta(hours=1)),
        created_by=teacher.id,
        class_id=clazz.id,
    )
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


@pytest.fixture()
def membership(db: Session, student: User, open_task: Task) -> ClassMembership:
    m = ClassMembership(class_id=open_task.class_id, student_id=student.id)
    db.add(m)
    db.commit()
    db.refresh(m)
    return m

