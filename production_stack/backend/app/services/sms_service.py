import base64
import hashlib
import hmac
import json
import uuid
from abc import ABC, abstractmethod
from datetime import datetime, timezone
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

from app.core.config import settings


class SmsService(ABC):
    @abstractmethod
    def send_code(self, *, phone: str, code: str, scene: str) -> None: ...


class MockSmsService(SmsService):
    def send_code(self, *, phone: str, code: str, scene: str) -> None:
        return


def _aliyun_percent_encode(s: str) -> str:
    """阿里云 RPC 签名用的百分号编码（与 urllib 默认略有不同）。"""
    return quote(str(s), safe="", encoding="utf-8").replace("+", "%20").replace("*", "%2A").replace("%7E", "~")


class AliyunSmsService(SmsService):
    """调用阿里云短信 SendSms（签名版本 1，GET），无需额外 pip 依赖。"""

    def __init__(self) -> None:
        if not (
            settings.aliyun_sms_access_key_id
            and settings.aliyun_sms_access_key_secret
            and settings.aliyun_sms_sign_name
            and settings.aliyun_sms_template_code
        ):
            raise RuntimeError("Aliyun SMS 配置不完整，请检查 .env 中 ALIYUN_SMS_*")

    def send_code(self, *, phone: str, code: str, scene: str) -> None:
        _ = scene  # 模板侧可按业务区分，当前共用一个验证码模板
        secret = settings.aliyun_sms_access_key_secret or ""
        params: dict[str, str] = {
            "Format": "JSON",
            "Version": "2017-05-25",
            "AccessKeyId": settings.aliyun_sms_access_key_id or "",
            "SignatureMethod": "HMAC-SHA1",
            "Timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "SignatureVersion": "1.0",
            "SignatureNonce": str(uuid.uuid4()),
            "Action": "SendSms",
            "RegionId": settings.aliyun_sms_region_id,
            "PhoneNumbers": phone,
            "SignName": settings.aliyun_sms_sign_name or "",
            "TemplateCode": settings.aliyun_sms_template_code or "",
            "TemplateParam": json.dumps(
                {settings.aliyun_sms_template_param_key: code},
                ensure_ascii=False,
            ),
        }
        sorted_keys = sorted(params.keys())
        canonical = "&".join(f"{_aliyun_percent_encode(k)}={_aliyun_percent_encode(params[k])}" for k in sorted_keys)
        string_to_sign = f"GET&{_aliyun_percent_encode('/')}&{_aliyun_percent_encode(canonical)}"
        key = (secret + "&").encode("utf-8")
        signature = base64.b64encode(
            hmac.new(key, string_to_sign.encode("utf-8"), hashlib.sha1).digest()
        ).decode()
        params["Signature"] = signature

        query = "&".join(f"{_aliyun_percent_encode(k)}={_aliyun_percent_encode(params[k])}" for k in sorted(params.keys()))
        url = f"https://dysmsapi.aliyuncs.com/?{query}"
        try:
            req = Request(url, method="GET", headers={"Accept": "application/json"})
            with urlopen(req, timeout=15) as resp:
                raw = resp.read().decode("utf-8")
        except HTTPError as e:
            raise RuntimeError(f"阿里云短信 HTTP 错误: {e.code} {e.reason}") from e
        except URLError as e:
            raise RuntimeError(f"阿里云短信网络错误: {e.reason}") from e

        try:
            body = json.loads(raw)
        except json.JSONDecodeError as e:
            raise RuntimeError(f"阿里云短信返回非 JSON: {raw[:200]}") from e

        if body.get("Code") != "OK":
            msg = body.get("Message") or body.get("Code") or str(body)
            raise RuntimeError(f"阿里云短信发送失败: {msg}")


class TencentSmsService(SmsService):
    def __init__(self) -> None:
        if not (
            settings.tencent_sms_secret_id
            and settings.tencent_sms_secret_key
            and settings.tencent_sms_app_id
            and settings.tencent_sms_sign_name
            and settings.tencent_sms_template_id
        ):
            raise RuntimeError("Tencent SMS 配置不完整")

    def send_code(self, *, phone: str, code: str, scene: str) -> None:
        raise NotImplementedError(
            "腾讯云短信尚未在本仓库实现；请改用 SMS_PROVIDER=aliyun，"
            "或自行接入 tencentcloud-sdk-python 并在 TencentSmsService.send_code 中实现。"
        )


def get_sms_service() -> SmsService:
    provider = (settings.sms_provider or "mock").lower()
    if provider == "tencent":
        return TencentSmsService()
    if provider == "aliyun":
        return AliyunSmsService()
    return MockSmsService()
