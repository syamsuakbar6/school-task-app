from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field, model_validator

from app.models.user import UserRole


class UserBase(BaseModel):
    name: str = Field(min_length=3, max_length=100)
    role: UserRole = UserRole.STUDENT


class UserCreate(UserBase):
    nisn: str | None = Field(default=None, min_length=10, max_length=10, pattern=r'^\d{10}$')
    nip: str | None = Field(default=None, min_length=18, max_length=18, pattern=r'^\d{18}$')
    email: EmailStr | None = None
    password: str = Field(min_length=8, max_length=128)

    @model_validator(mode='after')
    def validate_identifier(self) -> 'UserCreate':
        role = str(self.role).lower()
        if role == UserRole.STUDENT.value and not self.nisn:
            raise ValueError('NISN wajib diisi untuk siswa (10 digit angka).')
        if role == UserRole.TEACHER.value and not self.nip:
            raise ValueError('NIP wajib diisi untuk guru (18 digit angka).')
        return self


class UserLogin(BaseModel):
    identifier: str = Field(
        description="NISN (10 digit) untuk siswa, NIP (18 digit) untuk guru"
    )
    password: str = Field(min_length=8, max_length=128)


class UserSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    role: UserRole
    nisn: str | None = None
    nip: str | None = None


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    email: str | None = None
    nisn: str | None = None
    nip: str | None = None
    role: UserRole
    created_at: datetime
