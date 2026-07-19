from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from redis.asyncio import Redis

from core.redis import get_redis
from core.security import get_current_user
from auth.models import User
from pairing.schemas import (
    PairingCreateResponse,
    PairingStatusResponse,
    PairDeviceRequest,
    PairDeviceResponse,
)
from pairing.service import (
    create_pairing_session_service,
    get_pairing_status_service,
    pair_device_service,
    delete_pairing_session_service,
)
from pairing.websocket import pairing_manager

router = APIRouter(tags=["pairing"])


@router.post("/api/pairing/create", response_model=PairingCreateResponse)
async def create_pairing(redis: Redis = Depends(get_redis)):
    return await create_pairing_session_service(redis)


@router.get("/api/pairing/{session_id}", response_model=PairingStatusResponse)
async def get_pairing(session_id: str, redis: Redis = Depends(get_redis)):
    return await get_pairing_status_service(session_id, redis)


@router.post("/api/pairing/{session_id}/pair", response_model=PairDeviceResponse)
async def pair_session(
    session_id: str,
    request: PairDeviceRequest,
    current_user: User = Depends(get_current_user),
    redis: Redis = Depends(get_redis),
):
    return await pair_device_service(
        session_id=session_id,
        pairing_token=request.pairing_token,
        user=current_user,
        device_name=request.device_name,
        redis_client=redis,
    )


@router.delete("/api/pairing/{session_id}")
async def delete_pairing(session_id: str, redis: Redis = Depends(get_redis)):
    return await delete_pairing_session_service(session_id, redis)


@router.websocket("/ws/pairing/{session_id}")
async def pairing_websocket(websocket: WebSocket, session_id: str):
    await pairing_manager.connect(session_id, websocket)
    try:
        while True:
            # Listen for heartbeats/ping or keep alive
            await websocket.receive_text()
    except WebSocketDisconnect:
        pairing_manager.disconnect(session_id, websocket)
    except Exception:
        pairing_manager.disconnect(session_id, websocket)
