"""Projects with independent memory (description, goals, files, chats)."""
from __future__ import annotations

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import func, select

from app.deps import CurrentUser, DbSession, owned_project
from app.models import Chat, FileEntry, Project
from app.schemas import ProjectIn, ProjectOut, ProjectUpdate

router = APIRouter(prefix="/projects", tags=["projects"])


async def _serialise(db, project: Project) -> ProjectOut:
    file_count = await db.scalar(
        select(func.count(FileEntry.id)).where(
            FileEntry.user_id == project.user_id,
            FileEntry.project_id == project.id,
            FileEntry.is_folder.is_(False),
        )
    )
    chat_count = await db.scalar(
        select(func.count(Chat.id)).where(Chat.user_id == project.user_id, Chat.project_id == project.id)
    )
    data = ProjectOut.model_validate(project)
    return data.model_copy(update={"file_count": int(file_count or 0), "chat_count": int(chat_count or 0)})


@router.get("", response_model=list[ProjectOut])
async def list_projects(user: CurrentUser, db: DbSession) -> list[ProjectOut]:
    rows = (
        await db.scalars(
            select(Project).where(Project.user_id == user.id).order_by(Project.updated_at.desc())
        )
    ).all()
    return [await _serialise(db, row) for row in rows]


@router.post("", response_model=ProjectOut, status_code=status.HTTP_201_CREATED)
async def create_project(payload: ProjectIn, user: CurrentUser, db: DbSession) -> ProjectOut:
    name = payload.name.strip()
    duplicate = await db.scalar(select(Project).where(Project.user_id == user.id, Project.name == name))
    if duplicate is not None:
        raise HTTPException(status_code=409, detail="A project with this name already exists")
    project = Project(user_id=user.id, name=name, description=payload.description, goals=payload.goals)
    db.add(project)
    await db.commit()
    await db.refresh(project)
    return await _serialise(db, project)


@router.get("/{project_id}", response_model=ProjectOut)
async def get_project(project_id: str, user: CurrentUser, db: DbSession) -> ProjectOut:
    return await _serialise(db, await owned_project(db, user.id, project_id))


@router.patch("/{project_id}", response_model=ProjectOut)
async def update_project(project_id: str, payload: ProjectUpdate, user: CurrentUser, db: DbSession) -> ProjectOut:
    project = await owned_project(db, user.id, project_id)
    if payload.name is not None:
        name = payload.name.strip()
        duplicate = await db.scalar(
            select(Project).where(Project.user_id == user.id, Project.name == name, Project.id != project.id)
        )
        if duplicate is not None:
            raise HTTPException(status_code=409, detail="A project with this name already exists")
        project.name = name
    if payload.description is not None:
        project.description = payload.description
    if payload.goals is not None:
        project.goals = payload.goals
    await db.commit()
    await db.refresh(project)
    return await _serialise(db, project)


@router.delete("/{project_id}", status_code=204, response_model=None)
async def delete_project(project_id: str, user: CurrentUser, db: DbSession) -> None:
    project = await owned_project(db, user.id, project_id)
    files = (await db.scalars(select(FileEntry).where(FileEntry.project_id == project.id))).all()
    chats = (await db.scalars(select(Chat).where(Chat.project_id == project.id))).all()
    for item in files:
        item.project_id = None
    for item in chats:
        item.project_id = None
    await db.delete(project)
    await db.commit()
