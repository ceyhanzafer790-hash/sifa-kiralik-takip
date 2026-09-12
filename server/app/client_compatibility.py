from __future__ import annotations

import time

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from .runtime_settings import (
    get_runtime_settings,
    is_version_below,
)

CACHE_SECONDS = 10
_cache_value: dict | None = None
_cache_at = 0.0

EXEMPT_PATHS = {
    "/health",
    "/app/status",
    "/auth/login",
}


def _settings() -> dict:
    global _cache_at, _cache_value

    now = time.monotonic()
    if _cache_value is None or now - _cache_at > CACHE_SECONDS:
        _cache_value = get_runtime_settings()
        _cache_at = now

    return _cache_value


def invalidate_runtime_cache() -> None:
    global _cache_at, _cache_value
    _cache_value = None
    _cache_at = 0.0


class ClientCompatibilityMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        path = request.url.path
        signed_document_download = (
            request.method == "GET"
            and path.startswith("/documents/")
            and path.endswith("/signed-download")
        )
        if path in EXEMPT_PATHS or signed_document_download:
            return await call_next(request)

        settings = _settings()

        if not settings.get("enforce_min_client_version"):
            return await call_next(request)

        client_version = request.headers.get("X-App-Version")
        minimum = settings.get("min_client_version")

        if not client_version or is_version_below(
            client_version,
            minimum,
        ):
            return JSONResponse(
                status_code=426,
                content={
                    "detail": {
                        "code": "client_update_required",
                        "message": (
                            "Bu uygulama sürümü artık sunucuyla işlem yapamaz. "
                            "Güncelleme gereklidir."
                        ),
                        "current_version": client_version,
                        "minimum_version": minimum,
                        "latest_version": settings.get(
                            "latest_client_version"
                        ),
                    }
                },
                headers={
                    "X-Min-Client-Version": str(minimum or ""),
                },
            )

        return await call_next(request)
