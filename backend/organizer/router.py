from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core.database import get_db
from core.security import get_current_user
from auth.models import User
from organizer.schemas import (
    FolderCreateRequest,
    FolderUpdateRequest,
    FolderResponse,
    FileCreateRequest,
    FileResponse,
)
from organizer.service import (
    list_folders_service,
    create_folder_service,
    update_folder_service,
    delete_folder_service,
    list_files_service,
    create_file_service,
)

router = APIRouter(prefix="/api/folders", tags=["organizer"])
files_router = APIRouter(prefix="/api/files", tags=["organizer-files"])


@router.get("", response_model=List[FolderResponse])
async def get_folders(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await list_folders_service(current_user, db)


@router.post("", response_model=FolderResponse)
async def create_folder(
    request: FolderCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await create_folder_service(current_user, request, db)


@router.patch("/{id}", response_model=FolderResponse)
async def update_folder(
    id: str,
    request: FolderUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await update_folder_service(current_user, id, request, db)


@router.delete("/{id}")
async def delete_folder(
    id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await delete_folder_service(current_user, id, db)


@files_router.get("", response_model=List[FileResponse])
async def get_files(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await list_files_service(current_user, db)


@files_router.post("", response_model=FileResponse)
async def create_file(
    request: FileCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await create_file_service(current_user, request, db)
