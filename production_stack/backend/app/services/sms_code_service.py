from datetime import datetime, timedelta, timezone
from typing import Optional

import redis
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.errors import bad_request, too_many_requests
from app.core.security import generate_sms_code, hash_sms_code, verify_sms_code
from app.repositories.sms_log_repo import SmsCodeLogRepository
from app.services.sms_service import SmsService
from app.utils.validators import validate_phone


class SmsCodeService:
    def __init__(self, *, db: Session, rds: redis.Redis, sms: SmsService):
        self.db = db
        self.rds = rds
        self.sms = sms

    def _cooldown_key(self, *, scene: str, phone: str) -> str:
        return f"sms:cooldown:{scene}:{phone}"

    def _code_key(self, *, scene: str, phone: str) -> str:
        return f"sms:code:{scene}:{phone}"

    def _log_id_key(self, *, scene: str, phone: str) -> str:
        return f"sms:log_id:{scene}:{phone}"

    def _hour_key(self, *, phone: str, hour: str) -> str:
        return f"sms:count:hour:{phone}:{hour}"

    def _day_key(self, *, phone: str, day: str) -> str:
        return f"sms:count:day:{phone}:{day}"

    def _verify_attempts_key(self, *, scene: str, phone: str) -> str:
        return f"sms:verify:attempts:{scene}:{phone}"

    def risk_check(self, *, phone: str, scene: str, ip: Optional[str], device_id: Optional[str]) -> None:
        return

    def send_code(self, *, phone: str, scene: str, ip: Optional[str], device_id: Optional[str]) -> Optional[str]:
        validate_phone(phone)

        if scene not in {"register", "login", "reset_password", "bind"}:
            raise bad_request("scene 参数不合法")

        self.risk_check(phone=phone, scene=scene, ip=ip, device_id=device_id)

        cooldown_key = self._cooldown_key(scene=scene, phone=phone)
        if self.rds.exists(cooldown_key):
            raise too_many_requests("验证码已发送，请稍后再试")

        now = datetime.now(timezone.utc)
        hour = now.strftime("%Y%m%d%H")
        day = now.strftime("%Y%m%d")

        hour_key = self._hour_key(phone=phone, hour=hour)
        hour_count = self.rds.incr(hour_key, 1)
        if hour_count == 1:
            self.rds.expire(hour_key, 3600)
        if hour_count > settings.sms_hourly_limit:
            raise too_many_requests("验证码发送过于频繁，请稍后再试")

        day_key = self._day_key(phone=phone, day=day)
        day_count = self.rds.incr(day_key, 1)
        if day_count == 1:
            self.rds.expire(day_key, 86400)
        if day_count > settings.sms_daily_limit:
            raise too_many_requests("今日验证码发送次数已达上限")

        code = generate_sms_code()
        code_hash = hash_sms_code(code)
        expired_at = now + timedelta(seconds=settings.sms_code_ttl_seconds)

        log_repo = SmsCodeLogRepository(self.db)
        log = log_repo.create(
            phone=phone,
            scene=scene,
            code_hash=code_hash,
            expired_at=expired_at,
            ip=ip,
            device_id=device_id,
        )

        code_key = self._code_key(scene=scene, phone=phone)
        log_id_key = self._log_id_key(scene=scene, phone=phone)
        self.rds.setex(code_key, settings.sms_code_ttl_seconds, code_hash)
        self.rds.setex(log_id_key, settings.sms_code_ttl_seconds, str(log.id))
        self.rds.setex(cooldown_key, settings.sms_cooldown_seconds, "1")

        try:
            self.sms.send_code(phone=phone, code=code, scene=scene)
        except Exception:
            self.rds.delete(code_key)
            self.rds.delete(log_id_key)
            self.rds.delete(cooldown_key)
            self.rds.decr(hour_key)
            self.rds.decr(day_key)
            log_repo.delete_by_id(log.id)
            raise

        if settings.debug or settings.app_env == "dev":
            return code
        return None

    def verify_code(self, *, phone: str, scene: str, code: str) -> None:
        validate_phone(phone)

        if scene not in {"register", "login", "reset_password", "bind"}:
            raise bad_request("scene 参数不合法")

        code_key = self._code_key(scene=scene, phone=phone)
        code_hash = self.rds.get(code_key)
        attempts_key = self._verify_attempts_key(scene=scene, phone=phone)
        attempts = self.rds.incr(attempts_key, 1)
        if attempts == 1:
            self.rds.expire(attempts_key, settings.sms_code_ttl_seconds)
        if attempts > 10:
            raise too_many_requests("验证失败次数过多，请稍后再试")

        if not code_hash or not verify_sms_code(code, code_hash):
            raise bad_request("手机号或验证码错误")

        self.rds.delete(code_key)
        self.rds.delete(attempts_key)

        log_id_key = self._log_id_key(scene=scene, phone=phone)
        log_id = self.rds.get(log_id_key)
        self.rds.delete(log_id_key)
        if log_id and log_id.isdigit():
            SmsCodeLogRepository(self.db).mark_used(int(log_id))
