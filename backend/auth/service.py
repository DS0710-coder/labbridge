import random
import uuid
from datetime import datetime, timedelta, timezone
from typing import List, Tuple
from fastapi import HTTPException, status
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import update

from core.config import settings
from core.middleware import check_otp_rate_limit
from core.security import (
    create_access_token,
    create_refresh_token,
    hash_token,
    verify_token_hash,
    verify_refresh_token,
)
from auth.models import User, RefreshToken, utc_now
from auth.schemas import (
    SendOTPRequest,
    SendOTPResponse,
    VerifyOTPRequest,
    TokenResponse,
    DeviceInfoResponse,
)


async def send_otp_service(request: SendOTPRequest, db: AsyncSession, redis_client: Redis) -> SendOTPResponse:
    await check_otp_rate_limit(request.phone, redis_client)

    if settings.SMS_PROVIDER_KEY == "dev":
        otp_code = "123456"
    else:
        otp_code = f"{random.randint(100000, 999999)}"

    # Store OTP with 5 minute TTL
    key = f"otp:code:{request.phone}"
    await redis_client.set(key, otp_code, ex=300)

    # In production, integrate Twilio/Fast2SMS here
    dev_otp = otp_code if settings.SMS_PROVIDER_KEY == "dev" else None
    return SendOTPResponse(
        message="OTP sent successfully via SMS",
        dev_otp=dev_otp
    )


async def verify_otp_service(request: VerifyOTPRequest, db: AsyncSession, redis_client: Redis) -> Tuple[TokenResponse, str]:
    key = f"otp:code:{request.phone}"
    stored_otp = await redis_client.get(key)

    if not stored_otp:
        # Allow fallback in dev mode if requested immediately
        if settings.SMS_PROVIDER_KEY != "dev" or request.otp != "123456":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="OTP expired or invalid"
            )
    elif stored_otp != request.otp:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect OTP"
        )
    else:
        await redis_client.delete(key)

    # Find or create user
    result = await db.execute(select(User).where(User.phone == request.phone))
    user = result.scalar_one_or_none()
    if not user:
        user = User(id=str(uuid.uuid4()), phone=request.phone, created_at=utc_now(), last_active=utc_now())
        db.add(user)
        await db.commit()
        await db.refresh(user)
    else:
        user.last_active = utc_now()
        await db.commit()

    # Generate tokens
    access_token = create_access_token({"sub": user.id, "phone": user.phone})
    refresh_token = create_refresh_token({"sub": user.id, "device_id": request.device_id})

    # Store hashed refresh token
    expires_at = utc_now() + timedelta(days=30)
    token_record = RefreshToken(
        id=str(uuid.uuid4()),
        user_id=user.id,
        token_hash=hash_token(refresh_token),
        device_name=request.device_name,
        device_id=request.device_id,
        created_at=utc_now(),
        expires_at=expires_at,
        revoked=False
    )
    db.add(token_record)
    await db.commit()

    response = TokenResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=900,
        user_id=user.id,
        phone=user.phone,
        refresh_token=refresh_token
    )
    return response, refresh_token


async def refresh_session_service(refresh_token: str, db: AsyncSession) -> TokenResponse:
    payload = verify_refresh_token(refresh_token)
    user_id = payload.get("sub")
    device_id = payload.get("device_id")

    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token payload")

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    # Find matching active token
    stmt = select(RefreshToken).where(
        RefreshToken.user_id == user_id,
        RefreshToken.revoked == False,
        RefreshToken.expires_at > utc_now()
    )
    if device_id:
        stmt = stmt.where(RefreshToken.device_id == device_id)

    tokens_result = await db.execute(stmt)
    token_records = tokens_result.scalars().all()

    valid_record = None
    for record in token_records:
        if verify_token_hash(refresh_token, record.token_hash):
            valid_record = record
            break

    if not valid_record:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token revoked or invalid")

    access_token = create_access_token({"sub": user.id, "phone": user.phone})
    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=900,
        user_id=user.id,
        phone=user.phone,
        refresh_token=refresh_token
    )


async def logout_device_service(user_id: str, device_id: str, db: AsyncSession) -> None:
    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == user_id, RefreshToken.device_id == device_id)
        .values(revoked=True)
    )
    await db.commit()


async def get_user_devices_service(user_id: str, db: AsyncSession) -> List[DeviceInfoResponse]:
    result = await db.execute(
        select(RefreshToken)
        .where(RefreshToken.user_id == user_id, RefreshToken.revoked == False, RefreshToken.expires_at > utc_now())
        .order_by(RefreshToken.created_at.desc())
    )
    records = result.scalars().all()
    return [DeviceInfoResponse.model_validate(r) for r in records]
