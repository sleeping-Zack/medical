from datetime import date, datetime
from typing import Any, Dict, List, Optional

from sqlalchemy import JSON, Date, DateTime, Enum, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class PlanStatus:
    ACTIVE = "active"
    PAUSED = "paused"


class MedicinePlan(Base):
    __tablename__ = "medicine_plans"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    target_user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    created_by_user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    medicine_id: Mapped[int] = mapped_column(ForeignKey("medicines.id", ondelete="CASCADE"), nullable=False, index=True)
    status: Mapped[str] = mapped_column(
        Enum(PlanStatus.ACTIVE, PlanStatus.PAUSED, name="plan_status"),
        nullable=False,
        default=PlanStatus.ACTIVE,
        server_default=PlanStatus.ACTIVE,
    )
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    # 例：[{"hour":8,"minute":0,"weekdays":"1111111"}] 从左到右周一到周日，1 表示该日需服
    schedules_json: Mapped[List[Dict[str, Any]]] = mapped_column(JSON, nullable=False)
    label: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
