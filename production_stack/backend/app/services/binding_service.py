from typing import List

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import conflict, forbidden, not_found
from app.models.caregiver_binding import BindingStatus, CaregiverBinding
from app.models.user import User, UserRole
from app.repositories.user_repo import UserRepository
from app.schemas.care import BoundElderOut


class BindingService:
    def __init__(self, db: Session):
        self.db = db

    def _mask_phone(self, phone: str) -> str:
        if len(phone) <= 4:
            return "****"
        return phone[:3] + "****" + phone[-4:]

    def bind_by_short_id_and_phone_tail(
        self,
        *,
        caregiver: User,
        elder_short_id: str,
        phone_last4: str,
    ) -> CaregiverBinding:
        if caregiver.role != UserRole.PERSONAL:
            raise forbidden("仅个人端可发起绑定")

        elder = UserRepository(self.db).get_by_short_id(elder_short_id)
        if not elder or elder.role != UserRole.ELDERLY:
            raise not_found("未找到匹配的长辈端账号，请核对绑定短号与手机后四位")

        if not elder.phone.endswith(phone_last4):
            raise not_found("未找到匹配的长辈端账号，请核对绑定短号与手机后四位")

        if elder.id == caregiver.id:
            raise forbidden("不能绑定自己")

        row = self.db.execute(
            select(CaregiverBinding).where(
                CaregiverBinding.caregiver_id == caregiver.id,
                CaregiverBinding.elder_id == elder.id,
            )
        ).scalar_one_or_none()

        if row:
            if row.status == BindingStatus.ACTIVE:
                raise conflict("已与该长辈建立绑定关系")
            row.status = BindingStatus.ACTIVE
            row.can_manage_medicine = True
            row.can_view_records = True
            row.can_receive_alerts = True
            self.db.add(row)
            self.db.commit()
            self.db.refresh(row)
            return row

        binding = CaregiverBinding(
            caregiver_id=caregiver.id,
            elder_id=elder.id,
            status=BindingStatus.ACTIVE,
        )
        self.db.add(binding)
        self.db.commit()
        self.db.refresh(binding)
        return binding

    def to_bound_elder_out(self, binding: CaregiverBinding) -> BoundElderOut:
        repo = UserRepository(self.db)
        elder = repo.get_by_id(binding.elder_id)
        if not elder:
            raise not_found("绑定数据异常")
        elder = repo.ensure_short_id(elder)
        return BoundElderOut(
            elder_id=elder.id,
            short_id=elder.short_id or "",
            phone_masked=self._mask_phone(elder.phone),
            can_manage_medicine=binding.can_manage_medicine,
            can_view_records=binding.can_view_records,
            can_receive_alerts=binding.can_receive_alerts,
        )

    def list_bound_elders(self, *, caregiver: User) -> List[BoundElderOut]:
        if caregiver.role != UserRole.PERSONAL:
            raise forbidden("仅个人端可查看绑定列表")

        rows = self.db.execute(
            select(CaregiverBinding).where(
                CaregiverBinding.caregiver_id == caregiver.id,
                CaregiverBinding.status == BindingStatus.ACTIVE,
            )
        ).scalars().all()

        return [self.to_bound_elder_out(b) for b in rows]
