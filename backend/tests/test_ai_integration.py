from __future__ import annotations

import json

import httpx
import pytest

from app.ai_clients import GeminiClient, MistralClient


MARKET_DATA = {
    "asset": "EUR/USD",
    "market": "FOREX",
    "price": 1.10216,
    "timeframe": "M5",
    "candles": [
        {"t": "2026-11-09T16:00:00Z", "o": 1.1020, "h": 1.1024, "l": 1.1019, "c": 1.1023},
        {"t": "2026-11-09T16:05:00Z", "o": 1.1023, "h": 1.1026, "l": 1.1021, "c": 1.10216},
    ],
    "indicators": {"rsi": 56.2, "ema200": 1.1005, "adx": 24.1},
}


def _gemini_transport(seen: list[dict], direction: str = "UP"):
    def handler(request: httpx.Request) -> httpx.Response:
        body = json.loads(request.content)
        seen.append({"url": str(request.url), "key": request.url.params.get("key"), "body": body})
        text = json.dumps(
            {
                "direction": direction,
                "confidence": 71,
                "summary": "Bullish structure above EMA 200.",
                "reasons": ["Higher highs", "RSI above 50"],
                "risks": ["Resistance overhead"],
                "invalidation": "Close below 1.1005",
            }
        )
        return httpx.Response(200, json={"candidates": [{"content": {"parts": [{"text": text}]}}]})

    return httpx.MockTransport(handler)


def _mistral_transport(seen: list[dict], direction: str = "DOWN"):
    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(
            {
                "url": str(request.url),
                "auth": request.headers.get("Authorization"),
                "body": json.loads(request.content),
            }
        )
        text = json.dumps(
            {
                "direction": direction,
                "confidence": 64,
                "summary": "Momentum fading at resistance.",
                "reasons": ["Lower high", "Momentum divergence"],
                "risks": ["Trend still up"],
                "invalidation": "Close above 1.1030",
            }
        )
        return httpx.Response(200, json={"choices": [{"message": {"content": text}}]})

    return httpx.MockTransport(handler)


@pytest.mark.asyncio
async def test_both_models_receive_identical_market_payload():
    gemini_seen: list[dict] = []
    mistral_seen: list[dict] = []
    gemini = GeminiClient("gemini-test-key", "gemini-2.0-flash")
    mistral = MistralClient("mistral-test-key", "mistral-small-latest")
    gemini._client = httpx.AsyncClient(transport=_gemini_transport(gemini_seen))
    mistral._client = httpx.AsyncClient(transport=_mistral_transport(mistral_seen))
    try:
        up = await gemini.analyse(MARKET_DATA)
        down = await mistral.analyse(MARKET_DATA)
    finally:
        await gemini.close()
        await mistral.close()

    assert up["online"] is True and up["direction"] == "UP" and up["reasons"]
    assert down["online"] is True and down["direction"] == "DOWN" and down["risks"]
    assert up["direction"] != down["direction"]

    gemini_prompt = gemini_seen[0]["body"]["contents"][0]["parts"][0]["text"]
    mistral_prompt = mistral_seen[0]["body"]["messages"][1]["content"]
    assert gemini_prompt == mistral_prompt
    assert "EUR/USD" in gemini_prompt and "1.10216" in gemini_prompt
    assert gemini_seen[0]["key"] == "gemini-test-key"
    assert mistral_seen[0]["auth"] == "Bearer mistral-test-key"
    assert gemini_seen[0]["body"]["systemInstruction"]["parts"][0]["text"].startswith(
        "You are one of two independent market analysts"
    )


@pytest.mark.asyncio
async def test_gemini_error_does_not_leak_key():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(401, json={"error": {"message": "invalid key"}})

    client = GeminiClient("super-secret-key", "gemini-2.0-flash")
    client._client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    try:
        result = await client.analyse(MARKET_DATA)
    finally:
        await client.close()
    assert result["online"] is False
    assert "super-secret-key" not in str(result)


@pytest.mark.asyncio
async def test_chat_uses_separate_chat_prompt():
    seen: list[dict] = []
    client = GeminiClient("gemini-test-key", "gemini-2.0-flash")
    client._client = httpx.AsyncClient(transport=_gemini_transport(seen, direction="UP"))
    try:
        answer = await client.chat("What is RSI?", [{"role": "user", "content": "hi"}], context="EUR/USD UP")
    finally:
        await client.close()
    assert answer
    system = seen[0]["body"]["systemInstruction"]["parts"][0]["text"]
    assert "NEXUS AI" in system
    assert "independent market analysts" not in system
