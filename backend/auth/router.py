from typing import List, Optional
from fastapi import APIRouter, Depends, Response, Cookie, HTTPException, status
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.redis import get_redis
from core.security import get_current_user
from auth.models import User
from auth.schemas import (
    SendOTPRequest,
    SendOTPResponse,
    VerifyOTPRequest,
    TokenResponse,
    LogoutRequest,
    DeviceInfoResponse,
)
from auth.service import (
    send_otp_service,
    verify_otp_service,
    refresh_session_service,
    logout_device_service,
    get_user_devices_service,
)

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/send-otp", response_model=SendOTPResponse)
async def send_otp(
    request: SendOTPRequest,
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    return await send_otp_service(request, db, redis)


@router.post("/verify-otp", response_model=TokenResponse)
async def verify_otp(
    request: VerifyOTPRequest,
    response: Response,
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
):
    token_response, refresh_token = await verify_otp_service(request, db, redis)
    
    # Set HttpOnly refresh token cookie
    response.set_cookie(
        key="refresh_token",
        value=refresh_token,
        max_age=30 * 24 * 3600,
        httponly=True,
        samesite="lax",
        secure=False  # Set True in production with HTTPS
    )
    return token_response


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token_endpoint(
    refresh_token: Optional[str] = Cookie(None),
    db: AsyncSession = Depends(get_db),
):
    if not refresh_token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token missing in cookie")
    return await refresh_session_service(refresh_token, db)


@router.post("/logout")
async def logout(
    request: LogoutRequest,
    response: Response,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await logout_device_service(current_user.id, request.device_id, db)
    response.delete_cookie("refresh_token")
    return {"message": "Logged out successfully"}


@router.get("/devices", response_model=List[DeviceInfoResponse])
async def list_devices(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await get_user_devices_service(current_user.id, db)
