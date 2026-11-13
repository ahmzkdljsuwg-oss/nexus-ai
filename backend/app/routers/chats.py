"""Conversation storage, always scoped to the authenticated owner."""
from __future__ import annotations

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import func, select

from app.deps import CurrentUser, DbSession, owned_project
from app.models import Chat, Message
from app.schemas import ChatDetail, ChatIn, ChatOut, ChatUpdate, MessageOut

router = APIRouter(prefix="/chats", tags=["chats"])


async def owned_chat(db, user_id: str, chat_id: str) -> Chat:
    chat = await db.get(Chat, chat_id)
    if chat is None or chat.user_id != user_id:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return chat


async def _serialise(db, chat: Chat) -> ChatOut:
    count = await db.scalar(select(func.count(Message.id)).where(Message.chat_id == chat.id))
    last = await db.scalar(
        select(Message.content).where(Message.chat_id == chat.id).order_by(Message.created_at.desc()).limit(1)
    )
    return ChatOut(
        id=chat.id,
        project_id=chat.project_id,
        title=chat.title,
        created_at=chat.created_at,
        updated_at=chat.updated_at,
        message_count=int(count or 0),
        last_message=(last or "")[:200],
    )


@router.get("", response_model=list[ChatOut])
async def list_chats(user: CurrentUser, db: DbSession, project_id: str | None = None) -> list[ChatOut]:
    query = select(Chat).where(Chat.user_id == user.id)
    if project_id:
        await owned_project(db, user.id, project_id)
        query = query.where(Chat.project_id == project_id)
    rows = (await db.scalars(query.order_by(Chat.updated_at.desc()))).all()
    return [await _serialise(db, row) for row in rows]


@router.post("", response_model=ChatOut, status_code=status.HTTP_201_CREATED)
async def create_chat(payload: ChatIn, user: CurrentUser, db: DbSession) -> ChatOut:
    if payload.project_id:
        await owned_project(db, user.id, payload.project_id)
    chat = Chat(user_id=user.id, project_id=payload.project_id, title=payload.title.strip() or "New conversation")
    db.add(chat)
    await db.commit()
    await db.refresh(chat)
    return await _serialise(db, chat)


@router.get("/{chat_id}", response_model=ChatDetail)
async def get_chat(chat_id: str, user: CurrentUser, db: DbSession) -> ChatDetail:
    chat = await owned_chat(db, user.id, chat_id)
    base = await _serialise(db, chat)
    messages = (
        await db.scalars(select(Message).where(Message.chat_id == chat.id).order_by(Message.created_at.asc()))
    ).all()
    return ChatDetail(**base.model_dump(), messages=[MessageOut.model_validate(item) for item in messages])


@router.patch("/{chat_id}", response_model=ChatOut)
async def rename_chat(chat_id: str, payload: ChatUpdate, user: CurrentUser, db: DbSession) -> ChatOut:
    chat = await owned_chat(db, user.id, chat_id)
    chat.title = payload.title.strip()
    await db.commit()
    await db.refresh(chat)
    return await _serialise(db, chat)


@router.delete("/{chat_id}", status_code=204, response_model=None)
async def delete_chat(chat_id: str, user: CurrentUser, db: DbSession) -> None:
    chat = await owned_chat(db, user.id, chat_id)
    messages = (await db.scalars(select(Message).where(Message.chat_id == chat.id))).all()
    for item in messages:
        await db.delete(item)
    await db.delete(chat)
    await db.commit()
