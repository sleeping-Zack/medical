from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class BindingStatus:
    ACTIVE = "active"
    REVOKED = "revoked"


class CaregiverBinding(Base):
    __tablename__ = "caregiver_bindings"
    __table_args__ = (UniqueConstraint("caregiver_id", "elder_id", name="uq_caregiver_elder"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    caregiver_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    elder_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    status: Mapped[str] = mapped_column(
        Enum(BindingStatus.ACTIVE, BindingStatus.REVOKED, name="binding_status"),
        nullable=False,
        default=BindingStatus.ACTIVE,
        server_default=BindingStatus.ACTIVE,
    )
    can_manage_medicine: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="1")
    can_view_records: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="1")
    can_receive_alerts: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="1")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
