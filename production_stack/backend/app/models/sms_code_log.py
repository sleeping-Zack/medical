from datetime import datetime
from typing import Optional

from sqlalchemy import Boolean, DateTime, Enum, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class SmsScene:
    REGISTER = "register"
    LOGIN = "login"
    RESET_PASSWORD = "reset_password"
    BIND = "bind"


class SmsCodeLog(Base):
    __tablename__ = "sms_code_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    phone: Mapped[str] = mapped_column(String(20), index=True, nullable=False)
    scene: Mapped[str] = mapped_column(
        Enum(
            SmsScene.REGISTER,
            SmsScene.LOGIN,
            SmsScene.RESET_PASSWORD,
            SmsScene.BIND,
            name="sms_scene",
        ),
        index=True,
        nullable=False,
    )
    code_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    expired_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    used: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default="0")
    ip: Mapped[Optional[str]] = mapped_column(String(45), nullable=True)
    device_id: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())

