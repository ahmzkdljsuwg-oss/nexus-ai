"""Real market data, deterministic analysis and the dual-AI comparison layer."""
from __future__ import annotations

import asyncio
import time
from datetime import datetime, timedelta, timezone
from typing import Any

from app.ai_clients import BaseAIClient
from app.db import AnalysisRecord, HistoryStore
from config import Settings
from engines.technical.analyzer import AnalysisResult, analyze_market_data
from providers.base import DataUnavailable, MarketData, utc_now
from providers.catalog import Asset, Market, assets_for, get_asset, timeframe
from providers.inventory import MarketInventory
from providers.registry import DataSourceRegistry, build_registry

MARKETS: tuple[dict[str, Any], ...] = (
    {"key": "OTC", "market": Market.OTC, "label": "OTC MARKET", "icon": "🌐", "accent": "#4ADE80"},
    {"key": "SMARTY", "market": Market.SMARTY, "label": "SMARTY MARKET", "icon": "🧠", "accent": "#38BDF8"},
    {"key": "FOOTBALL", "market": Market.FOOTBALL, "label": "FOOTBALL INDEX", "icon": "⚽", "accent": "#A3E635"},
    {"key": "LUXURY", "market": Market.LUXURY, "label": "LUXURY INDEX", "icon": "💎", "accent": "#F0C75E"},
    {"key": "AI", "market": Market.AI, "label": "AI INDEX", "icon": "🤖", "accent": "#C084FC"},
    {"key": "CRICKET", "market": Market.CRICKET, "label": "CRICKET INDEX", "icon": "🏏", "accent": "#FB923C"},
    {"key": "FOREX", "market": Market.FOREX, "label": "FOREX MARKET", "icon": "💱", "accent": "#22D3EE"},
)
MARKET_BY_KEY = {item["key"]: item for item in MARKETS}
DURATION_LABELS = {
    30: "30 ثانية / 30 sec",
    60: "1 دقيقة / 1 min",
    120: "2 دقائق / 2 min",
    180: "3 دقائق / 3 min",
    300: "5 دقائق / 5 min",
    900: "15 دقيقة / 15 min",
    1800: "30 دقيقة / 30 min",
    3600: "1 ساعة / 1 hour",
}
EXPERT_DURATIONS = (30, 60, 120, 180, 300)
FOREX_DURATIONS = (60, 300, 900, 1800, 3600)


def market_key(value: str) -> str | None:
    raw = str(value).strip().upper()
    if raw == "AI INDEX":
        raw = "AI"
    return raw if raw in MARKET_BY_KEY else None


def analysis_frame(asset: Asset, duration: int) -> str:
    if asset.market.is_expertoption:
        if duration <= 30:
            return "30sec"
        if duration <= 180:
            return "1min"
        return "5min"
    if duration <= 60:
        return "1min"
    if duration <= 300:
        return "5min"
    if duration <= 900:
        return "15min"
    return "1h"


def chart_frame(asset: Asset) -> str:
    return "1min" if asset.market.is_expertoption else "5min"


def durations_for(asset: Asset) -> list[int]:
    return list(EXPERT_DURATIONS if asset.market.is_expertoption else FOREX_DURATIONS)


def _pct(value: float | None) -> float | None:
    return round(value, 2) if value is not None else None


def candle_view(candles, limit: int = 14) -> list[dict[str, Any]]:
    rows = []
    for candle in candles[-limit:]:
        span = max(candle.high - candle.low, 1e-12)
        body = abs(candle.close - candle.open)
        rows.append(
            {
                "time": candle.time.isoformat(),
                "open": candle.open,
                "high": candle.high,
                "low": candle.low,
                "close": candle.close,
                "body_pct": round(body / span * 100, 1),
                "close_position_pct": round((candle.close - candle.low) / span * 100, 1),
                "bullish": candle.close > candle.open,
            }
        )
    return rows


def _technical_payload(data: MarketData, result: AnalysisResult) -> dict[str, Any]:
    indicators = result.indicators or {}
    smc = result.smc or {}
    return {
        "market": result.market.upper(),
        "asset": result.asset_display,
        "asset_key": result.asset_key,
        "direction": result.direction,
        "confidence": round(result.confidence, 1),
        "evidence_score": round(float(result.evidence_score or result.confidence), 1),
        "price": result.price,
        "source": result.source,
        "timeframe": result.timeframe,
        "trend": result.trend_summary,
        "momentum": result.momentum_strength,
        "generated_at": result.generated_at.isoformat(),
        "reasons": list(result.reasons),
        "warnings": list(result.warnings),
        "invalidation": list(result.invalidation),
        "indicators": {
            key: indicators.get(key)
            for key in (
                "rsi", "macd", "macd_signal", "macd_hist", "ema9", "ema21", "ema50",
                "ema200", "sma20", "bb_upper", "bb_lower", "atr", "stochastic_k",
                "stochastic_d", "adx", "volatility",
            )
            if key in indicators
        },
        "smc": smc,
        "alligator_ma": result.alligator_ma,
        "confirmed_strategies": result.confirmed_strategies,
        "opposing_strategies": result.opposing_strategies,
        "candle_analysis": {
            "summary": (
                f"{result.timeframe} trend {result.trend_summary}, momentum {result.momentum_strength}, "
                f"volatility {str(indicators.get('volatility') or 'UNKNOWN')}"
            ),
            "candles": candle_view(data.candles),
        },
        "data_status": "LIVE",
    }


def _ai_prompt_payload(technical: dict[str, Any]) -> dict[str, Any]:
    return {
        "market": technical["market"],
        "asset": technical["asset"],
        "timeframe": technical["timeframe"],
        "price": technical["price"],
        "source": technical["source"],
        "engine_direction": technical["direction"],
        "engine_evidence": technical["evidence_score"],
        "trend": technical["trend"],
        "momentum": technical["momentum"],
        "indicators": technical["indicators"],
        "smc": technical["smc"],
        "reasons": technical["reasons"],
        "recent_candles": technical["candle_analysis"]["candles"][-8:],
    }


def compare_ai(technical: dict[str, Any], gemini: dict, mistral: dict) -> dict[str, Any]:
    engine = technical["direction"]
    responses = [a for a in (gemini, mistral) if a.get("online")]
    differences: list[str] = []
    agreements: list[str] = []
    for item in responses:
        if item["direction"] == engine:
            agreements.append(f"{item['provider']} agrees with the engine ({engine}).")
        elif item["direction"] == "NO TRADE":
            differences.append(f"{item['provider']} prefers NO TRADE while the engine says {engine}.")
        else:
            differences.append(
                f"{item['provider']} says {item['direction']} while the engine says {engine}."
            )
    if len(responses) == 2:
        if gemini["direction"] == mistral["direction"]:
            agreements.append("Both AI models reached the same direction.")
        else:
            differences.append("The two AI models disagree with each other.")

    final = engine
    note = "Final direction is the deterministic engine's call; AI text is comparison, not a vote count."
    if engine in {"UP", "DOWN"} and len(responses) == 2:
        if all(item["direction"] == ("DOWN" if engine == "UP" else "UP") for item in responses):
            final = "NO TRADE"
            note = "Both AI models opposed the engine, so the recommendation is withheld."
        elif sum(1 for item in responses if item["direction"] == engine) == 0:
            final = "NO TRADE"
            note = "Neither AI model supported the engine; no actionable recommendation."
        elif len({item["direction"] for item in responses} | {engine}) > 2:
            final = "NO TRADE"
            note = "The engine and the two AI models split three ways; no clear recommendation."

    if not responses:
        summary = (
            "Gemini and Mistral are not available; the deterministic technical engine produced this result alone. "
            "Configure both server-side keys to enable the comparison."
        )
    else:
        summary = (
            f"{len(responses)} AI model(s) reviewed the same verified data. "
            + " ".join(agreements + differences)
            + f" {note}"
        )
    return {
        "engine_direction": engine,
        "final_direction": final,
        "agreements": agreements,
        "differences": differences,
        "summary": summary,
        "disclaimer": (
            "Agreement between models does not guarantee a trade outcome. "
            "Confidence reflects evidence quality, not win probability."
        ),
        "responded": len(responses),
    }


class TradingService:
    def __init__(self, settings: Settings, gemini: BaseAIClient, mistral: BaseAIClient, store: HistoryStore) -> None:
        self.settings = settings
        self.gemini = gemini
        self.mistral = mistral
        self.store = store
        self.registry: DataSourceRegistry = build_registry(settings)
        bridge = next((p for p in self.registry.providers if getattr(p, "id", "") == "eo_bridge"), None)
        self.inventory = MarketInventory(bridge) if bridge is not None else None
        self._overview_cache: tuple[float, dict] | None = None

    async def close(self) -> None:
        await self.registry.close()
        await self.gemini.close()
        await self.mistral.close()

    async def assets(self, key: str) -> list[Asset]:
        item = MARKET_BY_KEY.get(key)
        if item is None:
            raise DataUnavailable("MARKET_UNKNOWN", "Unknown market")
        market: Market = item["market"]
        if market is Market.FOREX or self.inventory is None:
            return assets_for(market)
        return await self.inventory.assets(market)

    async def _market_row(self, item: dict[str, Any], include_candles: bool = True, preferred_asset: str | None = None) -> dict[str, Any]:
        row: dict[str, Any] = {
            "key": item["key"],
            "label": item["label"],
            "icon": item["icon"],
            "accent": item["accent"],
            "status": "UNAVAILABLE",
            "source": None,
            "price": None,
            "price_display": "—",
            "asset": None,
            "assets": [],
            "candles": [],
            "timeframe": None,
            "updated_at": None,
            "error": None,
        }
        try:
            assets = await self.assets(item["key"])
        except DataUnavailable as exc:
            row["error"] = exc.message
            return row
        except Exception as exc:  # noqa: BLE001
            row["error"] = f"market discovery failed: {exc}"
            return row
        row["assets"] = [
            {"key": asset.key, "symbol": asset.symbol, "display": asset.display, "name": asset.name}
            for asset in assets[:30]
        ]
        if not assets:
            row["error"] = "DATA UNAVAILABLE — this source returned no active instrument"
            return row
        if preferred_asset:
            preferred = next((candidate for candidate in assets if candidate.key == preferred_asset), None)
            if preferred is None:
                row["error"] = f"DATA UNAVAILABLE — asset {preferred_asset} is not listed for this market"
                return row
            assets = [preferred]
        candidates = assets[:1] if preferred_asset else assets[:8]
        errors: list[str] = []
        data: MarketData | None = None
        asset: Asset | None = None
        for candidate in candidates:
            try:
                data = await self.registry.fetch(candidate, chart_frame(candidate), limit=180 if include_candles else 120)
            except DataUnavailable as exc:
                errors.append(f"{candidate.display}: {exc.message}")
                continue
            except Exception as exc:  # noqa: BLE001
                errors.append(f"{candidate.display}: data fetch failed: {exc}")
                continue
            asset = candidate
            break
        if data is None or asset is None:
            row["error"] = "DATA UNAVAILABLE — " + ("; ".join(errors[:3]) or "no verified quote")
            row["source"] = self.registry.source_summary(assets[0])
            return row
        price = data.quote.mid if data.quote is not None else data.last_close
        row.update(
            {
                "status": "LIVE",
                "source": data.source,
                "asset": {"key": asset.key, "symbol": asset.symbol, "display": asset.display, "name": asset.name},
                "price": price,
                "price_display": self.format_price(price, asset),
                "timeframe": data.timeframe.label,
                "updated_at": data.last_time.isoformat() if data.last_time else None,
                "candles": [
                    {"t": c.time.isoformat(), "o": c.open, "h": c.high, "l": c.low, "c": c.close}
                    for c in data.candles[-80:]
                ]
                if include_candles
                else [],
            }
        )
        return row

    async def overview(self, force: bool = False) -> dict[str, Any]:
        now = time.monotonic()
        if not force and self._overview_cache and self._overview_cache[0] > now:
            return self._overview_cache[1]
        rows = await asyncio.gather(*(self._market_row(item, include_candles=False) for item in MARKETS))
        payload = {
            "markets": rows,
            "total_markets": len(rows),
            "available_markets": sum(1 for row in rows if row["status"] == "LIVE"),
            "ai": {
                "gemini": {"configured": self.gemini.configured, "model": self.gemini.model},
                "mistral": {"configured": self.mistral.configured, "model": self.mistral.model},
            },
            "generated_at": utc_now().isoformat(),
        }
        self._overview_cache = (now + 25.0, payload)
        return payload

    async def snapshot(self, key: str, asset_key: str | None = None) -> dict[str, Any]:
        item = MARKET_BY_KEY.get(key)
        if item is None:
            raise DataUnavailable("MARKET_UNKNOWN", "Unknown market")
        row = await self._market_row(item, include_candles=True, preferred_asset=asset_key)
        row["durations"] = FOREX_DURATIONS if item["market"] is Market.FOREX else EXPERT_DURATIONS
        row["duration_labels"] = {str(value): DURATION_LABELS[value] for value in row["durations"]}
        row["ai"] = {
            "gemini": {"configured": self.gemini.configured, "model": self.gemini.model},
            "mistral": {"configured": self.mistral.configured, "model": self.mistral.model},
        }
        return row

    async def _analyse_once(self, asset: Asset, duration: int) -> tuple[MarketData, AnalysisResult]:
        data = await self.registry.fetch(asset, analysis_frame(asset, duration), limit=260)
        return data, analyze_market_data(data, duration_seconds=duration)

    async def analyse(
        self,
        key: str,
        asset_key: str | None,
        duration_mode: str,
        duration: int | None,
        language: str = "en",
    ) -> dict[str, Any]:
        if duration_mode not in {"manual", "auto"}:
            raise DataUnavailable("DURATION_MODE", "duration_mode must be manual or auto")
        assets = await self.assets(key)
        asset = get_asset(asset_key) if asset_key else (assets[0] if assets else None)
        if asset is None and asset_key and self.inventory is not None:
            asset = await self.inventory.resolve(asset_key)
        if asset is None or asset.market is not MARKET_BY_KEY[key]["market"]:
            raise DataUnavailable("ASSET_UNAVAILABLE", "This asset is not available in the selected market")
        allowed = durations_for(asset)
        chosen = duration
        reason = "The trade duration was selected manually and is not changed by the engine."
        data: MarketData | None = None
        result: AnalysisResult | None = None

        if duration_mode == "manual":
            if duration not in allowed:
                raise DataUnavailable("DURATION_UNSUPPORTED", "This duration is not supported for this asset")
            try:
                data, result = await self._analyse_once(asset, int(duration))
            except DataUnavailable as exc:
                return await self._unavailable(asset, key, exc, allowed, duration_mode, duration)
        else:
            best: tuple[tuple[float, float, float], int, AnalysisResult, MarketData] | None = None
            failures: list[str] = []
            cache: dict[str, MarketData] = {}
            for candidate in allowed:
                frame = analysis_frame(asset, candidate)
                try:
                    frame_data = cache.get(frame)
                    if frame_data is None:
                        frame_data = await self.registry.fetch(asset, frame, limit=260)
                        cache[frame] = frame_data
                    frame_result = analyze_market_data(frame_data, duration_seconds=candidate)
                except DataUnavailable as exc:
                    failures.append(exc.message)
                    continue
                if frame_result.direction not in {"UP", "DOWN"}:
                    continue
                rank = (
                    float(frame_result.evidence_score or 0),
                    float(frame_result.data_quality_score or 0),
                    frame_result.confidence,
                )
                if best is None or rank > best[0]:
                    best = (rank, candidate, frame_result, frame_data)
            if best is None:
                exc = DataUnavailable(
                    "NO_ACTIONABLE_SETUP",
                    "DATA UNAVAILABLE — no actionable setup across supported durations",
                    "; ".join(failures[:3]) or "The evidence did not pass the confirmation rules",
                )
                return await self._unavailable(asset, key, exc, allowed, duration_mode, None)
            _, chosen, result, data = best
            reason = (
                f"Suggestion only: {DURATION_LABELS[chosen].split(' / ')[0]} is the nearest verified expiry "
                f"to the {result.timeframe} structure. Trend {result.trend_summary}, "
                f"momentum {result.momentum_strength}, evidence {result.confidence:.0f}%. "
                "This duration is an estimate from current candles, not a guarantee."
            )

        assert data is not None and result is not None
        technical = _technical_payload(data, result)
        prompt_data = _ai_prompt_payload(technical)
        gemini_result, mistral_result = await asyncio.gather(
            self.gemini.analyse(prompt_data),
            self.mistral.analyse(prompt_data),
        )
        comparison = compare_ai(technical, gemini_result, mistral_result)
        final_direction = comparison["final_direction"]
        actionable = final_direction in {"UP", "DOWN"}
        status = "READY" if actionable else "NO_TRADE"

        generated = result.generated_at
        expires = generated + timedelta(seconds=int(chosen or 0)) if actionable and chosen else None
        payload = {
            "market": key,
            "market_label": MARKET_BY_KEY[key]["label"],
            "asset_key": asset.key,
            "asset": asset.display,
            "symbol": asset.symbol,
            "direction": final_direction,
            "signal_ar": "شراء" if final_direction == "UP" else "بيع" if final_direction == "DOWN" else "لا توجد فرصة",
            "status": status,
            "confidence": round(result.confidence, 1) if actionable else None,
            "evidence_score": round(float(result.evidence_score or result.confidence), 1),
            "confidence_note": (
                "Evidence quality, not a probability of winning. "
                "Verified trade results are shown separately in history."
            ),
            "duration": chosen,
            "duration_label": DURATION_LABELS.get(chosen or 0, "—"),
            "duration_mode": duration_mode,
            "duration_reason": reason,
            "available_durations": allowed,
            "duration_labels": {str(value): DURATION_LABELS[value] for value in allowed},
            "timeframe": result.timeframe,
            "entry": {
                "price": result.price if actionable else None,
                "price_display": self.format_price(result.price, asset) if actionable else "—",
                "time": generated.isoformat(),
                "valid_until": expires.isoformat() if expires else None,
                "condition": (
                    "Enter only while the price is within 0.15% of the displayed entry and the status is READY."
                    if actionable
                    else "No entry: the engine did not issue an actionable recommendation."
                ),
                "invalidation": list(result.invalidation)
                or ([comparison["summary"]] if not actionable else ["A close beyond the opposing structure invalidates the setup."]),
            },
            "reasons": list(result.reasons) if actionable else [],
            "no_trade_reason": None if actionable else (
                result.cancellation_reason
                or comparison["summary"]
                or "The evidence did not pass the confirmation rules."
            ),
            "source": result.source,
            "data_status": "LIVE",
            "generated_at": generated.isoformat(),
            "technical": technical,
            "ai": {
                "gemini": gemini_result,
                "mistral": mistral_result,
                "comparison": comparison,
            },
            "disclaimer": (
                "NEXUS AI analyses data; it never executes trades and never guarantees profit. "
                "Trading carries risk of loss."
            ),
        }
        if actionable:
            record = AnalysisRecord(
                market=key,
                asset_key=asset.key,
                asset=asset.display,
                direction=final_direction,
                confidence=float(result.confidence),
                duration_seconds=int(chosen or 0),
                entry_price=result.price,
                source=result.source,
                status=status,
                result="OPEN",
                created_at=generated,
                expires_at=expires,
                payload=payload,
                summary=str(result.reasons[0]) if result.reasons else comparison["summary"],
            )
            record = await self.store.save(record)
            payload["record_id"] = record.id
            payload["entry"]["record_id"] = record.id
        else:
            payload["record_id"] = None
        return payload

    async def _unavailable(
        self,
        asset: Asset,
        key: str,
        exc: DataUnavailable,
        allowed: list[int],
        mode: str,
        duration: int | None,
    ) -> dict[str, Any]:
        payload = {
            "market": key,
            "market_label": MARKET_BY_KEY[key]["label"],
            "asset_key": asset.key,
            "asset": asset.display,
            "symbol": asset.symbol,
            "direction": "NO TRADE",
            "signal_ar": "لا توجد فرصة",
            "status": "UNAVAILABLE",
            "confidence": None,
            "evidence_score": 0.0,
            "duration": duration,
            "duration_label": DURATION_LABELS.get(duration or 0, "—"),
            "duration_mode": mode,
            "duration_reason": exc.message,
            "available_durations": allowed,
            "duration_labels": {str(value): DURATION_LABELS[value] for value in allowed},
            "timeframe": analysis_frame(asset, duration or allowed[0]),
            "entry": {
                "price": None,
                "price_display": "—",
                "time": None,
                "valid_until": None,
                "condition": "No entry: verified market data is unavailable.",
                "invalidation": [exc.message],
            },
            "reasons": [],
            "no_trade_reason": exc.message,
            "source": None,
            "data_status": "UNAVAILABLE",
            "generated_at": utc_now().isoformat(),
            "technical": None,
            "ai": {
                "gemini": {"provider": "Gemini", "online": False, "error": "Not called: market data unavailable"},
                "mistral": {"provider": "Mistral", "online": False, "error": "Not called: market data unavailable"},
                "comparison": {
                    "summary": "AI analysis was not requested because the market data failed validation.",
                    "disclaimer": "No recommendation is issued from unverified data.",
                },
            },
            "disclaimer": "No recommendation is issued from stale or unavailable data.",
            "error": {"code": exc.code, "message": exc.message, "detail": exc.detail},
        }
        return payload

    def format_price(self, price: float | None, asset: Asset) -> str:
        if price is None:
            return "—"
        return f"{price:.{asset.price_precision}f}"

    async def verify_due(self) -> int:
        now = utc_now()
        due = await self.store.open_expired(now)
        resolved = 0
        for record in due:
            try:
                asset = get_asset(record.asset_key)
                if asset is None:
                    await self.store.resolve(record.id, "UNVERIFIED", None, now)
                    resolved += 1
                    continue
                quote = await asyncio.wait_for(self.registry.quote_for_verification(asset, 90), timeout=8)
            except Exception:  # noqa: BLE001
                if record.expires_at is not None:
                    expires = record.expires_at
                    if expires.tzinfo is None:
                        expires = expires.replace(tzinfo=timezone.utc)
                    if (now - expires).total_seconds() > 300:
                        await self.store.resolve(record.id, "UNVERIFIED", None, now)
                        resolved += 1
                continue
            entry = record.entry_price or 0.0
            if entry <= 0:
                await self.store.resolve(record.id, "UNVERIFIED", quote.mid, now)
            elif abs(quote.mid - entry) <= max(entry * 1e-6, 1e-9):
                await self.store.resolve(record.id, "DRAW", quote.mid, now)
            elif (record.direction == "UP" and quote.mid > entry) or (record.direction == "DOWN" and quote.mid < entry):
                await self.store.resolve(record.id, "WIN", quote.mid, now)
            else:
                await self.store.resolve(record.id, "LOSS", quote.mid, now)
            resolved += 1
        return resolved
