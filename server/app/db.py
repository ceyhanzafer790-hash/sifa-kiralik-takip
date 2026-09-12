from __future__ import annotations

import logging
import os
import threading
import time
from contextlib import contextmanager
from datetime import datetime, timezone
from typing import Any

from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

DATABASE_URL = os.environ["DATABASE_URL"]

POOL_MIN_SIZE = max(
    1,
    int(os.environ.get("DB_POOL_MIN_SIZE", "2")),
)
POOL_MAX_SIZE = max(
    POOL_MIN_SIZE,
    int(os.environ.get("DB_POOL_MAX_SIZE", "10")),
)
POOL_TIMEOUT_SECONDS = max(
    1,
    int(os.environ.get("DB_POOL_TIMEOUT_SECONDS", "10")),
)
SLOW_QUERY_MS = max(
    1,
    int(os.environ.get("DB_SLOW_QUERY_MS", "500")),
)

logger = logging.getLogger("sifa.sql")

pool = ConnectionPool(
    conninfo=DATABASE_URL,
    min_size=POOL_MIN_SIZE,
    max_size=POOL_MAX_SIZE,
    timeout=POOL_TIMEOUT_SECONDS,
    open=False,
    kwargs={
        "row_factory": dict_row,
        "autocommit": False,
    },
)

_metrics_lock = threading.Lock()
_metrics = {
    "query_count": 0,
    "slow_query_count": 0,
    "max_query_ms": 0.0,
    "last_slow_query_at": None,
}


def _query_summary(query: Any) -> str:
    text = " ".join(str(query).split())
    if len(text) > 500:
        text = text[:497] + "..."
    return text


def _record_query(duration_ms: float, query: Any) -> None:
    slow = duration_ms >= SLOW_QUERY_MS

    with _metrics_lock:
        _metrics["query_count"] += 1
        _metrics["max_query_ms"] = max(
            float(_metrics["max_query_ms"]),
            duration_ms,
        )
        if slow:
            _metrics["slow_query_count"] += 1
            _metrics["last_slow_query_at"] = (
                datetime.now(timezone.utc)
                .astimezone()
                .isoformat()
            )

    if slow:
        logger.warning(
            "slow_query",
            extra={
                "duration_ms": round(duration_ms, 2),
            },
        )
        # SQL parameters are deliberately not logged. Query text is
        # a normalized template only and may still contain literal SQL.
        logger.warning(
            "slow_query_template=%s",
            _query_summary(query),
        )


class TimedCursor:
    def __init__(self, cursor):
        self._cursor = cursor

    def execute(self, query, params=None, *args, **kwargs):
        started = time.perf_counter()
        try:
            return self._cursor.execute(
                query,
                params,
                *args,
                **kwargs,
            )
        finally:
            _record_query(
                (time.perf_counter() - started) * 1000,
                query,
            )

    def executemany(self, query, params_seq, *args, **kwargs):
        started = time.perf_counter()
        try:
            return self._cursor.executemany(
                query,
                params_seq,
                *args,
                **kwargs,
            )
        finally:
            _record_query(
                (time.perf_counter() - started) * 1000,
                query,
            )

    def __getattr__(self, name):
        return getattr(self._cursor, name)


def db_query_stats() -> dict:
    with _metrics_lock:
        return {
            **_metrics,
            "slow_query_threshold_ms": SLOW_QUERY_MS,
        }


def open_pool() -> None:
    if pool.closed:
        pool.open(wait=True)


def close_pool() -> None:
    if not pool.closed:
        pool.close()


@contextmanager
def db():
    if pool.closed:
        open_pool()

    with pool.connection(
        timeout=POOL_TIMEOUT_SECONDS,
    ) as conn:
        with conn.cursor() as raw_cur:
            yield conn, TimedCursor(raw_cur)
