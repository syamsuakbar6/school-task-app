from __future__ import annotations

from typing import Any

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette import status


def _coerce_message(detail: Any) -> str:
    if detail is None:
        return "An error occurred."
    if isinstance(detail, str):
        return detail
    if isinstance(detail, dict) and isinstance(detail.get("message"), str):
        return detail["message"]
    return str(detail)


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(HTTPException)
    async def http_exception_handler(_: Request, exc: HTTPException) -> JSONResponse:
        message = _coerce_message(exc.detail)
        payload: dict[str, Any] = {
            # Backward-compatible with default FastAPI shape
            "detail": exc.detail if exc.detail is not None else message,
            # New standardized fields
            "message": message,
            "status_code": exc.status_code,
        }
        return JSONResponse(status_code=exc.status_code, content=payload, headers=exc.headers)

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
        payload: dict[str, Any] = {
            "detail": exc.errors(),
            "message": "Validation error.",
            "status_code": status.HTTP_422_UNPROCESSABLE_ENTITY,
        }
        return JSONResponse(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, content=payload)

