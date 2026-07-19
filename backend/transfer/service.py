import json
import uuid
from typing import List
from fastapi import HTTPException, status
from redis.asyncio import Redis

from transfer.schemas import (
    TransferInitRequest,
    TransferInitResponse,
    UploadChunkRequest,
    UploadChunkResponse,
    TransferStatusResponse,
    TransferCancelResponse,
)
from transfer.websocket import transfer_manager


async def init_transfer_service(request: TransferInitRequest, redis_client: Redis) -> TransferInitResponse:
    raw_session = await redis_client.get(f"session:{request.session_id}")
    if not raw_session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pairing session expired or not found",
        )

    transfer_id = str(uuid.uuid4())
    transfer_data = {
        "transfer_id": transfer_id,
        "session_id": request.session_id,
        "filename": request.filename,
        "size": request.size,
        "total_chunks": request.total_chunks,
        "received_chunks": [],
        "status": "in_progress",
        "mime_type": request.mime_type,
    }

    # Store transfer metadata in Redis with 15 minute TTL
    await redis_client.set(f"transfer:{transfer_id}", json.dumps(transfer_data), ex=900)
    await redis_client.set(f"transfer_session:{request.session_id}", transfer_id, ex=900)

    # Notify WebSocket channels that transfer has started
    await transfer_manager.broadcast_event(
        request.session_id,
        {
            "event": "init",
            "transfer_id": transfer_id,
            "filename": request.filename,
            "size": request.size,
            "total_chunks": request.total_chunks,
            "mime_type": request.mime_type,
        },
    )

    return TransferInitResponse(transfer_id=transfer_id)


async def upload_chunk_service(
    transfer_id: str, request: UploadChunkRequest, redis_client: Redis
) -> UploadChunkResponse:
    raw_transfer = await redis_client.get(f"transfer:{transfer_id}")
    if not raw_transfer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transfer session expired or not found",
        )

    data = json.loads(raw_transfer)
    if data["status"] != "in_progress":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Transfer is already {data['status']}",
        )

    # Relay the encrypted chunk directly over WebSocket without writing to disk or DB
    relay_frame = {
        "event": "chunk",
        "transfer_id": transfer_id,
        "chunk_index": request.chunk_index,
        "encrypted_data": request.encrypted_data,
        "filename": data["filename"],
        "total_chunks": data["total_chunks"],
    }
    await transfer_manager.broadcast_event(data["session_id"], relay_frame)

    # Note: request.encrypted_data and relay_frame go out of scope here immediately upon return.
    # No file bytes are retained in server memory or written to disk.
    return UploadChunkResponse(message="Chunk relayed", chunk_index=request.chunk_index)


async def acknowledge_chunk_service(
    transfer_id: str, chunk_index: int, redis_client: Redis
) -> dict:
    raw_transfer = await redis_client.get(f"transfer:{transfer_id}")
    if not raw_transfer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transfer session not found",
        )

    data = json.loads(raw_transfer)
    if chunk_index not in data["received_chunks"]:
        data["received_chunks"].append(chunk_index)

    completed = len(data["received_chunks"]) >= data["total_chunks"]
    if completed:
        data["status"] = "completed"
        await redis_client.set(f"transfer:{transfer_id}", json.dumps(data), ex=900)
        await transfer_manager.broadcast_event(
            data["session_id"],
            {"event": "completed", "transfer_id": transfer_id, "filename": data["filename"]},
        )
    else:
        await redis_client.set(f"transfer:{transfer_id}", json.dumps(data), ex=900)
        await transfer_manager.broadcast_event(
            data["session_id"],
            {"event": "ack", "transfer_id": transfer_id, "chunk_index": chunk_index},
        )

    return {"status": data["status"], "received_chunks_count": len(data["received_chunks"])}


async def get_transfer_status_service(transfer_id: str, redis_client: Redis) -> TransferStatusResponse:
    raw_transfer = await redis_client.get(f"transfer:{transfer_id}")
    if not raw_transfer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transfer session not found",
        )

    data = json.loads(raw_transfer)
    return TransferStatusResponse(
        transfer_id=data["transfer_id"],
        filename=data["filename"],
        size=data["size"],
        total_chunks=data["total_chunks"],
        received_chunks=data["received_chunks"],
        status=data["status"],
    )


async def cancel_transfer_service(transfer_id: str, redis_client: Redis) -> TransferCancelResponse:
    raw_transfer = await redis_client.get(f"transfer:{transfer_id}")
    if not raw_transfer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transfer session not found",
        )

    data = json.loads(raw_transfer)
    data["status"] = "cancelled"
    await redis_client.set(f"transfer:{transfer_id}", json.dumps(data), ex=60)
    await transfer_manager.broadcast_event(
        data["session_id"], {"event": "cancelled", "transfer_id": transfer_id}
    )

    return TransferCancelResponse(message="Transfer cancelled", transfer_id=transfer_id)
