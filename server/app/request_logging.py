from __future__ import annotations

import logging
import time
import uuid

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

logger = logging.getLogger("sifa.request")


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = (
            request.headers.get("X-Request-ID")
            or str(uuid.uuid4())
        )
        request.state.request_id = request_id

        started = time.perf_counter()
        status_code = 500

        try:
            response = await call_next(request)
            status_code = response.status_code
        except Exception:
            logger.exception(
                "unhandled_request_error",
                extra={
                    "request_id": request_id,
                    "method": request.method,
                    "path": request.url.path,
                    "status_code": 500,
                    "duration_ms": round(
                        (time.perf_counter() - started) * 1000,
                        2,
                    ),
                    "client_ip": (
                        request.client.host
                        if request.client
                        else None
                    ),
                },
            )

            response = JSONResponse(
                status_code=500,
                content={
                    "detail": {
                        "code": "internal_error",
                        "message": (
                            "Beklenmeyen sunucu hatası oluştu. "
                            "İşlem numarası ile yönetici logları kontrol edilebilir."
                        ),
                        "request_id": request_id,
                    }
                },
            )
            status_code = 500

        duration_ms = round(
            (time.perf_counter() - started) * 1000,
            2,
        )

        logger.info(
            "request_completed",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "status_code": status_code,
                "duration_ms": duration_ms,
                "client_ip": (
                    request.client.host
                    if request.client
                    else None
                ),
            },
        )

        response.headers["X-Request-ID"] = request_id

        # Authorization, JWT, passwords, request bodies and document
        # contents are deliberately never logged.
        return response
