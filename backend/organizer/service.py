import uuid
from typing import List
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from auth.models import User
from organizer.models import Folder, FileItem, utc_now
from organizer.schemas import FolderCreateRequest, FolderUpdateRequest, FileCreateRequest


async def list_folders_service(user: User, db: AsyncSession) -> List[Folder]:
    result = await db.execute(
        select(Folder)
        .where(Folder.user_id == user.id)
        .order_by(Folder.pinned.desc(), Folder.name.asc())
    )
    return result.scalars().all()


async def create_folder_service(user: User, request: FolderCreateRequest, db: AsyncSession) -> Folder:
    if request.parent_id:
        parent_res = await db.execute(
            select(Folder).where(Folder.id == request.parent_id, Folder.user_id == user.id)
        )
        if not parent_res.scalar_one_or_none():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Parent folder not found")

    folder = Folder(
        id=str(uuid.uuid4()),
        user_id=user.id,
        name=request.name,
        parent_id=request.parent_id,
        color=request.color or "#6C63FF",
        pinned=False,
        created_at=utc_now(),
    )
    db.add(folder)
    await db.commit()
    await db.refresh(folder)
    return folder


async def update_folder_service(user: User, folder_id: str, request: FolderUpdateRequest, db: AsyncSession) -> Folder:
    result = await db.execute(
        select(Folder).where(Folder.id == folder_id, Folder.user_id == user.id)
    )
    folder = result.scalar_one_or_none()
    if not folder:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Folder not found")

    if request.name is not None:
        folder.name = request.name
    if request.color is not None:
        folder.color = request.color
    if request.pinned is not None:
        folder.pinned = request.pinned
    if request.parent_id is not None:
        folder.parent_id = request.parent_id

    await db.commit()
    await db.refresh(folder)
    return folder


async def delete_folder_service(user: User, folder_id: str, db: AsyncSession) -> dict:
    result = await db.execute(
        select(Folder).where(Folder.id == folder_id, Folder.user_id == user.id)
    )
    folder = result.scalar_one_or_none()
    if not folder:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Folder not found")

    await db.delete(folder)
    await db.commit()
    return {"message": "Folder deleted successfully"}


async def list_files_service(user: User, db: AsyncSession) -> List[FileItem]:
    result = await db.execute(
        select(FileItem)
        .where(FileItem.user_id == user.id)
        .order_by(FileItem.transferred_at.desc())
    )
    return result.scalars().all()


async def create_file_service(user: User, request: FileCreateRequest, db: AsyncSession) -> FileItem:
    if request.folder_id:
        folder_res = await db.execute(
            select(Folder).where(Folder.id == request.folder_id, Folder.user_id == user.id)
        )
        if not folder_res.scalar_one_or_none():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Destination folder not found")

    file_item = FileItem(
        id=str(uuid.uuid4()),
        user_id=user.id,
        folder_id=request.folder_id,
        name=request.name,
        size=request.size,
        mime_type=request.mime_type,
        transferred_at=utc_now(),
        device_name=request.device_name,
        tags=request.tags or "",
    )
    db.add(file_item)
    await db.commit()
    await db.refresh(file_item)
    return file_item
