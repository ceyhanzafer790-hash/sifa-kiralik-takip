import getpass
import os
import sys

import psycopg
from passlib.context import CryptContext

DATABASE_URL = os.environ.get("DATABASE_URL")
if not DATABASE_URL:
    print("DATABASE_URL ortam değişkeni gerekli.")
    sys.exit(1)

pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")

email = input("Yönetici e-posta: ").strip().lower()
full_name = input("Ad Soyad: ").strip()
password = getpass.getpass("Şifre (en az 8 karakter): ")

if len(password) < 8:
    print("Şifre en az 8 karakter olmalı.")
    sys.exit(1)

with psycopg.connect(DATABASE_URL) as conn:
    with conn.cursor() as cur:
        cur.execute(
            '''
            insert into app_users(email, password_hash, full_name, role, active)
            values (%s, %s, %s, 'admin', true)
            returning id
            ''',
            (email, pwd.hash(password), full_name),
        )
        user_id = cur.fetchone()[0]
        conn.commit()

print(f"İlk yönetici oluşturuldu: {user_id}")
