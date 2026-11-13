"""NEXUS AI backend: FastAPI application entry point."""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.config import get_settings
from app.db import SessionLocal, close_db, init_db
from app.routers import account, assistant, auth, chats, files, projects, tools
from app.schemas import HealthOut
from app.services.gemini import GeminiClient

VERSION = "1.0.0"
settings = get_settings()
logging.basicConfig(
    level=getattr(logging, settings.log_level.upper(), logging.INFO),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
log = logging.getLogger("nexus")


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings.runtime_secret()
    await init_db()
    app.state.gemini = GeminiClient(settings)
    log.info("NEXUS AI backend %s ready (gemini=%s)", VERSION, settings.gemini_configured)
    yield
    await close_db()


app = FastAPI(
    title="NEXUS AI API",
    version=VERSION,
    docs_url="/api/docs",
    openapi_url="/api/openapi.json",
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

for router in (auth.router, account.router, projects.router, files.router, chats.router, assistant.router, tools.router):
    app.include_router(router, prefix="/api")


@app.get("/", include_in_schema=False)
async def root() -> dict:
    return {"service": "NEXUS AI", "version": VERSION, "docs": "/api/docs"}


@app.get("/api/health", response_model=HealthOut)
async def health() -> HealthOut:
    database = "ok"
    try:
        async with SessionLocal() as session:
            await session.execute(text("SELECT 1"))
    except Exception:
        database = "unavailable"
    return HealthOut(
        status="ok" if database == "ok" else "degraded",
        service="NEXUS AI",
        version=VERSION,
        database=database,
        gemini_configured=settings.gemini_configured,
        gemini_model=settings.gemini_model,
        time=datetime.now(timezone.utc),
    )
