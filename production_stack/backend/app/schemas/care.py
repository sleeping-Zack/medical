from datetime import date
from typing import List, Optional

from pydantic import BaseModel, Field, field_validator


class BindingCreateRequest(BaseModel):
    elder_short_id: str = Field(..., min_length=6, max_length=6, description="长辈端账号 6 位绑定短号")
    phone_last4: str = Field(..., min_length=4, max_length=4, description="长辈手机号后四位")

    @field_validator("elder_short_id")
    @classmethod
    def digits_short(cls, v: str) -> str:
        if not v.isdigit():
            raise ValueError("绑定短号须为 6 位数字")
        return v

    @field_validator("phone_last4")
    @classmethod
    def digits_last4(cls, v: str) -> str:
        if not v.isdigit():
            raise ValueError("手机后四位须为数字")
        return v


class BoundElderOut(BaseModel):
    elder_id: int
    short_id: str
    phone_masked: str
    can_manage_medicine: bool
    can_view_records: bool
    can_receive_alerts: bool


class MedicineCreateRequest(BaseModel):
    target_user_id: int = Field(..., ge=1)
    name: str = Field(..., min_length=1, max_length=128)
    specification: Optional[str] = Field(default=None, max_length=255)
    note: Optional[str] = None


class MedicineOut(BaseModel):
    id: int
    target_user_id: int
    name: str
    specification: Optional[str]
    note: Optional[str]
    archived: bool


class ScheduleItem(BaseModel):
    hour: int = Field(ge=0, le=23)
    minute: int = Field(ge=0, le=59)
    # 从左到右：周一…周日，1 表示该日需要服药
    weekdays: str = Field(..., min_length=7, max_length=7)

    @field_validator("weekdays")
    @classmethod
    def bin_weekdays(cls, v: str) -> str:
        if not all(c in "01" for c in v):
            raise ValueError("weekdays 须为 7 位 0/1 字符串")
        return v


class PlanCreateRequest(BaseModel):
    target_user_id: int = Field(..., ge=1)
    medicine_id: int = Field(..., ge=1)
    start_date: date
    schedules: List[ScheduleItem] = Field(..., min_length=1)
    label: Optional[str] = Field(default=None, max_length=64)


class PlanOut(BaseModel):
    id: int
    target_user_id: int
    medicine_id: int
    medicine_name: str
    status: str
    start_date: date
    schedules_json: List[dict]
    label: Optional[str]
