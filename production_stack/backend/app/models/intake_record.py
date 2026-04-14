from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class IntakeAction:
    TAKEN = "taken"
    DELETED = "deleted"
    MISSED = "missed"


class IntakeRecord(Base):
    __tablename__ = "intake_records"
    __table_args__ = (
        UniqueConstraint(
            "target_user_id",
            "plan_id",
            "schedule_id",
            "due_time",
            name="uq_intake_event",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    target_user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    confirmed_by_user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    plan_id: Mapped[int] = mapped_column(ForeignKey("medicine_plans.id", ondelete="CASCADE"), nullable=False, index=True)
    schedule_id: Mapped[str] = mapped_column(String(64), nullable=False)
    due_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    action: Mapped[str] = mapped_column(String(16), nullable=False, default=IntakeAction.TAKEN, server_default=IntakeAction.TAKEN)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
