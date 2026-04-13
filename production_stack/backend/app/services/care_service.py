from datetime import date
from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import forbidden, not_found
from app.models.caregiver_binding import BindingStatus, CaregiverBinding
from app.models.medicine import Medicine
from app.models.medicine_plan import MedicinePlan, PlanStatus
from app.models.user import User, UserRole
from app.schemas.care import MedicineOut, PlanOut, ScheduleItem


class CareService:
    def __init__(self, db: Session):
        self.db = db

    def _assert_personal_can_manage_target(self, *, caregiver: User, target_user_id: int) -> None:
        if caregiver.role != UserRole.PERSONAL:
            raise forbidden("仅个人端可代管用药")
        if target_user_id == caregiver.id:
            return
        binding = self.db.execute(
            select(CaregiverBinding).where(
                CaregiverBinding.caregiver_id == caregiver.id,
                CaregiverBinding.elder_id == target_user_id,
                CaregiverBinding.status == BindingStatus.ACTIVE,
                CaregiverBinding.can_manage_medicine.is_(True),
            )
        ).scalar_one_or_none()
        if not binding:
            raise forbidden("无权限为该用户维护药品与计划，请先完成绑定并确认代管权限")

    def create_medicine(
        self,
        *,
        caregiver: User,
        target_user_id: int,
        name: str,
        specification: Optional[str],
        note: Optional[str],
    ) -> Medicine:
        self._assert_personal_can_manage_target(caregiver=caregiver, target_user_id=target_user_id)
        m = Medicine(
            target_user_id=target_user_id,
            created_by_user_id=caregiver.id,
            name=name.strip(),
            specification=specification.strip() if specification else None,
            note=note,
            archived=False,
        )
        self.db.add(m)
        self.db.commit()
        self.db.refresh(m)
        return m

    def list_medicines_for_personal(self, *, caregiver: User, target_user_id: int, include_archived: bool = False) -> List[Medicine]:
        self._assert_personal_can_manage_target(caregiver=caregiver, target_user_id=target_user_id)
        q = select(Medicine).where(Medicine.target_user_id == target_user_id)
        if not include_archived:
            q = q.where(Medicine.archived.is_(False))
        q = q.order_by(Medicine.id.desc())
        return list(self.db.execute(q).scalars().all())

    def list_medicines_for_elder(self, *, elder: User) -> List[Medicine]:
        if elder.role != UserRole.ELDERLY:
            raise forbidden("仅限长辈端查看")
        q = (
            select(Medicine)
            .where(Medicine.target_user_id == elder.id, Medicine.archived.is_(False))
            .order_by(Medicine.id.desc())
        )
        return list(self.db.execute(q).scalars().all())

    def create_plan(
        self,
        *,
        caregiver: User,
        target_user_id: int,
        medicine_id: int,
        start_date: date,
        schedules: List[ScheduleItem],
        label: Optional[str],
    ) -> MedicinePlan:
        self._assert_personal_can_manage_target(caregiver=caregiver, target_user_id=target_user_id)
        med = self.db.get(Medicine, medicine_id)
        if not med or med.target_user_id != target_user_id:
            raise not_found("药品不存在或不属于该长辈")
        payload = [s.model_dump() for s in schedules]
        plan = MedicinePlan(
            target_user_id=target_user_id,
            created_by_user_id=caregiver.id,
            medicine_id=medicine_id,
            status=PlanStatus.ACTIVE,
            start_date=start_date,
            schedules_json=payload,
            label=label.strip() if label else None,
        )
        self.db.add(plan)
        self.db.commit()
        self.db.refresh(plan)
        return plan

    def list_plans_for_personal(self, *, caregiver: User, target_user_id: int) -> List[PlanOut]:
        self._assert_personal_can_manage_target(caregiver=caregiver, target_user_id=target_user_id)
        rows = self.db.execute(
            select(MedicinePlan, Medicine)
            .join(Medicine, Medicine.id == MedicinePlan.medicine_id)
            .where(MedicinePlan.target_user_id == target_user_id)
            .order_by(MedicinePlan.id.desc())
        ).all()
        out: List[PlanOut] = []
        for p, m in rows:
            out.append(
                PlanOut(
                    id=p.id,
                    target_user_id=p.target_user_id,
                    medicine_id=p.medicine_id,
                    medicine_name=m.name,
                    status=p.status,
                    start_date=p.start_date,
                    schedules_json=list(p.schedules_json or []),
                    label=p.label,
                )
            )
        return out


def medicine_to_out(m: Medicine) -> MedicineOut:
    return MedicineOut(
        id=m.id,
        target_user_id=m.target_user_id,
        name=m.name,
        specification=m.specification,
        note=m.note,
        archived=m.archived,
    )
