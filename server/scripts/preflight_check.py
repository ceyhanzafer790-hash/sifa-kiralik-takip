from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent


def ok(message: str) -> None:
    print(f"OK   {message}")


def warn(message: str) -> None:
    print(f"UYARI {message}")


def fail(message: str, failures: list[str]) -> None:
    print(f"HATA {message}")
    failures.append(message)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--offline",
        action="store_true",
        help="DB/Docker erişimi olmadan yalnız dosya ve yapı kontrollerini yap.",
    )
    args = parser.parse_args()

    failures: list[str] = []

    required = [
        ROOT / "docker-compose.yml",
        ROOT / ".env.example",
        ROOT / "server" / "Dockerfile",
        ROOT / "server" / "app" / "main.py",
        ROOT / "server" / "app" / "app_runtime.py",
        ROOT / "server" / "app" / "finance.py",
        ROOT / "server" / "migrations" / "0006_runtime_settings_compliance_exceptions.sql",
        ROOT / "server" / "scripts" / "safe_upgrade.sh",
        ROOT / "server" / "scripts" / "register_release_manifest.py",
        ROOT / "server" / "scripts" / "verify_release_manifest.py",
        ROOT / "server" / "scripts" / "build_release_manifest.py",
        ROOT / "server" / "migrations" / "0008_receivable_aging.sql",
        ROOT / "server" / "app" / "diagnostics.py",
        ROOT / "flutter_client" / "lib" / "screens" / "production_readiness_screen.dart",
        ROOT / "flutter_client" / "lib" / "screens" / "overdue_receivables_screen.dart",
        ROOT / "server" / "migrations" / "0009_payment_due_date.sql",
        ROOT / "server" / "app" / "readiness.py",
        ROOT / "server" / "migrations" / "0001_initial_snapshot.sql",
        ROOT / "server" / "scripts" / "backup_local.sh",
        ROOT / "server" / "scripts" / "backup_onedrive.sh",
        ROOT / "flutter_client" / "pubspec.yaml",
    ]

    for path in required:
        if path.exists():
            ok(f"Dosya mevcut: {path.relative_to(ROOT)}")
        else:
            fail(
                f"Eksik dosya: {path.relative_to(ROOT)}",
                failures,
            )

    api_validator = ROOT / "server" / "scripts" / "validate_api_contracts.py"
    api_result = subprocess.run(
        [sys.executable, str(api_validator)],
        capture_output=True,
        text=True,
    )
    if api_result.returncode == 0:
        ok("Flutter ↔ FastAPI endpoint sözleşmesi doğrulandı.")
    else:
        fail(
            "Flutter ↔ FastAPI endpoint sözleşmesi tutarsız.",
            failures,
        )
        print(api_result.stdout)
        print(api_result.stderr)

    validator = ROOT / "server" / "scripts" / "validate_migrations.py"
    result = subprocess.run(
        [sys.executable, str(validator)],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        ok("Migration dosyaları doğrulandı.")
    else:
        fail(
            "Migration dosya doğrulaması başarısız.",
            failures,
        )
        print(result.stdout)
        print(result.stderr)


    backup_local = (
        ROOT / "server" / "scripts" / "backup_local.sh"
    ).read_text(encoding="utf-8")
    if "v0_6_selfhosted_documents_data" in backup_local:
        fail(
            "backup_local.sh eski v0.6 Docker volume adına bağlı.",
            failures,
        )
    else:
        ok("Yerel yedek scripti sabit eski volume adına bağlı değil.")

    env_example = (ROOT / ".env.example").read_text(encoding="utf-8")
    for bad in ("CHANGE_ME", "change-me", "postgres:postgres"):
        if bad in env_example:
            warn(
                f".env.example içinde örnek/değiştirilecek değer var: {bad}. "
                "Üretimde gerçek sırlarla değiştirilmelidir."
            )

    if args.offline:
        try:
            import psycopg_pool  # noqa: F401
            ok("psycopg_pool Python paketi kurulu.")
        except Exception:
            warn(
                "psycopg_pool bu Python ortamında kurulu değil. "
                "Sunucuda requirements.txt kurulunca tekrar kontrol edilmelidir."
            )

        print()
        if failures:
            print(f"Preflight başarısız. Hata sayısı: {len(failures)}")
            return 1
        print("Offline preflight başarılı.")
        return 0

    docker = shutil.which("docker")
    if not docker:
        fail("Docker bulunamadı.", failures)
    else:
        ok(f"Docker bulundu: {docker}")

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        fail("DATABASE_URL tanımlı değil.", failures)
    else:
        try:
            import psycopg
            with psycopg.connect(
                database_url,
                connect_timeout=5,
            ) as conn:
                with conn.cursor() as cur:
                    cur.execute("select 1")
                    cur.fetchone()
            ok("PostgreSQL bağlantısı başarılı.")
        except Exception as exc:
            fail(
                f"PostgreSQL bağlantısı başarısız: {exc}",
                failures,
            )

    document_root = Path(
        os.environ.get("DOCUMENT_ROOT", "/data/documents")
    )
    try:
        document_root.mkdir(parents=True, exist_ok=True)
        test = document_root / ".sifa_write_test"
        test.write_text("ok", encoding="utf-8")
        test.unlink()
        ok(f"Belge klasörü yazılabilir: {document_root}")
    except Exception as exc:
        fail(
            f"Belge klasörü yazılamıyor: {exc}",
            failures,
        )

    backup_dir = Path(
        os.environ.get("LOCAL_BACKUP_DIR", "/srv/sifa-backup")
    )
    try:
        backup_dir.mkdir(parents=True, exist_ok=True)
        ok(f"Yedek klasörü erişilebilir: {backup_dir}")
    except Exception as exc:
        fail(
            f"Yedek klasörü erişilemiyor: {exc}",
            failures,
        )

    print()
    if failures:
        print(f"Preflight başarısız. Hata sayısı: {len(failures)}")
        return 1

    print("Üretim preflight başarılı.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
