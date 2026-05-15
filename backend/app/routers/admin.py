from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, delete
from sqlalchemy.orm import Session

from app.core.dependencies import DBSession, get_current_user
from app.core.security import hash_password
from app.models.class_model import Class, ClassMembership, TeacherClassAssignment
from app.models.user import User, UserRole
from app.schemas.user_schema import UserResponse
from pydantic import BaseModel, Field


router = APIRouter(prefix="/admin", tags=["Admin"])


# ── Guards ────────────────────────────────────────────────────────────────────

def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if str(current_user.role).lower() != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required.",
        )
    return current_user


# ── Schemas ───────────────────────────────────────────────────────────────────

class CreateStudentRequest(BaseModel):
    name: str = Field(min_length=3, max_length=100)
    nisn: str = Field(min_length=10, max_length=10, pattern=r'^\d{10}$')


class CreateClassRequest(BaseModel):
    name: str = Field(min_length=3, max_length=100)
    code: str = Field(min_length=1, max_length=20)


class StudentResponse(BaseModel):
    id: int
    name: str
    nisn: str | None
    role: str

    class Config:
        from_attributes = True


class TeacherResponse(BaseModel):
    id: int
    name: str
    nip: str | None
    role: str

    class Config:
        from_attributes = True


class ClassResponse(BaseModel):
    id: int
    name: str
    code: str | None
    teacher_id: int | None = None

    class Config:
        from_attributes = True


class ClassWithStudentsResponse(BaseModel):
    id: int
    name: str
    code: str | None
    students: list[StudentResponse] = Field(default_factory=list)
    teachers: list[TeacherResponse] = Field(default_factory=list)

    class Config:
        from_attributes = True


# ── User endpoints ────────────────────────────────────────────────────────────

@router.get("/users", response_model=list[UserResponse])
def list_all_users(
    db: DBSession,
    _: User = Depends(require_admin),
) -> list[UserResponse]:
    users = db.scalars(select(User).order_by(User.created_at.desc())).all()
    return [UserResponse.model_validate(u) for u in users]


@router.post("/students", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_student(
    payload: CreateStudentRequest,
    db: DBSession,
    _: User = Depends(require_admin),
) -> UserResponse:
    # Cek duplikat NISN
    existing = db.scalar(select(User).where(User.nisn == payload.nisn))
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="NISN sudah terdaftar.",
        )

    # Password default = NISN
    student = User(
        name=payload.name.strip(),
        nisn=payload.nisn,
        role=UserRole.STUDENT.value,
        password=hash_password(payload.nisn),
    )
    db.add(student)
    db.commit()
    db.refresh(student)
    return UserResponse.model_validate(student)


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    user_id: int,
    db: DBSession,
    current_admin: User = Depends(require_admin),
) -> None:
    if user_id == current_admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tidak bisa menghapus akun sendiri.",
        )

    user = db.scalar(select(User).where(User.id == user_id))
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User tidak ditemukan.",
        )

    # Hapus relasi kelas dulu sebelum hapus user
    db.execute(delete(ClassMembership).where(ClassMembership.student_id == user_id))
    db.execute(delete(TeacherClassAssignment).where(TeacherClassAssignment.teacher_id == user_id))
    db.delete(user)
    db.commit()


# ── Class endpoints ───────────────────────────────────────────────────────────

@router.get("/classes", response_model=list[ClassWithStudentsResponse])
def list_all_classes(
    db: DBSession,
    _: User = Depends(require_admin),
) -> list[ClassWithStudentsResponse]:
    classes = db.scalars(select(Class).order_by(Class.created_at.desc())).all()
    result = []
    for c in classes:
        memberships = db.scalars(
            select(ClassMembership).where(ClassMembership.class_id == c.id)
        ).all()
        student_ids = [m.student_id for m in memberships]
        students = []
        if student_ids:
            students = db.scalars(
                select(User).where(User.id.in_(student_ids))
            ).all()
        assignments = db.scalars(
            select(TeacherClassAssignment).where(TeacherClassAssignment.class_id == c.id)
        ).all()
        teacher_ids = [a.teacher_id for a in assignments]
        teachers = []
        if teacher_ids:
            teachers = db.scalars(
                select(User).where(User.id.in_(teacher_ids))
            ).all()
        result.append(ClassWithStudentsResponse(
            id=c.id,
            name=c.name,
            code=c.code,
            students=[StudentResponse.model_validate(s) for s in students],
            teachers=[TeacherResponse.model_validate(t) for t in teachers],
        ))
    return result


@router.post("/classes", response_model=ClassResponse, status_code=status.HTTP_201_CREATED)
def create_class(
    payload: CreateClassRequest,
    db: DBSession,
    current_admin: User = Depends(require_admin),
) -> ClassResponse:
    existing = db.scalar(select(Class).where(Class.code == payload.code))
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Kode kelas sudah digunakan.",
        )

    new_class = Class(
        name=payload.name.strip(),
        code=payload.code.strip().upper(),
        teacher_id=current_admin.id,
    )
    db.add(new_class)
    db.commit()
    db.refresh(new_class)
    return ClassResponse.model_validate(new_class)


@router.delete("/classes/{class_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_class(
    class_id: int,
    db: DBSession,
    _: User = Depends(require_admin),
) -> None:
    cls = db.scalar(select(Class).where(Class.id == class_id))
    if cls is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Kelas tidak ditemukan.",
        )
    db.execute(delete(ClassMembership).where(ClassMembership.class_id == class_id))
    db.execute(delete(TeacherClassAssignment).where(TeacherClassAssignment.class_id == class_id))
    db.delete(cls)
    db.commit()


# ── Assign endpoints ──────────────────────────────────────────────────────────

@router.get("/classes/{class_id}/students", response_model=list[StudentResponse])
def list_students_in_class(
    class_id: int,
    db: DBSession,
    _: User = Depends(require_admin),
) -> list[StudentResponse]:
    memberships = db.scalars(
        select(ClassMembership).where(ClassMembership.class_id == class_id)
    ).all()
    student_ids = [m.student_id for m in memberships]
    if not student_ids:
        return []
    students = db.scalars(select(User).where(User.id.in_(student_ids))).all()
    return [StudentResponse.model_validate(s) for s in students]


@router.post(
    "/classes/{class_id}/students/{student_id}",
    status_code=status.HTTP_201_CREATED,
)
def assign_student_to_class(
    class_id: int,
    student_id: int,
    db: DBSession,
    _: User = Depends(require_admin),
) -> dict:
    cls = db.scalar(select(Class).where(Class.id == class_id))
    if cls is None:
        raise HTTPException(status_code=404, detail="Kelas tidak ditemukan.")

    student = db.scalar(select(User).where(User.id == student_id))
    if student is None or str(student.role).lower() != UserRole.STUDENT.value:
        raise HTTPException(status_code=404, detail="Siswa tidak ditemukan.")

    existing = db.scalar(
        select(ClassMembership).where(
            ClassMembership.class_id == class_id,
            ClassMembership.student_id == student_id,
        )
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Siswa sudah terdaftar di kelas ini.",
        )

    membership = ClassMembership(class_id=class_id, student_id=student_id)
    db.add(membership)
    db.commit()
    return {"message": "Siswa berhasil ditambahkan ke kelas."}


@router.delete(
    "/classes/{class_id}/students/{student_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def remove_student_from_class(
    class_id: int,
    student_id: int,
    db: DBSession,
    _: User = Depends(require_admin),
) -> None:
    membership = db.scalar(
        select(ClassMembership).where(
            ClassMembership.class_id == class_id,
            ClassMembership.student_id == student_id,
        )
    )
    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Siswa tidak terdaftar di kelas ini.",
        )
    db.delete(membership)
    db.commit()


@router.get("/classes/{class_id}/teachers", response_model=list[TeacherResponse])
def list_teachers_in_class(
    class_id: int,
    db: DBSession,
    _: User = Depends(require_admin),
) -> list[TeacherResponse]:
    cls = db.scalar(select(Class).where(Class.id == class_id))
    if cls is None:
        raise HTTPException(status_code=404, detail="Kelas tidak ditemukan.")

    assignments = db.scalars(
        select(TeacherClassAssignment).where(TeacherClassAssignment.class_id == class_id)
    ).all()
    teacher_ids = [a.teacher_id for a in assignments]
    if not teacher_ids:
        return []
    teachers = db.scalars(select(User).where(User.id.in_(teacher_ids))).all()
    return [TeacherResponse.model_validate(t) for t in teachers]


@router.post(
    "/classes/{class_id}/teachers/{teacher_id}",
    status_code=status.HTTP_201_CREATED,
)
def assign_teacher_to_class(
    class_id: int,
    teacher_id: int,
    db: DBSession,
    _: User = Depends(require_admin),
) -> dict:
    cls = db.scalar(select(Class).where(Class.id == class_id))
    if cls is None:
        raise HTTPException(status_code=404, detail="Kelas tidak ditemukan.")

    teacher = db.scalar(select(User).where(User.id == teacher_id))
    if teacher is None or str(teacher.role).lower() != UserRole.TEACHER.value:
        raise HTTPException(status_code=404, detail="Guru tidak ditemukan.")

    existing = db.scalar(
        select(TeacherClassAssignment).where(
            TeacherClassAssignment.class_id == class_id,
            TeacherClassAssignment.teacher_id == teacher_id,
        )
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Guru sudah terdaftar di kelas ini.",
        )

    assignment = TeacherClassAssignment(class_id=class_id, teacher_id=teacher_id)
    db.add(assignment)
    db.commit()
    return {"message": "Guru berhasil ditambahkan ke kelas."}


@router.delete(
    "/classes/{class_id}/teachers/{teacher_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def remove_teacher_from_class(
    class_id: int,
    teacher_id: int,
    db: DBSession,
    _: User = Depends(require_admin),
) -> None:
    assignment = db.scalar(
        select(TeacherClassAssignment).where(
            TeacherClassAssignment.class_id == class_id,
            TeacherClassAssignment.teacher_id == teacher_id,
        )
    )
    if assignment is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Guru tidak terdaftar di kelas ini.",
        )
    db.delete(assignment)
    db.commit()
