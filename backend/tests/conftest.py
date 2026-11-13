from __future__ import annotations

import os
from pathlib import Path
from uuid import uuid4

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

TEST_DB = Path(f"/tmp/nexus-test-{uuid4().hex}.db")
os.environ["DATABASE_URL"] = f"sqlite+aiosqlite:///{TEST_DB}"
os.environ["JWT_SECRET"] = "test-secret-key-that-is-long-enough"
os.environ["ENVIRONMENT"] = "test"
os.environ["GEMINI_API_KEY"] = ""

from app.db import SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.models import Base  # noqa: E402
from app.services.gemini import GeminiClient  # noqa: E402
from app.config import get_settings  # noqa: E402


@pytest_asyncio.fixture(scope="session", autouse=True)
async def database():
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    app.state.gemini = GeminiClient(get_settings())
    yield
    await engine.dispose()
    TEST_DB.unlink(missing_ok=True)


@pytest_asyncio.fixture(autouse=True)
async def clean_tables(database):
    from sqlalchemy import delete
    from app.models import Chat, FileEntry, Message, Project, Session, User

    async with SessionLocal() as session:
        for model in (Message, Chat, FileEntry, Project, Session, User):
            await session.execute(delete(model))
        await session.commit()
    app.state.gemini = GeminiClient(get_settings())
    yield


@pytest_asyncio.fixture
async def client():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http:
        yield http


async def register(client: AsyncClient, email: str = "a@nexus.ai", password: str = "strong-pass-1") -> dict:
    response = await client.post(
        "/api/auth/register",
        json={"email": email, "name": "Test User", "password": password},
    )
    assert response.status_code == 201, response.text
    return response.json()


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def user_a(client):
    data = await register(client, "a@nexus.ai")
    return {"token": data["access_token"], "user": data["user"]}
