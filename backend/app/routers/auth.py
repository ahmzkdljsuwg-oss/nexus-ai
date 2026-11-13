"""Registration, login, logout and session management."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.config import get_settings
from app.deps import CurrentSession, CurrentUser, DbSession
from app.models import Session, User
from app.schemas import LoginIn, RegisterIn, SessionOut, TokenOut, UserOut
from app.security import create_access_token, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


async def _start_session(db, user: User, device: str) -> TokenOut:
    session = Session(
        user_id=user.id,
        device=(device or "iPhone")[:120],
        expires_at=datetime.now(timezone.utc)
        + timedelta(minutes=get_settings().access_token_minutes),
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)
    token, expires_at = create_access_token(user.id, session.id)
    session.expires_at = expires_at
    await db.commit()
    return TokenOut(access_token=token, expires_at=expires_at, user=UserOut.model_validate(user))


@router.post("/register", response_model=TokenOut, status_code=status.HTTP_201_CREATED)
async def register(payload: RegisterIn, db: DbSession) -> TokenOut:
    if not get_settings().allow_registration:
        raise HTTPException(status_code=403, detail="Registration is disabled")
    email = payload.email.strip().lower()
    existing = await db.scalar(select(User).where(User.email == email))
    if existing is not None:
        raise HTTPException(status_code=409, detail="An account with this email already exists")
    user = User(
        email=email,
        name=payload.name.strip(),
        password_hash=hash_password(payload.password),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return await _start_session(db, user, "iPhone")


@router.post("/login", response_model=TokenOut)
async def login(payload: LoginIn, db: DbSession) -> TokenOut:
    email = payload.email.strip().lower()
    user = await db.scalar(select(User).where(User.email == email))
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Incorrect email or password")
    return await _start_session(db, user, payload.device)


@router.post("/logout", status_code=204, response_model=None)
async def logout(session: CurrentSession, db: DbSession) -> None:
    session.revoked_at = datetime.now(timezone.utc)
    await db.commit()


@router.get("/me", response_model=UserOut)
async def me(user: CurrentUser) -> UserOut:
    return UserOut.model_validate(user)


@router.get("/sessions", response_model=list[SessionOut])
async def sessions(user: CurrentUser, session: CurrentSession, db: DbSession) -> list[SessionOut]:
    rows = (
        await db.scalars(
            select(Session)
            .where(Session.user_id == user.id, Session.revoked_at.is_(None))
            .order_by(Session.last_seen_at.desc())
        )
    ).all()
    return [
        SessionOut(
            id=row.id,
            device=row.device,
            created_at=row.created_at,
            last_seen_at=row.last_seen_at,
            expires_at=row.expires_at,
            current=row.id == session.id,
        )
        for row in rows
    ]


@router.delete("/sessions/{session_id}", status_code=204, response_model=None)
async def revoke_session(session_id: str, user: CurrentUser, session: CurrentSession, db: DbSession) -> None:
    target = await db.get(Session, session_id)
    if target is None or target.user_id != user.id:
        raise HTTPException(status_code=404, detail="Session not found")
    if target.id == session.id:
        raise HTTPException(status_code=400, detail="Use logout for the current session")
    target.revoked_at = datetime.now(timezone.utc)
    await db.commit()
