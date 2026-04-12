import re

from app.core.errors import bad_request


MAINLAND_PHONE_RE = re.compile(r"^1[3-9]\d{9}$")
SMS_CODE_RE = re.compile(r"^\d{6}$")
PASSWORD_RE = re.compile(r"^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$")


def validate_phone(phone: str) -> None:
    if not MAINLAND_PHONE_RE.fullmatch(phone or ""):
        raise bad_request("请输入有效的 11 位中国大陆手机号")


def validate_sms_code(code: str) -> None:
    if not SMS_CODE_RE.fullmatch(code or ""):
        raise bad_request("请输入 6 位短信验证码")


def validate_password(password: str) -> None:
    p = password or ""
    if len(p) > 128:
        raise bad_request("密码过长，请不超过 128 个字符")
    if not PASSWORD_RE.fullmatch(p):
        raise bad_request("密码至少 8 位，且必须包含字母和数字")

