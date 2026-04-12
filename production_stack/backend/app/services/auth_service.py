import redis
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.errors import bad_request, conflict, unauthorized
from app.core.errors import too_many_requests
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.models.user import UserRole, UserStatus
from app.repositories.user_repo import UserRepository
from app.schemas.auth import TokenPair, UserMe
from app.utils.validators import validate_password, validate_phone


class AuthService:
    def __init__(self, *, db: Session, rds: redis.Redis):
        self.db = db
        self.rds = rds

    def _refresh_key(self, *, user_id: int) -> str:
        return f"auth:refresh:{user_id}"

    def issue_tokens(self, *, user_id: int, phone: str, role: str) -> TokenPair:
        access_token, expires_in = create_access_token(user_id=user_id, phone=phone, role=role)
        refresh_token, refresh_ttl, refresh_jti = create_refresh_token(user_id=user_id, phone=phone, role=role)
        self.rds.setex(self._refresh_key(user_id=user_id), refresh_ttl, refresh_jti)
        return TokenPair(access_token=access_token, refresh_token=refresh_token, expires_in=expires_in)

    def register(self, *, phone: str, password: str, role: str) -> tuple[TokenPair, UserMe]:
        validate_phone(phone)
        validate_password(password)
        if role not in {UserRole.PERSONAL, UserRole.ELDERLY}:
            raise bad_request("role 参数不合法")

        repo = UserRepository(self.db)
        if repo.get_by_phone(phone):
            raise conflict("该手机号已注册")

        user = repo.create(phone=phone, password_hash=hash_password(password), role=role)
        tokens = self.issue_tokens(user_id=user.id, phone=user.phone, role=user.role)
        return tokens, UserMe(id=user.id, phone=user.phone, role=user.role)

    def login_password(self, *, phone: str, password: str) -> tuple[TokenPair, UserMe]:
        validate_phone(phone)
        fail_key = f"auth:pwd_fail:{phone}"
        fail_count = int(self.rds.get(fail_key) or "0")
        if fail_count >= 10:
            raise too_many_requests("密码错误次数过多，请稍后再试")

        repo = UserRepository(self.db)
        user = repo.get_by_phone(phone)
        if not user or user.status != UserStatus.ACTIVE or not verify_password(password, user.password_hash):
            new_count = self.rds.incr(fail_key, 1)
            if new_count == 1:
                self.rds.expire(fail_key, 900)
            raise unauthorized("手机号或密码错误")

        self.rds.delete(fail_key)
        tokens = self.issue_tokens(user_id=user.id, phone=user.phone, role=user.role)
        return tokens, UserMe(id=user.id, phone=user.phone, role=user.role)

    def login_sms(self, *, phone: str) -> tuple[TokenPair, UserMe]:
        validate_phone(phone)
        repo = UserRepository(self.db)
        user = repo.get_by_phone(phone)
        if not user or user.status != UserStatus.ACTIVE:
            raise unauthorized("手机号或验证码错误")

        tokens = self.issue_tokens(user_id=user.id, phone=user.phone, role=user.role)
        return tokens, UserMe(id=user.id, phone=user.phone, role=user.role)

    def reset_password(self, *, phone: str, new_password: str) -> None:
        validate_phone(phone)
        validate_password(new_password)

        repo = UserRepository(self.db)
        user = repo.get_by_phone(phone)
        if not user or user.status != UserStatus.ACTIVE:
            raise unauthorized("手机号或验证码错误")

        repo.update_password(user=user, password_hash=hash_password(new_password))

        self.rds.delete(self._refresh_key(user_id=user.id))

    def refresh(self, *, refresh_token: str) -> TokenPair:
        payload = decode_token(refresh_token)
        if payload.get("token_type") != "refresh":
            raise unauthorized()

        user_id_str = payload.get("sub")
        if not user_id_str or not str(user_id_str).isdigit():
            raise unauthorized()
        user_id = int(user_id_str)

        current_jti = self.rds.get(self._refresh_key(user_id=user_id))
        if not current_jti or current_jti != payload.get("jti"):
            raise unauthorized()

        repo = UserRepository(self.db)
        user = repo.get_by_id(user_id)
        if not user or user.status != UserStatus.ACTIVE:
            raise unauthorized()

        return self.issue_tokens(user_id=user.id, phone=user.phone, role=user.role)

    def logout(self, *, user_id: int) -> None:
        self.rds.delete(self._refresh_key(user_id=user_id))
