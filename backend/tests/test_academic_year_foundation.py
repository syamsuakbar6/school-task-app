from __future__ import annotations

from datetime import date

import pytest
from fastapi import HTTPException
from sqlalchemy import select

from app.models.class_model import AcademicYear, Class, ClassMembership, TeacherClassAssignment
from app.models.submission import Submission
from app.models.task import Task
from app.models.user import User
from app.routers.admin import (
    CreateClassRequest,
    UpdateClassRequest,
    _assert_active_class_name_available,
    commit_promotion,
    create_class,
    preview_promotion,
    update_class,
)
from app.schemas.promotion_schema import PromotionCommitRequest, PromotionPreviewRequest
from app.services.academic_year_service import AcademicYearService
from app.services.class_service import ClassService
from app.services.grading_service import GradingService
from app.services.submission_service import SubmissionService
from app.services.task_service import TaskService
from app.utils.academic_year_utils import default_academic_year_name
from app.utils.class_name_utils import build_class_code, build_class_name, parse_class_name


def test_default_academic_year_name_uses_july_boundary():
    assert default_academic_year_name(date(2026, 5, 16)) == "2025/2026"
    assert default_academic_year_name(date(2026, 7, 1)) == "2026/2027"


def test_class_name_helpers_generate_and_parse_flexible_major():
    class_name = build_class_name(
        grade_level="xi",
        major=" rekayasa perangkat lunak ",
        section=" 1 ",
    )

    assert class_name == "XI REKAYASA PERANGKAT LUNAK 1"
    assert build_class_code(class_name) == "XIREKAYASAPERANGKATLUNAK1"
    assert parse_class_name(class_name) == (
        "XI",
        "REKAYASA PERANGKAT LUNAK",
        "1",
    )


def test_ensure_default_academic_year_creates_active_year_and_assigns_existing_classes(db, teacher):
    legacy_class = Class(name="X RPL 1", code="XRPL1", teacher_id=teacher.id)
    db.add(legacy_class)
    db.commit()
    db.refresh(legacy_class)

    academic_year = AcademicYearService.ensure_default_academic_year(db)
    db.refresh(legacy_class)

    assert academic_year.is_active is True
    assert academic_year.name == default_academic_year_name()
    assert legacy_class.academic_year_id == academic_year.id


def test_accessible_classes_default_to_active_academic_year(db):
    active_year = AcademicYear(name="2025/2026", is_active=True)
    old_year = AcademicYear(name="2024/2025", is_active=False)
    student = User(name="Student", email="year-student@example.com", password="x", role="student")
    teacher = User(name="Teacher", email="year-teacher@example.com", password="x", role="teacher")
    db.add_all([active_year, old_year, student, teacher])
    db.flush()

    active_class = Class(
        name="XI RPL 1",
        code="XIRPL1",
        teacher_id=teacher.id,
        academic_year_id=active_year.id,
    )
    old_class = Class(
        name="X RPL 1",
        code="XRPL1",
        teacher_id=teacher.id,
        academic_year_id=old_year.id,
    )
    db.add_all([active_class, old_class])
    db.flush()
    db.add_all([
        ClassMembership(class_id=active_class.id, student_id=student.id),
        ClassMembership(class_id=old_class.id, student_id=student.id),
    ])
    db.commit()

    classes = ClassService.get_classes(db, current_user=student)

    assert [clazz.id for clazz in classes] == [active_class.id]


def test_active_class_name_must_be_unique_within_same_academic_year(db, teacher):
    year_one = AcademicYear(name="2025/2026", is_active=True)
    year_two = AcademicYear(name="2026/2027", is_active=False)
    db.add_all([year_one, year_two])
    db.flush()
    db.add(Class(
        name="X RPL 1",
        code="XRPL1",
        teacher_id=teacher.id,
        academic_year_id=year_one.id,
    ))
    db.commit()

    with pytest.raises(HTTPException) as exc_info:
        _assert_active_class_name_available(
            db,
            normalized_name="X RPL 1",
            academic_year_id=year_one.id,
        )

    assert exc_info.value.status_code == 400

    _assert_active_class_name_available(
        db,
        normalized_name="X RPL 1",
        academic_year_id=year_two.id,
    )


def test_admin_class_create_and_update_store_structured_class_parts(db, teacher):
    created = create_class(
        CreateClassRequest(grade_level="x", major="rpl", section="1"),
        db,
        teacher,
    )

    assert created.name == "X RPL 1"
    assert created.code == "XRPL1"
    assert created.grade_level == "X"
    assert created.major == "RPL"
    assert created.section == "1"

    updated = update_class(
        created.id,
        UpdateClassRequest(grade_level="XI", major="DPIB", section="2"),
        db,
        teacher,
    )

    assert updated.name == "XI DPIB 2"
    assert updated.grade_level == "XI"
    assert updated.major == "DPIB"
    assert updated.section == "2"


def test_promotion_preview_maps_students_to_next_class_and_alumni(db, teacher):
    source_year = AcademicYear(name="2025/2026", is_active=True)
    target_year = AcademicYear(name="2026/2027", is_active=False)
    student_x = User(
        name="Siswa X",
        email="siswax@example.com",
        password="x",
        role="student",
        nisn="0000000001",
    )
    student_xii = User(
        name="Siswa XII",
        email="siswaxii@example.com",
        password="x",
        role="student",
        nisn="0000000002",
    )
    db.add_all([source_year, target_year, student_x, student_xii])
    db.flush()
    class_x = Class(
        name="X RPL 1",
        code="XRPL1",
        grade_level="X",
        major="RPL",
        section="1",
        teacher_id=teacher.id,
        academic_year_id=source_year.id,
    )
    class_xii = Class(
        name="XII TKJ 3",
        code="XIITKJ3",
        grade_level="XII",
        major="TKJ",
        section="3",
        teacher_id=teacher.id,
        academic_year_id=source_year.id,
    )
    db.add_all([class_x, class_xii])
    db.flush()
    db.add_all([
        ClassMembership(class_id=class_x.id, student_id=student_x.id),
        ClassMembership(class_id=class_xii.id, student_id=student_xii.id),
    ])
    db.commit()

    preview = preview_promotion(
        PromotionPreviewRequest(
            source_academic_year_id=source_year.id,
            target_academic_year_id=target_year.id,
        ),
        db,
        teacher,
    )

    assert preview.student_count == 2
    assert preview.alumni_count == 1
    class_by_name = {item.source_class_name: item for item in preview.classes}
    assert class_by_name["X RPL 1"].promoted_target_class_name == "XI RPL 1"
    assert class_by_name["X RPL 1"].retained_target_class_name == "X RPL 1"
    assert class_by_name["X RPL 1"].students[0].selected is True
    assert class_by_name["XII TKJ 3"].default_action == "graduate"
    assert class_by_name["XII TKJ 3"].students[0].will_be_alumni is True


def test_promotion_commit_creates_target_memberships_archives_source_and_marks_alumni(
    db,
    teacher,
):
    source_year = AcademicYear(name="2025/2026", is_active=True)
    target_year = AcademicYear(name="2026/2027", is_active=False)
    student_promoted = User(
        name="Naik",
        email="naik@example.com",
        password="x",
        role="student",
        nisn="0000000011",
    )
    student_retained = User(
        name="Tidak Naik",
        email="tidaknaik@example.com",
        password="x",
        role="student",
        nisn="0000000012",
    )
    student_alumni = User(
        name="Lulus",
        email="lulus@example.com",
        password="x",
        role="student",
        nisn="0000000013",
    )
    db.add_all([source_year, target_year, student_promoted, student_retained, student_alumni])
    db.flush()
    class_x = Class(
        name="X RPL 1",
        code="XRPL1",
        grade_level="X",
        major="RPL",
        section="1",
        teacher_id=teacher.id,
        academic_year_id=source_year.id,
    )
    class_xii = Class(
        name="XII RPL 1",
        code="XIIRPL1",
        grade_level="XII",
        major="RPL",
        section="1",
        teacher_id=teacher.id,
        academic_year_id=source_year.id,
    )
    db.add_all([class_x, class_xii])
    db.flush()
    db.add(TeacherClassAssignment(teacher_id=teacher.id, class_id=class_x.id))
    db.add_all([
        ClassMembership(class_id=class_x.id, student_id=student_promoted.id),
        ClassMembership(class_id=class_x.id, student_id=student_retained.id),
        ClassMembership(class_id=class_xii.id, student_id=student_alumni.id),
    ])
    db.commit()

    result = commit_promotion(
        PromotionCommitRequest(
            source_academic_year_id=source_year.id,
            target_academic_year_id=target_year.id,
            not_promoted_student_ids=[student_retained.id],
        ),
        db,
        teacher,
    )

    db.refresh(source_year)
    db.refresh(target_year)
    db.refresh(class_x)
    db.refresh(class_xii)
    db.refresh(student_alumni)
    assert result.created_class_count == 2
    assert result.membership_created_count == 2
    assert result.alumni_count == 1
    assert result.archived_class_count == 2
    assert source_year.is_active is False
    assert target_year.is_active is True
    assert class_x.is_archived is True
    assert class_xii.is_archived is True
    assert student_alumni.is_alumni is True

    promoted_class = db.scalar(select(Class).where(Class.name == "XI RPL 1"))
    retained_class = db.scalar(
        select(Class).where(
            Class.name == "X RPL 1",
            Class.academic_year_id == target_year.id,
        )
    )
    assert promoted_class is not None
    assert retained_class is not None
    assert db.scalar(
        select(ClassMembership).where(
            ClassMembership.class_id == promoted_class.id,
            ClassMembership.student_id == student_promoted.id,
        )
    ) is not None
    assert db.scalar(
        select(ClassMembership).where(
            ClassMembership.class_id == retained_class.id,
            ClassMembership.student_id == student_retained.id,
        )
    ) is not None
    assert db.scalar(
        select(ClassMembership).where(
            ClassMembership.class_id == class_x.id,
            ClassMembership.student_id == student_promoted.id,
        )
    ) is not None
    assert db.scalar(
        select(TeacherClassAssignment).where(
            TeacherClassAssignment.class_id == promoted_class.id,
            TeacherClassAssignment.teacher_id == teacher.id,
        )
    ) is not None

    second_result = commit_promotion(
        PromotionCommitRequest(
            source_academic_year_id=source_year.id,
            target_academic_year_id=target_year.id,
            not_promoted_student_ids=[student_retained.id],
        ),
        db,
        teacher,
    )

    assert second_result.created_class_count == 0
    assert second_result.membership_created_count == 0
    assert second_result.alumni_count == 0
    assert second_result.archived_class_count == 0


def test_task_history_filter_includes_archived_old_year_class(db, teacher):
    old_year = AcademicYear(name="2025/2026", is_active=False)
    active_year = AcademicYear(name="2026/2027", is_active=True)
    student = User(
        name="History Student",
        email="history-student@example.com",
        password="x",
        role="student",
        nisn="0000000021",
    )
    db.add_all([old_year, active_year, student])
    db.flush()
    old_class = Class(
        name="X RPL 1",
        code="XRPL1",
        grade_level="X",
        major="RPL",
        section="1",
        teacher_id=teacher.id,
        academic_year_id=old_year.id,
        is_archived=True,
    )
    active_class = Class(
        name="XI RPL 1",
        code="XIRPL1",
        grade_level="XI",
        major="RPL",
        section="1",
        teacher_id=teacher.id,
        academic_year_id=active_year.id,
    )
    db.add_all([old_class, active_class])
    db.flush()
    db.add_all([
        ClassMembership(class_id=old_class.id, student_id=student.id),
        ClassMembership(class_id=active_class.id, student_id=student.id),
        Task(
            title="Tugas Lama",
            description="Riwayat",
            created_by=teacher.id,
            class_id=old_class.id,
        ),
        Task(
            title="Tugas Aktif",
            description="Sekarang",
            created_by=teacher.id,
            class_id=active_class.id,
        ),
    ])
    db.commit()

    current_tasks = TaskService.get_all_tasks(db, current_user=student)
    history_tasks = TaskService.get_all_tasks(
        db,
        current_user=student,
        academic_year_id=old_year.id,
    )

    assert [task.title for task in current_tasks] == ["Tugas Aktif"]
    assert [task.title for task in history_tasks] == ["Tugas Lama"]


def test_history_task_is_readable_but_write_actions_stay_active_only(db, teacher):
    old_year = AcademicYear(name="2025/2026", is_active=False)
    active_year = AcademicYear(name="2026/2027", is_active=True)
    student = User(
        name="History Read Only",
        email="history-read-only@example.com",
        password="x",
        role="student",
        nisn="0000000022",
    )
    db.add_all([old_year, active_year, student])
    db.flush()
    old_class = Class(
        name="X RPL 1",
        code="XRPL1",
        grade_level="X",
        major="RPL",
        section="1",
        teacher_id=teacher.id,
        academic_year_id=old_year.id,
        is_archived=True,
    )
    db.add(old_class)
    db.flush()
    old_task = Task(
        title="Tugas Riwayat",
        description="Lama",
        created_by=teacher.id,
        class_id=old_class.id,
    )
    db.add_all([
        ClassMembership(class_id=old_class.id, student_id=student.id),
        TeacherClassAssignment(class_id=old_class.id, teacher_id=teacher.id),
        old_task,
    ])
    db.flush()
    old_submission = Submission(
        task_id=old_task.id,
        class_id=old_class.id,
        user_id=student.id,
        file_path="submissions/history.pdf",
        status="submitted",
        version=1,
    )
    db.add(old_submission)
    db.commit()

    assert TaskService.get_task_by_id(db, old_task.id, current_user=student).id == old_task.id
    assert SubmissionService.can_submit(db, student=student, task=old_task) is False
    assert GradingService.can_grade_submission(
        db,
        teacher=teacher,
        submission=old_submission,
    ) is False
