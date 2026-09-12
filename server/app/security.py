import os
from datetime import datetime, timedelta, timezone

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext

from .db import db
from .runtime_settings import get_runtime_settings

JWT_SECRET = os.environ["JWT_SECRET"]
ALGORITHM = "HS256"
TOKEN_HOURS = 24 * 7
DOCUMENT_DOWNLOAD_MINUTES = 5

pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")
bearer = HTTPBearer(auto_error=False)

def hash_password(password: str) -> str:
    return pwd.hash(password)

def verify_password(password: str, password_hash: str) -> bool:
    return pwd.verify(password, password_hash)

def create_token(user_id: str) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {
            "sub": user_id,
            "iat": int(now.timestamp()),
            "exp": int((now + timedelta(hours=TOKEN_HOURS)).timestamp()),
        },
        JWT_SECRET,
        algorithm=ALGORITHM,
    )


def create_document_download_token(document_id: str, user_id: str) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {
            "sub": user_id,
            "purpose": "document_download",
            "document_id": str(document_id),
            "iat": int(now.timestamp()),
            "exp": int(
                (now + timedelta(minutes=DOCUMENT_DOWNLOAD_MINUTES))
                .timestamp()
            ),
        },
        JWT_SECRET,
        algorithm=ALGORITHM,
    )


def verify_document_download_token(token: str, document_id: str) -> str:
    try:
        payload = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=[ALGORITHM],
        )
        if payload.get("purpose") != "document_download":
            raise JWTError("invalid token purpose")
        if str(payload.get("document_id")) != str(document_id):
            raise JWTError("document mismatch")
        return str(payload["sub"])
    except (JWTError, KeyError):
        raise HTTPException(
            status_code=401,
            detail="İndirme bağlantısı geçersiz veya süresi dolmuş.",
        )

def current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
):
    if credentials is None:
        raise HTTPException(status_code=401, detail="Oturum gerekli.")

    try:
        payload = jwt.decode(
            credentials.credentials,
            JWT_SECRET,
            algorithms=[ALGORITHM],
        )
        user_id = payload["sub"]
    except (JWTError, KeyError):
        raise HTTPException(status_code=401, detail="Geçersiz oturum.")

    with db() as (_, cur):
        cur.execute(
            """
            select id, email, full_name, role, active
            from app_users
            where id = %s
            """,
            (user_id,),
        )
        user = cur.fetchone()

    if not user or not user["active"]:
        raise HTTPException(status_code=401, detail="Kullanıcı aktif değil.")
    return user

def require_write(user=Depends(current_user)):
    if user["role"] not in ("admin", "staff"):
        raise HTTPException(status_code=403, detail="Yazma yetkiniz yok.")

    if user["role"] != "admin":
        settings = get_runtime_settings()
        if settings.get("maintenance_mode"):
            raise HTTPException(
                status_code=503,
                detail={
                    "code": "maintenance_mode",
                    "message": (
                        settings.get("maintenance_message")
                        or "Sistem bakım modunda. Yazma işlemleri geçici olarak kapalı."
                    ),
                },
            )

    return user


def require_admin(user=Depends(current_user)):
    if user["role"] != "admin":
        raise HTTPException(
            status_code=403,
            detail="Bu işlem yalnızca yönetici hesabına açık.",
        )
    return user
