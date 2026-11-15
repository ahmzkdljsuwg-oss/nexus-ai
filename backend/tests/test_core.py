from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest

from app.ai_clients import _parse_json
from app.db import HistoryStore
from app.market_service import (
    MARKET_BY_KEY,
    TradingService,
    analysis_frame,
    compare_ai,
    durations_for,
    market_key,
    strong_gate,
)
from config import Settings
from providers.base import Candle, MarketData, Quote, ValidationReport
from providers.catalog import FOREX_ASSETS, timeframe


def test_market_keys_and_durations():
    assert market_key("ai index") == "AI"
    assert market_key("forex") == "FOREX"
    assert market_key("unknown") is None
    asset = FOREX_ASSETS[0]
    assert 300 in durations_for(asset)
    assert analysis_frame(asset, 300) == "5min"


def test_ai_json_parser_rejects_markdown_and_clamps():
    parsed = _parse_json(
        '```json\n{"direction":"buy","confidence":150,"summary":"x","reasons":["a"],"risks":[],"invalidation":"y"}\n```'
    )
    assert parsed is not None
    assert parsed["direction"] == "UP"
    assert parsed["confidence"] == 100.0


def test_compare_ai_without_models_keeps_engine():
    technical = {"direction": "UP"}
    gemini = {"provider": "Gemini", "online": False}
    mistral = {"provider": "Mistral", "online": False}
    out = compare_ai(technical, gemini, mistral)
    assert out["final_direction"] == "UP"
    assert out["responded"] == 0
    assert "not available" in out["summary"]


def test_compare_ai_blocks_three_way_split():
    technical = {"direction": "UP"}
    gemini = {"provider": "Gemini", "online": True, "direction": "DOWN"}
    mistral = {"provider": "Mistral", "online": True, "direction": "NO TRADE"}
    out = compare_ai(technical, gemini, mistral)
    assert out["final_direction"] == "NO TRADE"
    assert out["differences"]


def _market_data() -> MarketData:
    asset = FOREX_ASSETS[0]
    tf = timeframe("1min")
    now = datetime.now(timezone.utc).replace(second=0, microsecond=0)
    candles = []
    price = 1.10
    for index in range(260):
        opened = price
        price += 0.00002 if index % 3 else -0.00001
        candles.append(
            Candle(
                time=now - timedelta(minutes=260 - index),
                open=opened,
                high=max(opened, price) + 0.00003,
                low=min(opened, price) - 0.00003,
                close=price,
            )
        )
    quote = Quote(symbol="EUR/USD", bid=price - 0.00001, ask=price + 0.00001, time=now, source="test")
    return MarketData(
        asset=asset,
        timeframe=tf,
        candles=candles,
        source="test",
        quote=quote,
        validation=ValidationReport(ok=True, bar_count=len(candles), last_candle_time=candles[-1].time),
    )


class FakeAI:
    configured = True
    model = "test-model"

    def __init__(self, direction: str) -> None:
        self.direction = direction

    async def analyse(self, data: dict) -> dict:
        return {
            "provider": "Gemini" if self.direction == "UP" else "Mistral",
            "online": True,
            "direction": self.direction,
            "confidence": 70,
            "summary": "test",
            "reasons": ["ema"],
            "risks": [],
            "invalidation": "close beyond",
        }

    async def close(self) -> None:
        return None


@pytest.mark.asyncio
async def test_analysis_persists_only_actionable_results(tmp_path, monkeypatch):
    from engines.technical.analyzer import AnalysisResult

    def fake_analyze(data, duration_seconds=None):
        return AnalysisResult(
            asset_key=data.asset.key,
            asset_display=data.asset.display,
            market=data.asset.market.value,
            timeframe=data.timeframe.code,
            direction="UP",
            confidence=72.0,
            score_up=8.0,
            score_down=1.0,
            price=data.last_close,
            source="test",
            generated_at=datetime.now(timezone.utc),
            reasons=["Bullish market structure", "EMA confirmation"],
            indicators={"rsi": 55, "volatility": "LOW"},
            smc={"bos": "bullish"},
            evidence_score=72.0,
            data_quality_score=80.0,
            invalidation=["Close below the last swing low"],
        )

    monkeypatch.setattr("app.market_service.analyze_market_data", fake_analyze)
    settings = Settings(
        twelve_data_api_key=None,
        eo_bridge_url=None,
        eo_bridge_key=None,
        mt5_bridge_url=None,
        mt5_bridge_key=None,
        gemini_api_key="test",
        gemini_model="test",
        mistral_api_key="test",
        mistral_model="test",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'test.db'}",
        log_level="INFO",
        cors_origins="*",
        history_limit=50,
        request_min_interval=0,
    )
    store = HistoryStore(settings)
    await store.init()
    service = TradingService(settings, FakeAI("UP"), FakeAI("UP"), store)

    async def fake_fetch(asset, tf, limit=300):
        data = _market_data()
        return MarketData(
            asset=asset,
            timeframe=timeframe(tf) if isinstance(tf, str) else tf,
            candles=data.candles,
            source="test",
            quote=data.quote,
            validation=data.validation,
        )

    service.registry.fetch = fake_fetch  # type: ignore[assignment]
    payload = await service.analyse("FOREX", "EUR_USD_FOREX", "manual", 60)
    assert payload["data_status"] == "LIVE"
    assert payload["technical"]["candle_analysis"]["candles"]
    assert payload["ai"]["comparison"]["responded"] == 2
    assert payload["record_id"] is not None
    stats = await store.statistics()
    assert stats["total"] == 1
    await service.close()
    await store.close()


def _result(data, confirmations: int):
    from engines.technical.analyzer import AnalysisResult

    return AnalysisResult(
        asset_key=data.asset.key,
        asset_display=data.asset.display,
        market=data.asset.market.value,
        timeframe=data.timeframe.code,
        direction="UP",
        confidence=76.0,
        score_up=8.0,
        score_down=1.0,
        price=data.last_close,
        source="test",
        generated_at=datetime.now(timezone.utc),
        reasons=["Bullish market structure"],
        indicators={"rsi": 55, "volatility": "NORMAL"},
        evidence_score=76.0,
        data_quality_score=82.0,
        confirmed_strategies=[{"name": f"confirm-{index}"} for index in range(confirmations)],
    )


def test_strong_gate_requires_three_confirmations():
    data = _market_data()
    weak = strong_gate(_result(data, 1))
    assert any("confirmations" in item for item in weak)
    assert strong_gate(_result(data, 3)) == []


@pytest.mark.asyncio
async def test_strong_and_normal_modes_run_end_to_end(tmp_path, monkeypatch):
    def fake_analyze(data, duration_seconds=None):
        return _result(data, 3)

    monkeypatch.setattr("app.market_service.analyze_market_data", fake_analyze)
    settings = Settings(
        twelve_data_api_key=None,
        eo_bridge_url=None,
        eo_bridge_key=None,
        mt5_bridge_url=None,
        mt5_bridge_key=None,
        gemini_api_key="test",
        gemini_model="test",
        mistral_api_key="test",
        mistral_model="test",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'modes.db'}",
        log_level="INFO",
        cors_origins="*",
        history_limit=50,
        request_min_interval=0,
    )
    store = HistoryStore(settings)
    await store.init()
    service = TradingService(settings, FakeAI("UP"), FakeAI("UP"), store)

    async def fake_fetch(asset, tf, limit=300):
        data = _market_data()
        return MarketData(
            asset=asset,
            timeframe=timeframe(tf) if isinstance(tf, str) else tf,
            candles=data.candles,
            source="test",
            quote=data.quote,
            validation=data.validation,
        )

    service.registry.fetch = fake_fetch  # type: ignore[assignment]

    normal = await service.analyse("FOREX", "EUR_USD_FOREX", "auto", None, analysis_mode="normal")
    assert normal["analysis_mode"] == "normal"
    assert normal["mode_label"] == "NORMAL ANALYSIS"
    assert normal["direction"] in {"UP", "DOWN", "NO TRADE"}
    assert normal["technical"]["candle_analysis"]["candle_state"] in {"FORMING", "CLOSED", "UNKNOWN"}

    strong = await service.analyse("FOREX", "EUR_USD_FOREX", "auto", None, analysis_mode="strong")
    assert strong["analysis_mode"] == "strong"
    assert strong["mode_label"] == "STRONG ANALYSIS"
    assert strong["strong_gate"] == []
    assert strong["direction"] in {"UP", "DOWN", "NO TRADE"}

    repeated = await service.analyse("FOREX", "EUR_USD_FOREX", "auto", None, analysis_mode="strong")
    if repeated["direction"] in {"UP", "DOWN"}:
        assert repeated["duplicate"] is True

    stats = await store.statistics()
    assert stats["total"] >= 1
    await service.close()
    await store.close()


@pytest.mark.asyncio
@pytest.mark.parametrize("market", list(MARKET_BY_KEY))
async def test_both_modes_on_each_market_with_simulated_candles(tmp_path, monkeypatch, market):
    def fake_analyze(data, duration_seconds=None):
        return _result(data, 3)

    monkeypatch.setattr("app.market_service.analyze_market_data", fake_analyze)
    settings = Settings(
        twelve_data_api_key=None,
        eo_bridge_url=None,
        eo_bridge_key=None,
        mt5_bridge_url=None,
        mt5_bridge_key=None,
        gemini_api_key="test",
        gemini_model="test",
        mistral_api_key="test",
        mistral_model="test",
        database_url=f"sqlite+aiosqlite:///{tmp_path / (market + '.db')}",
        log_level="INFO",
        cors_origins="*",
        history_limit=50,
        request_min_interval=0,
    )
    store = HistoryStore(settings)
    await store.init()
    service = TradingService(settings, FakeAI("UP"), FakeAI("UP"), store)

    async def fake_fetch(asset, tf, limit=300):
        data = _market_data()
        return MarketData(
            asset=asset,
            timeframe=timeframe(tf) if isinstance(tf, str) else tf,
            candles=data.candles,
            source="test",
            quote=data.quote,
            validation=data.validation,
        )

    from providers.catalog import ASSETS

    service.registry.fetch = fake_fetch  # type: ignore[assignment]

    async def fake_assets(selected, force=False):
        return [asset for asset in ASSETS if asset.market is selected]

    service.inventory.assets = fake_assets  # type: ignore[assignment]
    assets = [asset for asset in ASSETS if asset.market is MARKET_BY_KEY[market]["market"]]
    if not assets:
        await service.close()
        await store.close()
        pytest.skip(f"{market} has no registered asset")

    for mode in ("normal", "strong"):
        payload = await service.analyse(market, None, "auto", None, analysis_mode=mode)
        assert payload["analysis_mode"] == mode
        assert payload["market"] == market
        assert payload["direction"] in {"UP", "DOWN", "NO TRADE"}
        assert payload["data_status"] in {"LIVE", "UNAVAILABLE"}

    await service.close()
    await store.close()
