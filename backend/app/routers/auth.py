from fastapi import APIRouter, Depends, status

from app.core.dependencies import DBSession, get_current_user
from app.schemas.auth_schema import TokenResponse
from app.schemas.user_schema import UserCreate, UserLogin, UserResponse
from app.services.auth_service import AuthService


router = APIRouter(tags=["Authentication"])


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
)
def register(user_in: UserCreate, db: DBSession) -> UserResponse:
    user = AuthService.register_user(db, user_in)
    return UserResponse.model_validate(user)


@router.post("/login", response_model=TokenResponse)
def login(credentials: UserLogin, db: DBSession) -> TokenResponse:
    user = AuthService.authenticate_user(
        db,
        email=credentials.email,
        password=credentials.password,
    )
    return TokenResponse(**AuthService.build_login_response(user))


@router.get("/me", response_model=UserResponse)
def read_current_user(current_user=Depends(get_current_user)) -> UserResponse:
    return UserResponse.model_validate(current_user)
