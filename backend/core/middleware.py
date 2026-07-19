from fastapi import HTTPException, status
from redis.asyncio import Redis


async def check_otp_rate_limit(phone: str, redis_client: Redis) -> None:
    """
    Enforces max 3 OTP requests per phone per 10 minutes using Redis counter.
    Key structure: otp:ratelimit:{phone}
    """
    key = f"otp:ratelimit:{phone}"
    current_count = await redis_client.get(key)
    if current_count is not None and int(current_count) >= 3:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rate limit exceeded. Maximum 3 OTP requests per 10 minutes allowed."
        )
    
    pipe = redis_client.pipeline()
    pipe.incr(key)
    if current_count is None:
        pipe.expire(key, 600)  # 10 minutes in seconds
    await pipe.execute()
