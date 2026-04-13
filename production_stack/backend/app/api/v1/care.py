from typing import List

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_personal
from app.core.database import get_db
from app.models.medicine import Medicine
from app.models.user import User
from app.schemas.care import (
    BindingCreateRequest,
    BoundElderOut,
    MedicineCreateRequest,
    MedicineOut,
    PlanCreateRequest,
    PlanOut,
)
from app.schemas.common import ApiResponse
from app.services.binding_service import BindingService
from app.services.care_service import CareService, medicine_to_out

router = APIRouter(prefix="/api/v1", tags=["care"])


@router.post("/bindings", response_model=ApiResponse[BoundElderOut])
def create_binding(
    body: BindingCreateRequest,
    caregiver: User = Depends(require_personal),
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
    caregiver: User = Depends(require_personal),
    db: Session = Depends(get_db),
):
    rows = BindingService(db).list_bound_elders(caregiver=caregiver)
    return ApiResponse(data=rows)


@router.get("/care/medicines", response_model=ApiResponse[List[MedicineOut]])
def list_medicines_for_caregiver(
    target_user_id: int = Query(..., ge=1),
    caregiver: User = Depends(require_personal),
    db: Session = Depends(get_db),
):
    meds = CareService(db).list_medicines_for_personal(caregiver=caregiver, target_user_id=target_user_id)
    return ApiResponse(data=[medicine_to_out(m) for m in meds])


@router.post("/care/medicines", response_model=ApiResponse[MedicineOut])
def create_medicine(
    body: MedicineCreateRequest,
    caregiver: User = Depends(require_personal),
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


@router.get("/care/plans", response_model=ApiResponse[List[PlanOut]])
def list_plans(
    target_user_id: int = Query(..., ge=1),
    caregiver: User = Depends(require_personal),
    db: Session = Depends(get_db),
):
    plans = CareService(db).list_plans_for_personal(caregiver=caregiver, target_user_id=target_user_id)
    return ApiResponse(data=plans)


@router.post("/care/plans", response_model=ApiResponse[PlanOut])
def create_plan(
    body: PlanCreateRequest,
    caregiver: User = Depends(require_personal),
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
        )
    )


@router.get("/elder/medicines", response_model=ApiResponse[List[MedicineOut]])
def list_medicines_for_elder_self(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    meds = CareService(db).list_medicines_for_elder(elder=current_user)
    return ApiResponse(data=[medicine_to_out(m) for m in meds])
