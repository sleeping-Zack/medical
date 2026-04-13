from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_env: str = "dev"
    debug: bool = True

    mysql_dsn: str
    redis_url: str
    #: 为 True 时使用内存 Redis（fakeredis），无需本机安装/启动 Redis，仅建议开发用
    redis_use_mock: bool = False

    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 14

    sms_provider: str = "mock"
    sms_code_ttl_seconds: int = 300
    sms_code_salt: str
    sms_cooldown_seconds: int = 60
    sms_hourly_limit: int = 5
    sms_daily_limit: int = 10

    tencent_sms_secret_id: Optional[str] = None
    tencent_sms_secret_key: Optional[str] = None
    tencent_sms_app_id: Optional[str] = None
    tencent_sms_sign_name: Optional[str] = None
    tencent_sms_template_id: Optional[str] = None

    aliyun_sms_access_key_id: Optional[str] = None
    aliyun_sms_access_key_secret: Optional[str] = None
    aliyun_sms_sign_name: Optional[str] = None
    aliyun_sms_template_code: Optional[str] = None
    #: 短信模板里验证码变量名，与控制台模板一致，一般为 code
    aliyun_sms_template_param_key: str = "code"
    #: 阿里云短信 API 区域，默认杭州
    aliyun_sms_region_id: str = "cn-hangzhou"


settings = Settings()
