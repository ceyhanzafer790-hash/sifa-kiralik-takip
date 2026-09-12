from __future__ import annotations

import json
import logging
import os
import sys
from datetime import datetime, timezone
from logging.handlers import RotatingFileHandler
from pathlib import Path


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": datetime.now(
                timezone.utc
            ).astimezone().isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        for key in (
            "request_id",
            "method",
            "path",
            "status_code",
            "duration_ms",
            "client_ip",
        ):
            if hasattr(record, key):
                payload[key] = getattr(record, key)

        if record.exc_info:
            payload["exception"] = self.formatException(
                record.exc_info
            )

        return json.dumps(
            payload,
            ensure_ascii=False,
            default=str,
        )


def configure_logging() -> None:
    root = logging.getLogger()
    if getattr(root, "_sifa_configured", False):
        return

    log_level = os.environ.get("LOG_LEVEL", "INFO").upper()
    formatter = JsonFormatter()

    console = logging.StreamHandler(sys.stdout)
    console.setFormatter(formatter)
    console.setLevel(log_level)

    handlers: list[logging.Handler] = [console]

    log_root = Path(
        os.environ.get(
            "LOG_ROOT",
            "/data/logs",
        )
    )

    try:
        log_root.mkdir(parents=True, exist_ok=True)
        file_handler = RotatingFileHandler(
            log_root / "sifa-api.jsonl",
            maxBytes=10 * 1024 * 1024,
            backupCount=10,
            encoding="utf-8",
        )
        file_handler.setFormatter(formatter)
        file_handler.setLevel(log_level)
        handlers.append(file_handler)
    except Exception:
        pass

    root.handlers.clear()
    for handler in handlers:
        root.addHandler(handler)

    root.setLevel(log_level)
    root._sifa_configured = True  # type: ignore[attr-defined]
    logging.getLogger("uvicorn.access").disabled = True
