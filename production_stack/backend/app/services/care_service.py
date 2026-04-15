from datetime import date, datetime, time, timedelta, timezone
from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import forbidden, not_found
from app.models.caregiver_binding import BindingStatus, CaregiverBinding
from app.models.intake_record import IntakeAction, IntakeRecord
from app.models.medicine import Medicine
from app.models.medicine_plan import MedicinePlan, PlanStatus
from app.models.user import User
from app.schemas.care import AdherencePointOut, MedicineOut, MedicineUpdateRequest, PlanOut, ReminderOut, ScheduleItem


class CareService:
    def __init__(self, db: Session):
        self.db = db

    def _assert_user_can_manage_target(self, *, current_user: User, target_user_id: int) -> None:
        if target_user_id == current_user.id:
            return
        binding = self.db.execute(
            select(CaregiverBinding).where(
                CaregiverBinding.caregiver_id == current_user.id,
                CaregiverBinding.elder_id == target_user_id,
                CaregiverBinding.status == BindingStatus.ACTIVE,
                CaregiverBinding.can_manage_medicine.is_(True),
            )
        ).scalar_one_or_none()
        if not binding:
            raise forbidden("无权限为该用户维护药品与计划，请先完成绑定并确认代管权限")

    @staticmethod
    def _to_utc_naive(dt: datetime | None) -> datetime | None:
        """统一时间比较口径：全部转成 UTC naive，避免 aware/naive 混比。"""
        if dt is None:
            return None
        if dt.tzinfo is None:
            return dt
        return dt.astimezone(timezone.utc).replace(tzinfo=None)

    def create_medicine(
        self,
        *,
        caregiver: User,
        target_user_id: int,
        name: str,
        specification: Optional[str],
        note: Optional[str],
    ) -> Medicine:
        self._assert_user_can_manage_target(current_user=caregiver, target_user_id=target_user_id)
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

    def list_medicines_for_user(self, *, current_user: User, target_user_id: int, include_archived: bool = False) -> List[Medicine]:
        self._assert_user_can_manage_target(current_user=current_user, target_user_id=target_user_id)
        q = select(Medicine).where(Medicine.target_user_id == target_user_id)
        if not include_archived:
            q = q.where(Medicine.archived.is_(False))
        q = q.order_by(Medicine.id.desc())
        return list(self.db.execute(q).scalars().all())

    def update_medicine(self, *, current_user: User, medicine_id: int, payload: MedicineUpdateRequest) -> Medicine:
        m = self.db.get(Medicine, medicine_id)
        if not m:
            raise not_found("药品不存在")
        self._assert_user_can_manage_target(current_user=current_user, target_user_id=m.target_user_id)

        if payload.name is not None:
            m.name = payload.name.strip()
        if payload.specification is not None:
            m.specification = payload.specification.strip() if payload.specification else None
        if payload.note is not None:
            m.note = payload.note
        if payload.archived is not None:
            m.archived = payload.archived
        self.db.add(m)
        self.db.commit()
        self.db.refresh(m)
        return m

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
        self._assert_user_can_manage_target(current_user=caregiver, target_user_id=target_user_id)
        med = self.db.get(Medicine, medicine_id)
        if not med or med.target_user_id != target_user_id:
            raise not_found("药品不存在或不属于该目标账号")
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

    def list_plans_for_user(self, *, current_user: User, target_user_id: int) -> List[PlanOut]:
        self._assert_user_can_manage_target(current_user=current_user, target_user_id=target_user_id)
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
                    created_at=p.created_at,
                    updated_at=p.updated_at,
                )
            )
        return out

    def list_today_reminders_for_user(
        self,
        *,
        current_user: User,
        target_user_id: int,
        on_date: date,
    ) -> List[ReminderOut]:
        self._assert_user_can_manage_target(current_user=current_user, target_user_id=target_user_id)
        plans = self.db.execute(
            select(MedicinePlan, Medicine)
            .join(Medicine, Medicine.id == MedicinePlan.medicine_id)
            .where(
                MedicinePlan.target_user_id == target_user_id,
                MedicinePlan.status == PlanStatus.ACTIVE,
                MedicinePlan.start_date <= on_date,
            )
            .order_by(MedicinePlan.id.desc())
        ).all()

        day_start = datetime.combine(on_date, time.min)
        day_end = day_start + timedelta(days=1)
        intake_rows = self.db.execute(
            select(IntakeRecord).where(
                IntakeRecord.target_user_id == target_user_id,
                IntakeRecord.due_time >= day_start,
                IntakeRecord.due_time < day_end,
            )
        ).scalars().all()
        by_event_key = {(r.plan_id, r.schedule_id, r.due_time): r for r in intake_rows}

        out: List[ReminderOut] = []
        weekday_idx = on_date.weekday()  # Monday=0 ... Sunday=6
        now = datetime.utcnow()
        for p, m in plans:
            schedules = list(p.schedules_json or [])
            for idx, sched in enumerate(schedules):
                weekdays = str(sched.get("weekdays", "1111111"))
                if len(weekdays) != 7 or weekdays[weekday_idx] != "1":
                    continue
                hour = int(sched.get("hour", 0))
                minute = int(sched.get("minute", 0))
                due = datetime.combine(on_date, time(hour=hour, minute=minute))
                schedule_id = f"{p.id}-{idx}"
                record = by_event_key.get((p.id, schedule_id, due))
                status = "pending"
                confirmed_at = None
                if record:
                    if record.action == IntakeAction.DELETED:
                        status = "deleted"
                    elif record.action == IntakeAction.MISSED:
                        status = "missed"
                    elif record.action == IntakeAction.SNOOZED:
                        snooze_until = self._to_utc_naive(record.snooze_until)
                        now_utc_naive = datetime.utcnow()
                        if snooze_until and snooze_until > now_utc_naive:
                            status = "snoozed"
                        else:
                            status = "pending"
                    else:
                        status = "taken"
                        confirmed_at = record.updated_at
                out.append(
                    ReminderOut(
                        id=f"{target_user_id}|{p.id}|{schedule_id}|{due.isoformat()}",
                        target_user_id=p.target_user_id,
                        plan_id=p.id,
                        schedule_id=schedule_id,
                        due_time=due,
                        status=status,
                        medicine_name=m.name,
                        created_at=now,
                        confirmed_at=confirmed_at,
                        snooze_until=record.snooze_until if record else None,
                        action_source=record.action_source if record else None,
                    )
                )

        out.sort(key=lambda x: x.due_time)
        return out

    def mark_reminder(
        self,
        *,
        current_user: User,
        target_user_id: int,
        plan_id: int,
        schedule_id: str,
        due_time: datetime,
        action: str,
        action_source: str | None = None,
    ) -> IntakeRecord:
        self._assert_user_can_manage_target(current_user=current_user, target_user_id=target_user_id)
        plan = self.db.get(MedicinePlan, plan_id)
        if not plan or plan.target_user_id != target_user_id:
            raise not_found("提醒对应计划不存在")
        row = self.db.execute(
            select(IntakeRecord).where(
                IntakeRecord.target_user_id == target_user_id,
                IntakeRecord.plan_id == plan_id,
                IntakeRecord.schedule_id == schedule_id,
                IntakeRecord.due_time == due_time,
            )
        ).scalar_one_or_none()
        if row:
            row.action = action
            row.snooze_until = None
            row.confirmed_by_user_id = current_user.id
            row.action_source = action_source or "app"
            self.db.add(row)
            self.db.commit()
            self.db.refresh(row)
            return row

        row = IntakeRecord(
            target_user_id=target_user_id,
            confirmed_by_user_id=current_user.id,
            plan_id=plan_id,
            schedule_id=schedule_id,
            due_time=due_time,
            action=action,
            action_source=action_source or "app",
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        return row

    def snooze_reminder(
        self,
        *,
        current_user: User,
        target_user_id: int,
        plan_id: int,
        schedule_id: str,
        due_time: datetime,
        snooze_minutes: int,
        action_source: str | None = None,
    ) -> IntakeRecord:
        self._assert_user_can_manage_target(current_user=current_user, target_user_id=target_user_id)
        plan = self.db.get(MedicinePlan, plan_id)
        if not plan or plan.target_user_id != target_user_id:
            raise not_found("提醒对应计划不存在")

        snooze_until = datetime.now(timezone.utc) + timedelta(minutes=snooze_minutes)
        row = self.db.execute(
            select(IntakeRecord).where(
                IntakeRecord.target_user_id == target_user_id,
                IntakeRecord.plan_id == plan_id,
                IntakeRecord.schedule_id == schedule_id,
                IntakeRecord.due_time == due_time,
            )
        ).scalar_one_or_none()
        if row:
            row.action = IntakeAction.SNOOZED
            row.snooze_until = snooze_until
            row.confirmed_by_user_id = current_user.id
            row.action_source = action_source or "app"
            self.db.add(row)
            self.db.commit()
            self.db.refresh(row)
            return row

        row = IntakeRecord(
            target_user_id=target_user_id,
            confirmed_by_user_id=current_user.id,
            plan_id=plan_id,
            schedule_id=schedule_id,
            due_time=due_time,
            action=IntakeAction.SNOOZED,
            snooze_until=snooze_until,
            action_source=action_source or "app",
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        return row

    def list_adherence_trend(
        self,
        *,
        current_user: User,
        target_user_id: int,
        days: int = 7,
    ) -> List[AdherencePointOut]:
        safe_days = max(1, min(days, 30))
        today = date.today()
        out: List[AdherencePointOut] = []
        for i in range(safe_days):
            d = today - timedelta(days=(safe_days - 1 - i))
            reminders = self.list_today_reminders_for_user(
                current_user=current_user,
                target_user_id=target_user_id,
                on_date=d,
            )
            effective = [r for r in reminders if r.status != "deleted"]
            total = len(effective)
            taken = len([r for r in effective if r.status == "taken"])
            rate = int(round((taken / total) * 100)) if total > 0 else 0
            out.append(AdherencePointOut(date=d, total=total, taken=taken, rate=rate))
        return out


def medicine_to_out(m: Medicine) -> MedicineOut:
    return MedicineOut(
        id=m.id,
        target_user_id=m.target_user_id,
        name=m.name,
        specification=m.specification,
        note=m.note,
        archived=m.archived,
        created_at=m.created_at,
        updated_at=m.updated_at,
    )
