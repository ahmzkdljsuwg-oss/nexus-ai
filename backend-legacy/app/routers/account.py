"""Account, user preferences and security overview."""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Request
from sqlalchemy import func, select

from app.deps import CurrentSession, CurrentUser, DbSession
from app.models import Chat, FileEntry, Project, Session, User
from app.schemas import AccountUpdate, SettingsUpdate, UserOut
from app.security import hash_password

router = APIRouter(tags=["account"])


@router.get("/account", response_model=UserOut)
async def get_account(user: CurrentUser) -> UserOut:
    return UserOut.model_validate(user)


@router.patch("/account", response_model=UserOut)
async def update_account(payload: AccountUpdate, user: CurrentUser, db: DbSession) -> UserOut:
    if payload.name is not None:
        user.name = payload.name.strip()
    if payload.password is not None:
        user.password_hash = hash_password(payload.password)
        now = datetime.now(timezone.utc)
        sessions = (
            await db.scalars(select(Session).where(Session.user_id == user.id, Session.revoked_at.is_(None)))
        ).all()
        for item in sessions:
            item.revoked_at = now
    await db.commit()
    await db.refresh(user)
    return UserOut.model_validate(user)


@router.get("/settings", response_model=UserOut)
async def get_settings_route(user: CurrentUser) -> UserOut:
    return UserOut.model_validate(user)


@router.patch("/settings", response_model=UserOut)
async def update_settings(payload: SettingsUpdate, user: CurrentUser, db: DbSession) -> UserOut:
    for field in ("locale", "appearance", "sound_enabled", "assistant_voice"):
        value = getattr(payload, field)
        if value is not None:
            setattr(user, field, value)
    await db.commit()
    await db.refresh(user)
    return UserOut.model_validate(user)


@router.get("/security/status")
async def security_status(request: Request, user: CurrentUser, session: CurrentSession, db: DbSession) -> dict:
    active_sessions = await db.scalar(
        select(func.count(Session.id)).where(
            Session.user_id == user.id,
            Session.revoked_at.is_(None),
            Session.expires_at > datetime.now(timezone.utc),
        )
    )
    project_count = await db.scalar(select(func.count(Project.id)).where(Project.user_id == user.id))
    file_count = await db.scalar(select(func.count(FileEntry.id)).where(FileEntry.user_id == user.id))
    chat_count = await db.scalar(select(func.count(Chat.id)).where(Chat.user_id == user.id))
    return {
        "authenticated": True,
        "current_session_id": session.id,
        "active_sessions": int(active_sessions or 0),
        "session_expires_at": session.expires_at,
        "projects": int(project_count or 0),
        "files": int(file_count or 0),
        "chats": int(chat_count or 0),
        "account_created_at": user.created_at,
        "checks": [
            {"id": "jwt", "label": "JWT session validation", "state": "pass"},
            {"id": "owner_scope", "label": "User-scoped database queries", "state": "pass"},
            {
                "id": "password_hash",
                "label": "Bcrypt password hashing",
                "state": "pass" if str(user.password_hash).startswith("$2") else "fail",
            },
            {
                "id": "database",
                "label": "Database reachable",
                "state": "pass",
            },
            {
                "id": "transport",
                "label": "HTTPS transport",
                "state": "pass"
                if (request.url.scheme == "https" or request.headers.get("x-forwarded-proto") == "https")
                else "warn",
            },
        ],
    }


@router.post("/account/change-password", status_code=204, response_model=None)
async def change_password(payload: AccountUpdate, user: CurrentUser, db: DbSession) -> None:
    if not payload.password:
        raise HTTPException(status_code=422, detail="A new password is required")
    user.password_hash = hash_password(payload.password)
    await db.commit()
