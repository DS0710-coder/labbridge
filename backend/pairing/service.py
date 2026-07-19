import json
import secrets
import time
import uuid
from typing import Optional
from fastapi import HTTPException, status
from redis.asyncio import Redis

from auth.models import User
from pairing.websocket import pairing_manager


async def create_pairing_session_service(redis_client: Redis) -> dict:
    session_id = str(uuid.uuid4())
    pairing_token = secrets.token_urlsafe(24)
    expires_at = int(time.time()) + 120  # 2 minutes exact TTL

    session_data = {
        "user_id": None,
        "pairing_token": pairing_token,
        "paired": False,
        "expires_at": expires_at,
        "device_name": None,
    }

    # Store in Redis with 5-minute (300s) TTL
    await redis_client.set(f"session:{session_id}", json.dumps(session_data), ex=300)

    qr_payload = {
        "session_id": session_id,
        "pairing_token": pairing_token,
        "expiry": expires_at,
    }

    return {
        "session_id": session_id,
        "qr_payload": qr_payload,
        "expires_at": expires_at,
    }


async def get_pairing_status_service(session_id: str, redis_client: Redis) -> dict:
    raw_data = await redis_client.get(f"session:{session_id}")
    if not raw_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session expired or not found",
        )
    
    data = json.loads(raw_data)
    return {
        "paired": data.get("paired", False),
        "user_id": data.get("user_id"),
        "device_name": data.get("device_name"),
    }


async def pair_device_service(
    session_id: str,
    pairing_token: str,
    user: User,
    device_name: Optional[str],
    redis_client: Redis,
) -> dict:
    raw_data = await redis_client.get(f"session:{session_id}")
    if not raw_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session expired or not found",
        )

    data = json.loads(raw_data)

    if data.get("paired"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session is already paired",
        )

    if int(time.time()) > data.get("expires_at", 0):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="QR pairing code has expired",
        )

    if not data.get("pairing_token") or data.get("pairing_token") != pairing_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or already used pairing token",
        )

    # Mark paired and invalidate single-use token immediately
    data["paired"] = True
    data["user_id"] = user.id
    data["device_name"] = device_name or "Android Device"
    data["pairing_token"] = None  # Single-use: consumed

    await redis_client.set(f"session:{session_id}", json.dumps(data), ex=300)

    # Broadcast event over WebSocket
    event_payload = {
        "event": "paired",
        "session_id": session_id,
        "user_id": user.id,
        "device_name": data["device_name"],
    }
    await pairing_manager.broadcast_to_session(session_id, event_payload)

    return {"message": "Paired successfully", "session_id": session_id, "device_name": data["device_name"]}


async def delete_pairing_session_service(session_id: str, redis_client: Redis) -> dict:
    await redis_client.delete(f"session:{session_id}")
    await pairing_manager.broadcast_to_session(session_id, {"event": "disconnected", "session_id": session_id})
    return {"message": "Session disconnected and deleted"}
