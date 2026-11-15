"""Smart Files: virtual, owner-scoped text files and folders."""
from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.config import get_settings
from app.deps import CurrentUser, DbSession, owned_project
from app.models import FileEntry
from app.schemas import FileIn, FileOut, FileUpdate
from app.services.files import is_descendant, normalize_path

router = APIRouter(prefix="/files", tags=["files"])


async def _owned_file(db, user_id: str, file_id: str) -> FileEntry:
    entry = await db.get(FileEntry, file_id)
    if entry is None or entry.user_id != user_id:
        raise HTTPException(status_code=404, detail="File not found")
    return entry


@router.get("", response_model=list[FileOut])
async def list_files(
    user: CurrentUser,
    db: DbSession,
    project_id: str | None = Query(default=None),
    parent: str | None = Query(default=None),
) -> list[FileEntry]:
    query = select(FileEntry).where(FileEntry.user_id == user.id)
    if project_id:
        await owned_project(db, user.id, project_id)
        query = query.where(FileEntry.project_id == project_id)
    rows = (await db.scalars(query.order_by(FileEntry.path.asc()))).all()
    if parent is not None:
        prefix = normalize_path(parent, allow_root=True).rstrip("/")
        rows = [row for row in rows if prefix and is_descendant(row.path, prefix)]
    return list(rows)


@router.post("", response_model=FileOut, status_code=status.HTTP_201_CREATED)
async def create_file(payload: FileIn, user: CurrentUser, db: DbSession) -> FileEntry:
    path = normalize_path(payload.path, allow_root=payload.is_folder)
    if payload.project_id:
        await owned_project(db, user.id, payload.project_id)
    if len(payload.content.encode("utf-8")) > get_settings().max_file_bytes:
        raise HTTPException(status_code=413, detail="File is too large")
    duplicate = await db.scalar(select(FileEntry).where(FileEntry.user_id == user.id, FileEntry.path == path))
    if duplicate is not None:
        raise HTTPException(status_code=409, detail="A file or folder already exists at this path")
    entry = FileEntry(
        user_id=user.id,
        project_id=payload.project_id,
        path=path,
        is_folder=payload.is_folder,
        content="" if payload.is_folder else payload.content,
    )
    db.add(entry)
    try:
        await db.commit()
    except IntegrityError as exc:
        await db.rollback()
        raise HTTPException(status_code=409, detail="A file or folder already exists at this path") from exc
    await db.refresh(entry)
    return entry


@router.get("/{file_id}", response_model=FileOut)
async def get_file(file_id: str, user: CurrentUser, db: DbSession) -> FileEntry:
    return await _owned_file(db, user.id, file_id)


@router.patch("/{file_id}", response_model=FileOut)
async def update_file(file_id: str, payload: FileUpdate, user: CurrentUser, db: DbSession) -> FileEntry:
    entry = await _owned_file(db, user.id, file_id)
    if payload.content is not None:
        if entry.is_folder:
            raise HTTPException(status_code=422, detail="A folder cannot have file content")
        if len(payload.content.encode("utf-8")) > get_settings().max_file_bytes:
            raise HTTPException(status_code=413, detail="File is too large")
        entry.content = payload.content
    if payload.path is not None:
        new_path = normalize_path(payload.path, allow_root=entry.is_folder)
        if new_path != entry.path:
            duplicate = await db.scalar(
                select(FileEntry).where(
                    FileEntry.user_id == user.id, FileEntry.path == new_path, FileEntry.id != entry.id
                )
            )
            if duplicate is not None:
                raise HTTPException(status_code=409, detail="A file or folder already exists at this path")
            if entry.is_folder:
                children = (
                    await db.scalars(
                        select(FileEntry).where(
                            FileEntry.user_id == user.id,
                            FileEntry.id != entry.id,
                            FileEntry.path.startswith(entry.path.rstrip("/") + "/"),
                        )
                    )
                ).all()
                for child in children:
                    child.path = new_path.rstrip("/") + child.path[len(entry.path.rstrip("/")) :]
            entry.path = new_path
    await db.commit()
    await db.refresh(entry)
    return entry


@router.delete("/{file_id}", status_code=204, response_model=None)
async def delete_file(file_id: str, user: CurrentUser, db: DbSession) -> None:
    entry = await _owned_file(db, user.id, file_id)
    if entry.is_folder:
        children = (
            await db.scalars(
                select(FileEntry).where(
                    FileEntry.user_id == user.id,
                    FileEntry.path.startswith(entry.path.rstrip("/") + "/"),
                )
            )
        ).all()
        for child in children:
            await db.delete(child)
    await db.delete(entry)
    await db.commit()
