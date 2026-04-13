from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from app.models.sms_code_log import SmsCodeLog


class SmsCodeLogRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(
        self,
        *,
        phone: str,
        scene: str,
        code_hash: str,
        expired_at: datetime,
        ip: Optional[str],
        device_id: Optional[str],
    ) -> SmsCodeLog:
        log = SmsCodeLog(
            phone=phone,
            scene=scene,
            code_hash=code_hash,
            expired_at=expired_at,
            used=False,
            ip=ip,
            device_id=device_id,
        )
        self.db.add(log)
        self.db.commit()
        self.db.refresh(log)
        return log

    def mark_used(self, log_id: int) -> None:
        log = self.db.get(SmsCodeLog, log_id)
        if not log:
            return
        log.used = True
        self.db.add(log)
        self.db.commit()

    def delete_by_id(self, log_id: int) -> None:
        log = self.db.get(SmsCodeLog, log_id)
        if not log:
            return
        self.db.delete(log)
        self.db.commit()

    def latest_unused(self, *, phone: str, scene: str) -> Optional[SmsCodeLog]:
        now = datetime.now(timezone.utc)
        stmt = (
            select(SmsCodeLog)
            .where(
                SmsCodeLog.phone == phone,
                SmsCodeLog.scene == scene,
                SmsCodeLog.used == False,
                SmsCodeLog.expired_at > now,
            )
            .order_by(desc(SmsCodeLog.id))
            .limit(1)
        )
        return self.db.execute(stmt).scalar_one_or_none()

