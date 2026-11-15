from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Float, Integer, JSON, String, Text, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

from config import Settings


class Base(DeclarativeBase):
    pass


class AnalysisRecord(Base):
    __tablename__ = "analysis_records"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    market: Mapped[str] = mapped_column(String(24), index=True)
    asset_key: Mapped[str] = mapped_column(String(80), index=True)
    asset: Mapped[str] = mapped_column(String(160))
    direction: Mapped[str] = mapped_column(String(16), index=True)
    confidence: Mapped[float] = mapped_column(Float, default=0.0)
    duration_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    entry_price: Mapped[float | None] = mapped_column(Float, nullable=True)
    source: Mapped[str | None] = mapped_column(String(80), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="READY")
    result: Mapped[str] = mapped_column(String(16), default="OPEN")
    exit_price: Mapped[float | None] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    payload: Mapped[dict] = mapped_column(JSON, default=dict)
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)


class HistoryStore:
    def __init__(self, settings: Settings) -> None:
        self.engine = create_async_engine(settings.async_database_url, pool_pre_ping=True)
        self.session_factory = async_sessionmaker(self.engine, expire_on_commit=False)

    async def init(self) -> None:
        async with self.engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

    async def close(self) -> None:
        await self.engine.dispose()

    async def save(self, record: AnalysisRecord) -> AnalysisRecord:
        async with self.session_factory() as session:
            session.add(record)
            await session.commit()
            await session.refresh(record)
            return record

    async def list(self, limit: int = 50) -> list[AnalysisRecord]:
        async with self.session_factory() as session:
            result = await session.execute(
                select(AnalysisRecord).order_by(AnalysisRecord.created_at.desc()).limit(limit)
            )
            return list(result.scalars())

    async def get(self, record_id: int) -> AnalysisRecord | None:
        async with self.session_factory() as session:
            return await session.get(AnalysisRecord, record_id)

    async def open_expired(self, now: datetime) -> list[AnalysisRecord]:
        async with self.session_factory() as session:
            result = await session.execute(
                select(AnalysisRecord).where(
                    AnalysisRecord.result == "OPEN",
                    AnalysisRecord.expires_at.is_not(None),
                    AnalysisRecord.expires_at <= now,
                )
            )
            return list(result.scalars())

    async def resolve(self, record_id: int, result: str, exit_price: float | None, now: datetime) -> None:
        async with self.session_factory() as session:
            record = await session.get(AnalysisRecord, record_id)
            if record is None:
                return
            record.result = result
            record.exit_price = exit_price
            record.resolved_at = now
            await session.commit()

    async def statistics(self) -> dict:
        async with self.session_factory() as session:
            rows = list((await session.execute(select(AnalysisRecord))).scalars())
        completed = [r for r in rows if r.result in {"WIN", "LOSS", "DRAW"}]
        wins = sum(1 for r in completed if r.result == "WIN")
        losses = sum(1 for r in completed if r.result == "LOSS")
        draws = sum(1 for r in completed if r.result == "DRAW")
        return {
            "total": len(rows),
            "completed": len(completed),
            "wins": wins,
            "losses": losses,
            "draws": draws,
            "open": sum(1 for r in rows if r.result == "OPEN"),
            "unverified": sum(1 for r in rows if r.result == "UNVERIFIED"),
            "verified": len(completed),
            "win_rate": round(wins / len(completed) * 100, 1) if completed else None,
        }
