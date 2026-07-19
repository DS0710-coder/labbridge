from typing import List, Optional
from pydantic import BaseModel, Field


class TransferInitRequest(BaseModel):
    session_id: str
    filename: str
    size: int
    total_chunks: int
    mime_type: str


class TransferInitResponse(BaseModel):
    transfer_id: str


class UploadChunkRequest(BaseModel):
    chunk_index: int
    encrypted_data: str = Field(..., description="Base64 encoded AES-256-GCM encrypted chunk")


class UploadChunkResponse(BaseModel):
    message: str
    chunk_index: int


class TransferStatusResponse(BaseModel):
    transfer_id: str
    filename: str
    size: int
    total_chunks: int
    received_chunks: List[int]
    status: str  # in_progress | completed | cancelled | failed


class TransferCancelResponse(BaseModel):
    message: str
    transfer_id: str
