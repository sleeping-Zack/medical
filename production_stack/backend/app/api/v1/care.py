from datetime import date
from typing import List

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.medicine import Medicine
from app.models.user import User
from app.schemas.care import (
    AdherencePointOut,
    BindingCreateRequest,
    BoundCaregiverOut,
    BoundElderOut,
    MedicineCreateRequest,
    MedicineUpdateRequest,
    MedicineOut,
    PlanCreateRequest,
    PlanOut,
    ReminderMarkRequest,
    ReminderSnoozeRequest,
    ReminderOut,
)
from app.schemas.common import ApiResponse
from app.services.binding_service import BindingService
from app.services.care_service import CareService, medicine_to_out

router = APIRouter(prefix="/api/v1", tags=["care"])


@router.post("/bindings", response_model=ApiResponse[BoundElderOut])
def create_binding(
    body: BindingCreateRequest,
    caregiver: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    svc = BindingService(db)
    binding = svc.bind_by_short_id_and_phone_tail(
        caregiver=caregiver,
        elder_short_id=body.elder_short_id,
        phone_last4=body.phone_last4,
    )
    return ApiResponse(data=svc.to_bound_elder_out(binding))


@router.get("/bindings", response_model=ApiResponse[List[BoundElderOut]])
def list_bindings(
    caregiver: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = BindingService(db).list_bound_elders(caregiver=caregiver)
    return ApiResponse(data=rows)


@router.get("/bindings/incoming", response_model=ApiResponse[List[BoundCaregiverOut]])
def list_incoming_bindings(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = BindingService(db).list_caregivers_for_target(target_user=current_user)
    return ApiResponse(data=rows)


@router.get("/care/medicines", response_model=ApiResponse[List[MedicineOut]])
def list_medicines_for_caregiver(
    target_user_id: int = Query(..., ge=1),
    caregiver: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    meds = CareService(db).list_medicines_for_user(current_user=caregiver, target_user_id=target_user_id)
    return ApiResponse(data=[medicine_to_out(m) for m in meds])


@router.post("/care/medicines", response_model=ApiResponse[MedicineOut])
def create_medicine(
    body: MedicineCreateRequest,
    caregiver: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    m = CareService(db).create_medicine(
        caregiver=caregiver,
        target_user_id=body.target_user_id,
        name=body.name,
        specification=body.specification,
        note=body.note,
    )
    return ApiResponse(data=medicine_to_out(m))


@router.put("/care/medicines/{medicine_id}", response_model=ApiResponse[MedicineOut])
def update_medicine(
    medicine_id: int,
    body: MedicineUpdateRequest,
    caregiver: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    m = CareService(db).update_medicine(current_user=caregiver, medicine_id=medicine_id, payload=body)
    return ApiResponse(data=medicine_to_out(m))


@router.get("/care/plans", response_model=ApiResponse[List[PlanOut]])
def list_plans(
    target_user_id: int = Query(..., ge=1),
    caregiver: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    plans = CareService(db).list_plans_for_user(current_user=caregiver, target_user_id=target_user_id)
    return ApiResponse(data=plans)


@router.post("/care/plans", response_model=ApiResponse[PlanOut])
def create_plan(
    body: PlanCreateRequest,
    caregiver: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    svc = CareService(db)
    p = svc.create_plan(
        caregiver=caregiver,
        target_user_id=body.target_user_id,
        medicine_id=body.medicine_id,
        start_date=body.start_date,
        schedules=body.schedules,
        label=body.label,
    )
    med = db.get(Medicine, p.medicine_id)
    return ApiResponse(
        data=PlanOut(
            id=p.id,
            target_user_id=p.target_user_id,
            medicine_id=p.medicine_id,
            medicine_name=med.name if med else "",
            status=p.status,
            start_date=p.start_date,
            schedules_json=list(p.schedules_json or []),
            label=p.label,
            created_at=p.created_at,
            updated_at=p.updated_at,
        )
    )


@router.get("/care/reminders", response_model=ApiResponse[List[ReminderOut]])
def list_reminders(
    target_user_id: int = Query(..., ge=1),
    on_date: date = Query(..., description="查询哪一天，格式 YYYY-MM-DD"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = CareService(db).list_today_reminders_for_user(
        current_user=current_user,
        target_user_id=target_user_id,
        on_date=on_date,
    )
    return ApiResponse(data=rows)


@router.post("/care/reminders/mark", response_model=ApiResponse[None])
def mark_reminder(
    body: ReminderMarkRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    CareService(db).mark_reminder(
        current_user=current_user,
        target_user_id=body.target_user_id,
        plan_id=body.plan_id,
        schedule_id=body.schedule_id,
        due_time=body.due_time,
        action=body.action,
        action_source=body.action_source,
    )
    return ApiResponse(message="ok")


@router.post("/care/reminders/snooze", response_model=ApiResponse[None])
def snooze_reminder(
    body: ReminderSnoozeRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    CareService(db).snooze_reminder(
        current_user=current_user,
        target_user_id=body.target_user_id,
        plan_id=body.plan_id,
        schedule_id=body.schedule_id,
        due_time=body.due_time,
        snooze_minutes=body.snooze_minutes,
        action_source=body.action_source,
    )
    return ApiResponse(message="ok")


@router.get("/care/adherence", response_model=ApiResponse[List[AdherencePointOut]])
def get_adherence_trend(
    target_user_id: int = Query(..., ge=1),
    days: int = Query(7, ge=1, le=30),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = CareService(db).list_adherence_trend(
        current_user=current_user,
        target_user_id=target_user_id,
        days=days,
    )
    return ApiResponse(data=rows)
