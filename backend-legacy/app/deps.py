"""Authentication dependencies shared by protected routes."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Annotated

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_session
from app.models import Session, User
from app.security import decode_access_token

bearer = HTTPBearer(auto_error=False)
DbSession = Annotated[AsyncSession, Depends(get_session)]
Credentials = Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]


def _aware(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


async def current_session(credentials: Credentials, db: DbSession) -> Session:
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired session",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise unauthorized
    try:
        payload = decode_access_token(credentials.credentials)
        user_id = str(payload.get("sub") or "")
        session_id = str(payload.get("sid") or "")
    except jwt.PyJWTError as exc:
        raise unauthorized from exc
    session = await db.get(Session, session_id)
    if session is None or session.user_id != user_id or session.revoked_at is not None:
        raise unauthorized
    if _aware(session.expires_at) <= datetime.now(timezone.utc):
        raise unauthorized
    session.last_seen_at = datetime.now(timezone.utc)
    await db.commit()
    return session


async def current_user(session: Annotated[Session, Depends(current_session)], db: DbSession) -> User:
    user = await db.get(User, session.user_id)
    if user is None:
        raise HTTPException(status_code=401, detail="User no longer exists")
    return user


CurrentUser = Annotated[User, Depends(current_user)]
CurrentSession = Annotated[Session, Depends(current_session)]


async def owned_project(db: AsyncSession, user_id: str, project_id: str):
    from app.models import Project

    project = await db.get(Project, project_id)
    if project is None or project.user_id != user_id:
        raise HTTPException(status_code=404, detail="Project not found")
    return project
