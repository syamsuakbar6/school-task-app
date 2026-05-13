from functools import lru_cache
from pathlib import Path

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


BASE_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=BASE_DIR / ".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    APP_NAME: str = "School Task Management API"
    API_V1_PREFIX: str = "/api/v1"
    DEBUG: bool = False

    DATABASE_URL: str = (
        "postgresql+psycopg2://postgres:postgres@localhost:5432/school_task_db"
    )

    SECRET_KEY: str = (
        "change-this-secret-key-to-a-long-random-string-with-32-plus-characters"
    )
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    CORS_ORIGINS: str = "http://localhost:3000,http://127.0.0.1:3000"

    # Local storage (fallback kalau Supabase tidak dikonfigurasi)
    STORAGE_DIR: str = "uploads/submissions"
    MAX_UPLOAD_SIZE_MB: int = 5
    ALLOWED_UPLOAD_EXTENSIONS: str = ".pdf,.docx,.png,.jpg,.jpeg,.txt,.zip"

    # Supabase Storage
    SUPABASE_URL: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""
    SUPABASE_BUCKET: str = "submissions"

    @field_validator("SECRET_KEY")
    @classmethod
    def validate_secret_key(cls, value: str) -> str:
        if len(value) < 32:
            raise ValueError("SECRET_KEY must be at least 32 characters long.")
        return value

    @property
    def cors_origins(self) -> list[str]:
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]

    @property
    def storage_root(self) -> Path:
        return self.storage_path.parent

    @property
    def storage_path(self) -> Path:
        return BASE_DIR / self.STORAGE_DIR

    @property
    def allowed_upload_extensions(self) -> set[str]:
        return {
            extension.strip().lower()
            for extension in self.ALLOWED_UPLOAD_EXTENSIONS.split(",")
            if extension.strip()
        }

    @property
    def supabase_enabled(self) -> bool:
        """True kalau Supabase sudah dikonfigurasi."""
        return bool(self.SUPABASE_URL and self.SUPABASE_SERVICE_ROLE_KEY)


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
