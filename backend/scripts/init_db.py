"""Create the NEXUS AI schema in the configured PostgreSQL database."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import asyncio

from sqlalchemy import text

from app.config import get_settings
from app.db import engine, init_db


async def main() -> None:
    settings = get_settings()
    if settings.async_database_url.startswith("sqlite"):
        print("Refusing to initialise production schema on SQLite.")
        raise SystemExit(2)
    await init_db()
    async with engine.connect() as connection:
        tables = (await connection.execute(text(
            "select tablename from pg_tables where schemaname='public' order by tablename"
        ))).scalars().all()
    await engine.dispose()
    print("schema ready:", ", ".join(tables) or "(no tables)")


if __name__ == "__main__":
    asyncio.run(main())
