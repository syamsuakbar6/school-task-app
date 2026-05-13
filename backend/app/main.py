from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.error_handlers import register_error_handlers
from app.db.database import check_database_connection, get_db
from app.routers import auth, class_router, submission, task

# TAMBAHKAN INI — pastikan semua model ter-register ke SQLAlchemy
# sebelum query pertama dijalankan
import app.models.user          # noqa: F401
import app.models.task          # noqa: F401
import app.models.submission    # noqa: F401
import app.models.grade         # noqa: F401
import app.models.class_model   # noqa: F401
import app.models.audit_log     # noqa: F401
import app.models.submission_state  # noqa: F401


@asynccontextmanager
async def lifespan(_: FastAPI):
    settings.storage_path.mkdir(parents=True, exist_ok=True)
    yield


app = FastAPI(
    title=settings.APP_NAME,
    description="FastAPI backend connected to the existing PostgreSQL LMS schema.",
    version="1.0.0",
    debug=settings.DEBUG,
    lifespan=lifespan,
)

register_error_handlers(app)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins or ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(class_router.router)
app.include_router(task.router)
app.include_router(submission.router)


@app.get("/", tags=["Root"])
def read_root() -> dict[str, str]:
    return {"message": f"{settings.APP_NAME} is running"}


@app.get("/health", tags=["Health"])
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/health/db", tags=["Health"])
def database_health_check(db: Session = Depends(get_db)) -> dict[str, int | str]:
    return check_database_connection(db)