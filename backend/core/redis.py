import redis.asyncio as redis
from core.config import settings

redis_client: redis.Redis | None = None


async def init_redis():
    global redis_client
    redis_client = redis.from_url(
        settings.REDIS_URL,
        encoding="utf-8",
        decode_responses=True
    )


async def close_redis():
    global redis_client
    if redis_client:
        await redis_client.aclose()


async def get_redis() -> redis.Redis:
    global redis_client
    if redis_client is None:
        await init_redis()
    return redis_client
