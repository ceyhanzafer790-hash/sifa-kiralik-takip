from __future__ import annotations

import argparse
import hashlib
import os
import re
import sys
from pathlib import Path

import psycopg
from psycopg.rows import dict_row

DATABASE_URL = os.environ["DATABASE_URL"]
MIGRATIONS_DIR = Path(
    os.environ.get(
        "MIGRATIONS_DIR",
        str(Path(__file__).resolve().parent.parent / "migrations"),
    )
)
BOOTSTRAP_LEGACY = MIGRATIONS_DIR / "_bootstrap_legacy.sql"

MIGRATION_RE = re.compile(r"^(?P<version>\d{4})_(?P<name>[a-z0-9_]+)\.sql$")


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _files() -> list[tuple[str, str, Path, str]]:
    result = []
    if not MIGRATIONS_DIR.exists():
        raise RuntimeError(
            f"Migration klasörü bulunamadı: {MIGRATIONS_DIR}"
        )

    for path in sorted(MIGRATIONS_DIR.glob("*.sql")):
        match = MIGRATION_RE.match(path.name)
        if not match:
            raise RuntimeError(
                f"Geçersiz migration dosya adı: {path.name}"
            )
        result.append(
            (
                match.group("version"),
                match.group("name"),
                path,
                _sha256(path),
            )
        )

    versions = [x[0] for x in result]
    if len(versions) != len(set(versions)):
        raise RuntimeError("Aynı migration sürümü birden fazla kez kullanılmış.")

    return result


def _ensure_table(cur) -> None:
    cur.execute(
        """
        create table if not exists schema_migrations (
          version text primary key,
          name text not null,
          sha256 text not null,
          applied_at timestamptz not null default now()
        )
        """
    )




def _table_exists(cur, table_name: str) -> bool:
    cur.execute(
        """
        select exists (
          select 1
          from information_schema.tables
          where table_schema = 'public'
            and table_name = %s
        ) as exists
        """,
        (table_name,),
    )
    return bool(cur.fetchone()["exists"])


def _legacy_bootstrap_needed(cur) -> bool:
    if not _table_exists(cur, "customers"):
        return False

    cur.execute("select count(*) as count from schema_migrations")
    applied = int(cur.fetchone()["count"])
    return applied == 0


def _run_legacy_bootstrap(conn) -> None:
    if not BOOTSTRAP_LEGACY.exists():
        raise RuntimeError(
            f"Legacy bootstrap dosyası bulunamadı: {BOOTSTRAP_LEGACY}"
        )

    with conn.cursor(row_factory=dict_row) as cur:
        if not _legacy_bootstrap_needed(cur):
            return

    sql = BOOTSTRAP_LEGACY.read_text(encoding="utf-8")
    print("Eski veritabanı tespit edildi. Legacy bootstrap uygulanıyor.")

    with conn.transaction():
        with conn.cursor() as cur:
            cur.execute(sql, prepare=False)


def migration_status(conn) -> dict:
    files = _files()

    with conn.cursor(row_factory=dict_row) as cur:
        _ensure_table(cur)
        cur.execute(
            """
            select version, name, sha256, applied_at
            from schema_migrations
            order by version
            """
        )
        applied_rows = cur.fetchall()

    applied = {row["version"]: row for row in applied_rows}
    pending = []
    checksum_errors = []

    for version, name, path, checksum in files:
        row = applied.get(version)
        if not row:
            pending.append({
                "version": version,
                "name": name,
                "file": path.name,
            })
            continue

        if row["sha256"] != checksum:
            checksum_errors.append({
                "version": version,
                "file": path.name,
                "expected": row["sha256"],
                "actual": checksum,
            })

    return {
        "latest_available": files[-1][0] if files else None,
        "latest_applied": applied_rows[-1]["version"] if applied_rows else None,
        "applied_count": len(applied_rows),
        "pending": pending,
        "checksum_errors": checksum_errors,
    }


def apply_migrations() -> dict:
    files = _files()

    with psycopg.connect(DATABASE_URL, row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "select pg_advisory_lock(hashtext('sifa_kiralik_schema_migrations'))"
            )
            _ensure_table(cur)
            conn.commit()

        try:
            _run_legacy_bootstrap(conn)
            status = migration_status(conn)
            if status["checksum_errors"]:
                raise RuntimeError(
                    "Daha önce uygulanmış migration dosyası değiştirilmiş. "
                    "Güvenlik nedeniyle işlem durduruldu."
                )

            for version, name, path, checksum in files:
                with conn.cursor(row_factory=dict_row) as cur:
                    cur.execute(
                        "select sha256 from schema_migrations where version = %s",
                        (version,),
                    )
                    existing = cur.fetchone()

                if existing:
                    continue

                sql = path.read_text(encoding="utf-8")
                print(f"Migration uygulanıyor: {version}_{name}")

                with conn.transaction():
                    with conn.cursor() as cur:
                        cur.execute(sql, prepare=False)
                        cur.execute(
                            """
                            insert into schema_migrations(version, name, sha256)
                            values (%s, %s, %s)
                            """,
                            (version, name, checksum),
                        )

            return migration_status(conn)
        finally:
            with conn.cursor() as cur:
                cur.execute(
                    "select pg_advisory_unlock(hashtext('sifa_kiralik_schema_migrations'))"
                )
            conn.commit()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="Migration uygulamadan durumunu kontrol et.",
    )
    args = parser.parse_args()

    with psycopg.connect(DATABASE_URL, row_factory=dict_row) as conn:
        if args.check:
            status = migration_status(conn)
            print(status)
            if status["checksum_errors"] or status["pending"]:
                return 1
            return 0

    status = apply_migrations()
    print(
        "Migration tamamlandı. "
        f"Son sürüm: {status['latest_applied']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
