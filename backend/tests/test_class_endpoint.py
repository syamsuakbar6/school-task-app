from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.core.dependencies import get_current_user
from app.db.database import get_db
from app.main import app
from app.models.user import User


@pytest.fixture()
def client_factory():
    def _build_client(db, current_user: User) -> TestClient:
        def override_get_db():
            yield db

        def override_get_current_user() -> User:
            return current_user

        app.dependency_overrides[get_db] = override_get_db
        app.dependency_overrides[get_current_user] = override_get_current_user
        return TestClient(app)

    yield _build_client
    app.dependency_overrides.clear()


def test_classes_teacher_with_assignment_sees_classes(db, teacher, open_task, client_factory):
    with client_factory(db, teacher) as client:
        response = client.get("/classes")

    assert response.status_code == 200
    payload = response.json()
    assert payload == [
        {
            "id": open_task.class_id,
            "name": "Class 1",
            "code": "C1",
            "teacher_id": teacher.id,
            "created_at": payload[0]["created_at"],
        }
    ]


def test_classes_teacher_without_assignment_returns_empty_list(db, other_teacher, open_task, client_factory):
    with client_factory(db, other_teacher) as client:
        response = client.get("/classes")

    assert response.status_code == 200
    assert response.json() == []


def test_classes_student_with_membership_sees_classes(db, student, open_task, membership, client_factory):
    with client_factory(db, student) as client:
        response = client.get("/classes")

    assert response.status_code == 200
    payload = response.json()
    assert payload == [
        {
            "id": open_task.class_id,
            "name": "Class 1",
            "code": "C1",
            "teacher_id": open_task.created_by,
            "created_at": payload[0]["created_at"],
        }
    ]


def test_classes_student_without_membership_returns_empty_list(db, client_factory):
    student = User(name="No Membership", email="nomember@example.com", password="x", role="student")
    db.add(student)
    db.commit()
    db.refresh(student)

    with client_factory(db, student) as client:
        response = client.get("/classes")

    assert response.status_code == 200
    assert response.json() == []
