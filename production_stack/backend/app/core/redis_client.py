from functools import lru_cache

import redis

from app.core.config import settings


@lru_cache(maxsize=1)
def get_redis() -> redis.Redis:
    if settings.redis_use_mock:
        import fakeredis

        # 与 redis.Redis 接口兼容，满足本项目的 setex/get/incr 等用法
        return fakeredis.FakeRedis(decode_responses=True)  # type: ignore[return-value]
    return redis.Redis.from_url(settings.redis_url, decode_responses=True)

