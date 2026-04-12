from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.core.redis_client import get_redis
from app.schemas.auth import (
    LoginPasswordRequest,
    LoginSmsRequest,
    LogoutRequest,
    RefreshRequest,
    RegisterRequest,
    ResetPasswordRequest,
    SmsSendData,
    SmsSendRequest,
    TokenPair,
    UserMe,
)
from app.schemas.common import ApiResponse
from app.services.auth_service import AuthService
from app.services.sms_code_service import SmsCodeService
from app.services.sms_service import get_sms_service
from app.utils.validators import validate_password, validate_sms_code

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


@router.post("/sms/send", response_model=ApiResponse[SmsSendData])
def send_sms(
    body: SmsSendRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    rds = get_redis()
    sms = get_sms_service()
    svc = SmsCodeService(db=db, rds=rds, sms=sms)
    code = svc.send_code(
        phone=body.phone,
        scene=body.scene,
        ip=request.client.host if request.client else None,
        device_id=body.device_id,
    )
    data = SmsSendData(cooldown_seconds=settings.sms_cooldown_seconds, debug_code=code)
    if not (settings.debug or settings.app_env == "dev"):
        data.debug_code = None
    return ApiResponse(data=data)


@router.post("/register", response_model=ApiResponse[TokenPair])
def register(
    body: RegisterRequest,
    db: Session = Depends(get_db),
):
    validate_sms_code(body.code)
    validate_password(body.password)

    rds = get_redis()
    SmsCodeService(db=db, rds=rds, sms=get_sms_service()).verify_code(
        phone=body.phone,
        scene="register",
        code=body.code,
    )
    tokens, _ = AuthService(db=db, rds=rds).register(phone=body.phone, password=body.password, role=body.role)
    return ApiResponse(data=tokens)


@router.post("/login/password", response_model=ApiResponse[TokenPair])
def login_password(
    body: LoginPasswordRequest,
    db: Session = Depends(get_db),
):
    rds = get_redis()
    tokens, _ = AuthService(db=db, rds=rds).login_password(phone=body.phone, password=body.password)
    return ApiResponse(data=tokens)


@router.post("/login/sms", response_model=ApiResponse[TokenPair])
def login_sms(
    body: LoginSmsRequest,
    db: Session = Depends(get_db),
):
    validate_sms_code(body.code)
    rds = get_redis()
    SmsCodeService(db=db, rds=rds, sms=get_sms_service()).verify_code(
        phone=body.phone,
        scene="login",
        code=body.code,
    )
    tokens, _ = AuthService(db=db, rds=rds).login_sms(phone=body.phone)
    return ApiResponse(data=tokens)


@router.post("/password/reset", response_model=ApiResponse[None])
def reset_password(
    body: ResetPasswordRequest,
    db: Session = Depends(get_db),
):
    validate_sms_code(body.code)
    validate_password(body.new_password)

    rds = get_redis()
    SmsCodeService(db=db, rds=rds, sms=get_sms_service()).verify_code(
        phone=body.phone,
        scene="reset_password",
        code=body.code,
    )
    AuthService(db=db, rds=rds).reset_password(phone=body.phone, new_password=body.new_password)
    return ApiResponse(message="ok")


@router.post("/refresh", response_model=ApiResponse[TokenPair])
def refresh(
    body: RefreshRequest,
    db: Session = Depends(get_db),
):
    rds = get_redis()
    tokens = AuthService(db=db, rds=rds).refresh(refresh_token=body.refresh_token)
    return ApiResponse(data=tokens)


@router.post("/logout", response_model=ApiResponse[None])
def logout(
    _: LogoutRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rds = get_redis()
    AuthService(db=db, rds=rds).logout(user_id=current_user.id)
    return ApiResponse(message="ok")


@router.get("/me", response_model=ApiResponse[UserMe])
def me(
    current_user=Depends(get_current_user),
):
    return ApiResponse(data=UserMe(id=current_user.id, phone=current_user.phone, role=current_user.role))
