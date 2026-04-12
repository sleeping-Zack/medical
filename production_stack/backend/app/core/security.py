import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import bcrypt
from jose import JWTError, jwt

from app.core.config import settings
from app.core.errors import unauthorized


def _sha256_hex_bytes(plain: str) -> bytes:
    """64 字节 ASCII，作为 bcrypt 输入，无 72 字节明文限制。"""
    return hashlib.sha256(plain.encode("utf-8")).hexdigest().encode("ascii")


def hash_password(password: str) -> str:
    digest = _sha256_hex_bytes(password)
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(digest, salt).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    h = password_hash.encode("utf-8")
    try:
        if bcrypt.checkpw(_sha256_hex_bytes(password), h):
            return True
    except ValueError:
        pass
    # 兼容此前 passlib 生成的「明文 bcrypt」哈希（短密码）
    try:
        return bcrypt.checkpw(password.encode("utf-8"), h)
    except ValueError:
        return False


def _now() -> datetime:
    return datetime.now(timezone.utc)


def create_access_token(*, user_id: int, phone: str, role: str) -> tuple[str, int]:
    expires_minutes = settings.access_token_expire_minutes
    exp = _now() + timedelta(minutes=expires_minutes)
    jti = str(uuid4())
    payload = {
        "sub": str(user_id),
        "phone": phone,
        "role": role,
        "token_type": "access",
        "jti": jti,
        "iat": int(_now().timestamp()),
        "exp": int(exp.timestamp()),
    }
    token = jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    return token, expires_minutes * 60


def create_refresh_token(*, user_id: int, phone: str, role: str) -> tuple[str, int, str]:
    expires_days = settings.refresh_token_expire_days
    exp = _now() + timedelta(days=expires_days)
    jti = str(uuid4())
    payload = {
        "sub": str(user_id),
        "phone": phone,
        "role": role,
        "token_type": "refresh",
        "jti": jti,
        "iat": int(_now().timestamp()),
        "exp": int(exp.timestamp()),
    }
    token = jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    return token, int(timedelta(days=expires_days).total_seconds()), jti


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
    except JWTError:
        raise unauthorized()


def hash_sms_code(code: str) -> str:
    data = f"{code}:{settings.sms_code_salt}".encode("utf-8")
    return hashlib.sha256(data).hexdigest()


def verify_sms_code(code: str, code_hash: str) -> bool:
    candidate = hash_sms_code(code)
    return hmac.compare_digest(candidate, code_hash)


def generate_sms_code() -> str:
    return "".join(str(secrets.randbelow(10)) for _ in range(6))
