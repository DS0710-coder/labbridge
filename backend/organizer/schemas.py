from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field, ConfigDict


class FolderCreateRequest(BaseModel):
    name: str = Field(..., max_length=100)
    parent_id: Optional[str] = None
    color: Optional[str] = "#6C63FF"


class FolderUpdateRequest(BaseModel):
    name: Optional[str] = None
    color: Optional[str] = None
    pinned: Optional[bool] = None
    parent_id: Optional[str] = None


class FolderResponse(BaseModel):
    id: str
    user_id: str
    name: str
    parent_id: Optional[str]
    color: str
    pinned: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class FileCreateRequest(BaseModel):
    name: str
    size: int
    mime_type: Optional[str] = "application/octet-stream"
    folder_id: Optional[str] = None
    device_name: Optional[str] = "Android Device"
    tags: Optional[str] = ""


class FileResponse(BaseModel):
    id: str
    user_id: str
    folder_id: Optional[str]
    name: str
    size: int
    mime_type: Optional[str]
    transferred_at: datetime
    device_name: Optional[str]
    tags: str

    model_config = ConfigDict(from_attributes=True)
