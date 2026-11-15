from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from config import Settings
from engines.technical.analyzer import AnalysisResult
from providers.base import Candle, DataUnavailable, MarketData, Quote, ValidationReport
from providers.catalog import FOREX_ASSETS, timeframe

ASSET = FOREX_ASSETS[0]


def _candles() -> list[Candle]:
    now = datetime.now(timezone.utc).replace(second=0, microsecond=0)
    price, rows = 1.10, []
    for index in range(260):
        opened = price
        price += 0.00002 if index % 3 else -0.00001
        rows.append(Candle(time=now - timedelta(minutes=260 - index), open=opened,
                           high=max(opened, price) + 3e-5, low=min(opened, price) - 3e-5, close=price))
    return rows


def _data(asset=ASSET, tf="1min") -> MarketData:
    rows = _candles()
    return MarketData(asset=asset, timeframe=timeframe(tf), candles=rows, source="test-feed",
                      quote=Quote(symbol=asset.symbol, bid=rows[-1].close, ask=rows[-1].close + 1e-5,
                                  time=rows[-1].time, source="test-feed"),
                      validation=ValidationReport(ok=True, bar_count=len(rows), last_candle_time=rows[-1].time))


@pytest.fixture()
def client(tmp_path, monkeypatch):
    def fake_analyze(data, duration_seconds=None):
        return AnalysisResult(
            asset_key=data.asset.key, asset_display=data.asset.display, market=data.asset.market.value,
            timeframe=data.timeframe.code, direction="UP", confidence=74.0, score_up=9.0, score_down=1.0,
            price=data.last_close, source="test-feed", generated_at=datetime.now(timezone.utc),
            reasons=["Bullish market structure", "EMA confirmation"],
            indicators={"rsi": 56, "volatility": "LOW"}, smc={"bos": "bullish"},
            evidence_score=74.0, data_quality_score=88.0,
            invalidation=["Close below the last swing low"],
        )

    monkeypatch.setattr("app.market_service.analyze_market_data", fake_analyze)
    settings = Settings(twelve_data_api_key=None, eo_bridge_url=None, eo_bridge_key=None,
                        mt5_bridge_url=None, mt5_bridge_key=None, gemini_api_key=None, gemini_model="test",
                        mistral_api_key=None, mistral_model="test",
                        database_url=f"sqlite+aiosqlite:///{tmp_path / 'http.db'}", log_level="INFO",
                        cors_origins="*", history_limit=50, request_min_interval=0)
    monkeypatch.setenv("SCANNER_ENABLED", "false")
    app = create_app(settings)
    with TestClient(app) as http:
        service = app.state.service

        async def fake_fetch(asset, tf, limit=300):
            return _data(asset, tf if isinstance(tf, str) else tf.code)

        async def no_assets(key):
            return [ASSET]

        service.registry.fetch = fake_fetch
        service.assets = no_assets
        service._overview_cache = None
        yield http


def test_health_and_markets_shapes(client):
    health = client.get("/api/health")
    assert health.status_code == 200
    assert health.json()["service"] == "NEXUS AI"
    assert health.json()["secret_exposure"] is False

    overview = client.get("/api/markets").json()
    keys = [row["key"] for row in overview["markets"]]
    assert keys == ["OTC", "SMARTY", "FOOTBALL", "LUXURY", "AI", "CRICKET", "FOREX"]
    assert all("status" in row for row in overview["markets"])


def test_market_snapshot_supports_detail_screen(client):
    body = client.get("/api/markets/FOREX").json()
    assert body["status"] == "LIVE"
    assert body["assets"] and body["assets"][0]["key"] == ASSET.key
    assert 300 in body["durations"] and "300" in body["duration_labels"]
    assert len(body["candles"]) >= 60


def test_analyse_manual_contract(client):
    body = client.post("/api/analyse", json={"market": "FOREX", "asset": ASSET.key,
                                             "duration_mode": "manual", "duration": 60,
                                             "language": "ar"}).json()
    assert body["direction"] in {"UP", "DOWN", "NO TRADE"}
    assert body["duration_mode"] == "manual" and body["duration"] == 60
    assert body["entry"]["price_display"]
    assert body["technical"]["candle_analysis"]["candles"]
    assert "gemini" in body["ai"] and "mistral" in body["ai"] and body["ai"]["comparison"]["disclaimer"]
    assert body["disclaimer"]


def test_auto_duration_reports_reason(client):
    body = client.post("/api/analyse", json={"market": "FOREX", "asset": ASSET.key,
                                             "duration_mode": "auto"}).json()
    assert body["duration"] in body["available_durations"]
    assert body["duration_reason"]


def test_recommendations_and_history_match_mobile(client):
    client.post("/api/analyse", json={"market": "FOREX", "asset": ASSET.key, "duration_mode": "manual", "duration": 60})
    recs = client.get("/api/recommendations").json()
    assert recs["items"]
    row = recs["items"][0]
    for field in ("market", "asset", "direction", "duration_label", "evidence_score", "status", "reasons"):
        assert field in row
    history = client.get("/api/history").json()
    assert history["items"] and "verified" in history["stats"]


def test_chat_reports_missing_key_without_inventing(client):
    response = client.post("/api/chat", json={"message": "hello", "history": []})
    assert response.status_code == 503
    assert response.json()["detail"]["code"] == "GEMINI_UNAVAILABLE"


def test_market_snapshot_switches_asset(client):
    second = FOREX_ASSETS[1]

    async def two_assets(key):
        return [ASSET, second]

    client.app.state.service.assets = two_assets
    body = client.get(f"/api/markets/FOREX?asset={second.key}").json()
    assert body["status"] == "LIVE"
    assert body["asset"]["key"] == second.key
    expected = _data(second)
    assert body["price"] == pytest.approx((expected.quote.bid + expected.quote.ask) / 2)


def test_pinned_asset_never_silently_switches(client):
    second = FOREX_ASSETS[1]

    async def two_assets(key):
        return [ASSET, second]

    async def only_first_works(asset, tf, limit=300):
        if asset.key == second.key:
            raise DataUnavailable("quote missing for this pair")
        return _data(asset, tf if isinstance(tf, str) else tf.code)

    client.app.state.service.assets = two_assets
    client.app.state.service.registry.fetch = only_first_works
    body = client.get(f"/api/markets/FOREX?asset={second.key}").json()
    assert body["status"] == "UNAVAILABLE"
    assert body["asset"] is None
    assert second.symbol in body["error"]
    assert body["assets"]


def test_no_trade_is_not_stored(client, monkeypatch):
    from app.market_service import AnalysisResult

    def no_trade(data, duration_seconds=None):
        return AnalysisResult(
            asset_key=data.asset.key, asset_display=data.asset.display, market=data.asset.market.value,
            timeframe=data.timeframe.code, direction="NO TRADE", confidence=20.0, score_up=0.5, score_down=0.5,
            price=data.last_close, source="test-feed", generated_at=datetime.now(timezone.utc),
            reasons=["Conflicting evidence"], indicators={"rsi": 50, "volatility": "LOW"}, smc={},
            evidence_score=18.0, data_quality_score=60.0, invalidation=[],
        )

    monkeypatch.setattr("app.market_service.analyze_market_data", no_trade)
    body = client.post("/api/analyse", json={"market": "FOREX", "asset": ASSET.key,
                                             "duration_mode": "manual", "duration": 60}).json()
    assert body["direction"] == "NO TRADE"
    assert body["status"] == "NO_TRADE"
    assert client.get("/api/history").json()["items"] == []


def test_paid_routes_are_rate_limited(tmp_path, monkeypatch):
    settings = Settings(twelve_data_api_key=None, eo_bridge_url=None, eo_bridge_key=None,
                        mt5_bridge_url=None, mt5_bridge_key=None, gemini_api_key=None, gemini_model="test",
                        mistral_api_key=None, mistral_model="test",
                        database_url=f"sqlite+aiosqlite:///{tmp_path / 'rate.db'}", log_level="INFO",
                        cors_origins="*", history_limit=50, request_min_interval=10)
    monkeypatch.setenv("SCANNER_ENABLED", "false")
    app = create_app(settings)
    with TestClient(app) as http:
        async def fake_fetch(asset, tf, limit=300):
            return _data(asset, tf if isinstance(tf, str) else tf.code)

        async def one_asset(key):
            return [ASSET]

        http.app.state.service.registry.fetch = fake_fetch
        http.app.state.service.assets = one_asset
        payload = {"market": "FOREX", "asset": ASSET.key, "duration_mode": "manual", "duration": 60}
        first = http.post("/api/analyse", json=payload)
        second = http.post("/api/analyse", json=payload)
    assert first.status_code == 200
    assert second.status_code == 429
    assert second.headers["Retry-After"]
    assert second.json()["detail"]["code"] == "RATE_LIMITED"
