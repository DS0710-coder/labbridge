from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from redis.asyncio import Redis

from core.redis import get_redis
from transfer.schemas import (
    TransferInitRequest,
    TransferInitResponse,
    UploadChunkRequest,
    UploadChunkResponse,
    TransferStatusResponse,
    TransferCancelResponse,
)
from transfer.service import (
    init_transfer_service,
    upload_chunk_service,
    acknowledge_chunk_service,
    get_transfer_status_service,
    cancel_transfer_service,
)
from transfer.websocket import transfer_manager

router = APIRouter(tags=["transfer"])


@router.post("/api/transfer/init", response_model=TransferInitResponse)
async def init_transfer(
    request: TransferInitRequest, redis: Redis = Depends(get_redis)
):
    return await init_transfer_service(request, redis)


@router.post("/api/transfer/{id}/chunk", response_model=UploadChunkResponse)
async def upload_chunk(
    id: str, request: UploadChunkRequest, redis: Redis = Depends(get_redis)
):
    return await upload_chunk_service(id, request, redis)


@router.post("/api/transfer/{id}/ack")
async def acknowledge_chunk(
    id: str, chunk_index: int, redis: Redis = Depends(get_redis)
):
    return await acknowledge_chunk_service(id, chunk_index, redis)


@router.get("/api/transfer/{id}/status", response_model=TransferStatusResponse)
async def get_transfer_status(id: str, redis: Redis = Depends(get_redis)):
    return await get_transfer_status_service(id, redis)


@router.post("/api/transfer/{id}/cancel", response_model=TransferCancelResponse)
async def cancel_transfer(id: str, redis: Redis = Depends(get_redis)):
    return await cancel_transfer_service(id, redis)


@router.websocket("/ws/transfer/{session_id}")
async def transfer_websocket(websocket: WebSocket, session_id: str):
    await transfer_manager.connect(session_id, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            if data.get("type") == "ack":
                transfer_id = data.get("transfer_id")
                chunk_index = data.get("chunk_index")
                if transfer_id and chunk_index is not None:
                    # Also update redis via service logic
                    redis = await get_redis()
                    await acknowledge_chunk_service(transfer_id, chunk_index, redis)
    except WebSocketDisconnect:
        transfer_manager.disconnect(session_id, websocket)
    except Exception:
        transfer_manager.disconnect(session_id, websocket)
