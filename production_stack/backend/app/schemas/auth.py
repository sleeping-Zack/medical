from typing import Optional

from pydantic import BaseModel, Field

from app.models.sms_code_log import SmsScene
from app.models.user import UserRole


class SmsSendRequest(BaseModel):
    phone: str = Field(..., examples=["13800138000"])
    scene: str = Field(..., examples=[SmsScene.REGISTER])
    device_id: Optional[str] = Field(default=None, examples=["device-abc"])


class SmsSendData(BaseModel):
    cooldown_seconds: int = 60
    debug_code: Optional[str] = None


class RegisterRequest(BaseModel):
    phone: str
    code: str
    password: str
    role: str = Field(..., examples=[UserRole.PERSONAL])


class LoginPasswordRequest(BaseModel):
    phone: str
    password: str


class LoginSmsRequest(BaseModel):
    phone: str
    code: str


class ResetPasswordRequest(BaseModel):
    phone: str
    code: str
    new_password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: Optional[str] = None


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class UserMe(BaseModel):
    id: int
    phone: str
    role: str
    short_id: str = Field(default="", description="6 位绑定短号，长辈端展示给家属用于绑定")

