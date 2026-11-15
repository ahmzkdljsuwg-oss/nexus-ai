from __future__ import annotations

import asyncio
import logging
import math
import os
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.ai_clients import AIUnavailable, GeminiClient, MistralClient
from app.db import AnalysisRecord, HistoryStore
from app.market_service import MARKET_BY_KEY, TradingService, market_key
from app.schemas import AnalyseRequest, ChatRequest
from config import Settings, settings as default_settings

LOG = logging.getLogger("nexus")
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO").upper(), format="%(asctime)s %(levelname)s %(name)s %(message)s")
# HTTP client request lines can include API keys in query strings; keep them out of logs.
for noisy in ("httpx", "httpcore"):
    logging.getLogger(noisy).setLevel(logging.WARNING)


def _record_row(record: AnalysisRecord) -> dict:
    payload = record.payload or {}
    return {
        "id": record.id,
        "market": record.market,
        "asset_key": record.asset_key,
        "asset": record.asset,
        "direction": record.direction,
        "signal_ar": "شراء" if record.direction == "UP" else "بيع" if record.direction == "DOWN" else "لا توجد فرصة",
        "confidence": round(record.confidence, 1) if record.confidence else None,
        "evidence_score": payload.get("evidence_score"),
        "duration": record.duration_seconds,
        "duration_label": payload.get("duration_label", "—"),
        "duration_mode": payload.get("duration_mode"),
        "reasons": payload.get("reasons", []),
        "no_trade_reason": payload.get("no_trade_reason"),
        "entry_price": record.entry_price,
        "entry_price_display": payload.get("entry", {}).get("price_display"),
        "source": record.source,
        "status": record.status,
        "result": record.result,
        "exit_price": record.exit_price,
        "exit_price_display": "—" if record.exit_price is None else f"{record.exit_price}",
        "created_at": record.created_at.isoformat() if record.created_at else None,
        "expires_at": record.expires_at.isoformat() if record.expires_at else None,
        "resolved_at": record.resolved_at.isoformat() if record.resolved_at else None,
        "summary": record.summary,
        "payload": payload,
    }


def create_app(settings: Settings = default_settings) -> FastAPI:
    store = HistoryStore(settings)
    gemini = GeminiClient(settings.gemini_api_key, settings.gemini_model)
    mistral = MistralClient(settings.mistral_api_key, settings.mistral_model)
    service = TradingService(settings, gemini, mistral, store)
    scanner_enabled = os.getenv("SCANNER_ENABLED", "true").lower() in {"1", "true", "yes", "on"}
    stop = asyncio.Event()

    async def scanner_loop() -> None:
        await asyncio.sleep(15)
        while not stop.is_set():
            for item in MARKET_BY_KEY.values():
                if stop.is_set():
                    return
                try:
                    assets = await service.assets(item["key"])
                    if not assets:
                        continue
                    await service.analyse(item["key"], None, "auto", None)
                    LOG.info("scan completed for %s", item["key"])
                except Exception as exc:  # noqa: BLE001
                    LOG.info("scan skipped for %s: %s", item["key"], exc)
                await asyncio.sleep(5)
            try:
                await asyncio.wait_for(stop.wait(), timeout=180)
            except asyncio.TimeoutError:
                pass

    async def verification_loop() -> None:
        while not stop.is_set():
            try:
                count = await service.verify_due()
                if count:
                    LOG.info("verified %d expired recommendations", count)
            except Exception:  # noqa: BLE001
                LOG.exception("verification loop failed")
            try:
                await asyncio.wait_for(stop.wait(), timeout=20)
            except asyncio.TimeoutError:
                pass

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        await store.init()
        LOG.info("NEXUS AI backend started: %s", settings.describe())
        tasks = [asyncio.create_task(verification_loop())]
        if scanner_enabled:
            tasks.append(asyncio.create_task(scanner_loop()))
        try:
            yield
        finally:
            stop.set()
            for task in tasks:
                task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)
            await service.close()
            await store.close()

    app = FastAPI(title="NEXUS AI", version="1.0.0", lifespan=lifespan)
    origins = [value.strip() for value in settings.cors_origins.split(",") if value.strip()]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins or ["*"],
        allow_credentials=False,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["Content-Type", "Accept"],
    )
    app.state.service = service
    app.state.store = store

    rate_buckets: dict[tuple[str, str], float] = {}

    @app.middleware("http")
    async def throttle_paid_routes(request: Request, call_next):
        interval = settings.request_min_interval
        if interval > 0 and request.method == "POST" and request.url.path in {"/api/analyse", "/api/chat"}:
            client = request.client.host if request.client else "unknown"
            key = (client, request.url.path)
            now = time.monotonic()
            last = rate_buckets.get(key)
            if last is not None and now - last < interval:
                wait = max(1, math.ceil(interval - (now - last)))
                return JSONResponse(
                    status_code=429,
                    headers={"Retry-After": str(wait)},
                    content={
                        "detail": {
                            "code": "RATE_LIMITED",
                            "message": f"Too many requests. Retry in {wait} second(s).",
                        }
                    },
                )
            rate_buckets[key] = now
            if len(rate_buckets) > 5000:
                cutoff = now - interval
                for bucket, seen in list(rate_buckets.items()):
                    if seen < cutoff:
                        rate_buckets.pop(bucket, None)
        return await call_next(request)

    @app.get("/")
    async def root():
        return {"service": "NEXUS AI", "docs": "/docs", "health": "/api/health"}

    @app.get("/api/health")
    async def health():
        database = "down"
        try:
            async with store.session_factory() as session:
                await session.execute(text("SELECT 1"))
            database = "postgresql" if "postgresql" in settings.async_database_url else "sqlite"
        except Exception:  # noqa: BLE001
            LOG.exception("database health check failed")
        return {
            "status": "ok" if database != "down" else "degraded",
            "service": "NEXUS AI",
            "version": "1.0.0",
            "database": database,
            "ai": {
                "gemini": {"configured": gemini.configured, "model": gemini.model, "status": "unprobed"},
                "mistral": {"configured": mistral.configured, "model": mistral.model, "status": "unprobed"},
            },
            "markets": [item["key"] for item in MARKET_BY_KEY.values()],
            "secret_exposure": False,
            "time": datetime.now(timezone.utc).isoformat(),
        }

    @app.get("/api/markets")
    async def markets():
        return await service.overview()

    @app.get("/api/markets/{key}")
    async def market(key: str, asset: str | None = None):
        normalised = market_key(key)
        if normalised is None:
            raise HTTPException(status_code=404, detail={"code": "MARKET_UNKNOWN", "message": "Unknown market"})
        try:
            return await service.snapshot(normalised, asset_key=asset)
        except Exception as exc:  # noqa: BLE001
            LOG.exception("market snapshot failed")
            raise HTTPException(
                status_code=503,
                detail={"code": "DATA_UNAVAILABLE", "message": f"DATA UNAVAILABLE — {exc}"},
            ) from exc

    @app.post("/api/analyse")
    async def analyse(body: AnalyseRequest):
        normalised = market_key(body.market)
        if normalised is None:
            raise HTTPException(status_code=404, detail={"code": "MARKET_UNKNOWN", "message": "Unknown market"})
        try:
            result = await service.analyse(
                normalised, body.asset, body.duration_mode, body.duration, body.language
            )
        except Exception as exc:  # noqa: BLE001
            from providers.base import DataUnavailable

            if isinstance(exc, DataUnavailable):
                raise HTTPException(
                    status_code=503,
                    detail={"code": exc.code, "message": exc.message, "detail": exc.detail},
                ) from exc
            LOG.exception("analysis failed")
            raise HTTPException(
                status_code=503,
                detail={"code": "ANALYSIS_FAILED", "message": "The analysis failed; no recommendation was issued."},
            ) from exc
        return result

    @app.get("/api/recommendations")
    async def recommendations():
        records = await store.list(limit=settings.history_limit)
        latest: dict[str, AnalysisRecord] = {}
        for record in records:
            if record.asset_key in latest:
                continue
            latest[record.asset_key] = record
        items = [_record_row(record) for record in latest.values() if record.status == "READY"]
        items.sort(
            key=lambda item: (
                float(item.get("evidence_score") or 0),
                float(item.get("confidence") or 0),
            ),
            reverse=True,
        )
        return {
            "items": items[:8],
            "count": len(items[:8]),
            "generated_at": datetime.now(timezone.utc).isoformat(),
        }

    @app.get("/api/history")
    async def history(limit: int = 50):
        safe_limit = max(1, min(int(limit), settings.history_limit))
        records = await store.list(limit=safe_limit)
        return {
            "items": [_record_row(record) for record in records],
            "stats": await store.statistics(),
        }

    @app.post("/api/chat")
    async def chat(body: ChatRequest):
        try:
            answer = await gemini.chat(
                body.message,
                [item.model_dump() for item in body.history[-10:]],
                body.context,
            )
        except AIUnavailable as exc:
            raise HTTPException(
                status_code=503,
                detail={
                    "code": "GEMINI_UNAVAILABLE",
                    "message": str(exc),
                    "note": "The chat page is separate from the analysis engine.",
                },
            ) from exc
        return {
            "answer": answer,
            "provider": "Gemini",
            "model": gemini.model,
            "time": datetime.now(timezone.utc).isoformat(),
        }

    return app


app = create_app()
