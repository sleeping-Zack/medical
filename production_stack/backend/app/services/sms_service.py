from abc import ABC, abstractmethod

from app.core.config import settings


class SmsService(ABC):
    @abstractmethod
    def send_code(self, *, phone: str, code: str, scene: str) -> None: ...


class MockSmsService(SmsService):
    def send_code(self, *, phone: str, code: str, scene: str) -> None:
        return


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
        raise NotImplementedError()


class AliyunSmsService(SmsService):
    def __init__(self) -> None:
        if not (
            settings.aliyun_sms_access_key_id
            and settings.aliyun_sms_access_key_secret
            and settings.aliyun_sms_sign_name
            and settings.aliyun_sms_template_code
        ):
            raise RuntimeError("Aliyun SMS 配置不完整")

    def send_code(self, *, phone: str, code: str, scene: str) -> None:
        raise NotImplementedError()


def get_sms_service() -> SmsService:
    provider = (settings.sms_provider or "mock").lower()
    if provider == "tencent":
        return TencentSmsService()
    if provider == "aliyun":
        return AliyunSmsService()
    return MockSmsService()

