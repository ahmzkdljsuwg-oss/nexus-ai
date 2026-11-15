"""Gemini and Mistral clients. They only explain data supplied by the engine."""
from __future__ import annotations

import asyncio
import json
import re
import time
from typing import Any

import httpx

ANALYSIS_SYSTEM = (
    "You are one of two independent market analysts. Use ONLY the supplied data. "
    "Never invent prices, candles, news or sources. If evidence is weak, choose NO TRADE. "
    "Return one compact JSON object with exactly these keys: "
    '{"direction":"UP|DOWN|NO TRADE","confidence":0-100,'
    '"summary":"one sentence","reasons":["evidence"],"risks":["risk"],'
    '"invalidation":"what invalidates the view"}. '
    "Do not add markdown fences or text outside the JSON."
)

CHAT_SYSTEM = (
    "You are NEXUS AI, a factual trading education assistant. "
    "You may explain concepts, risk and the supplied analysis. Never promise profit, "
    "never invent live prices, and state clearly when the user must check the app's "
    "verified data. You do not execute trades. Answer in the user's language, concisely."
)


class AIUnavailable(Exception):
    pass


def _parse_json(text: str) -> dict[str, Any] | None:
    cleaned = text.strip()
    cleaned = re.sub(r"^```(?:json)?", "", cleaned).strip()
    cleaned = re.sub(r"```$", "", cleaned).strip()
    try:
        value = json.loads(cleaned)
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", cleaned, re.S)
        if not match:
            return None
        try:
            value = json.loads(match.group(0))
        except json.JSONDecodeError:
            return None
    if not isinstance(value, dict):
        return None
    direction = str(value.get("direction", "NO TRADE")).upper().replace("_", " ").strip()
    if direction in {"BUY", "LONG"}:
        direction = "UP"
    if direction in {"SELL", "SHORT"}:
        direction = "DOWN"
    if direction not in {"UP", "DOWN", "NO TRADE"}:
        direction = "NO TRADE"
    try:
        confidence = max(0.0, min(100.0, float(value.get("confidence", 0))))
    except (TypeError, ValueError):
        confidence = 0.0
    reasons = value.get("reasons")
    risks = value.get("risks")
    return {
        "direction": direction,
        "confidence": round(confidence, 1),
        "summary": str(value.get("summary", "")).strip(),
        "reasons": [str(x).strip() for x in reasons][:5] if isinstance(reasons, list) else [],
        "risks": [str(x).strip() for x in risks][:4] if isinstance(risks, list) else [],
        "invalidation": str(value.get("invalidation", "")).strip(),
    }


class BaseAIClient:
    name = "AI"
    model = ""

    def __init__(self, api_key: str | None, model: str, timeout: float = 35.0) -> None:
        self.api_key = api_key or None
        self.model = model
        self.timeout = timeout
        self._client: httpx.AsyncClient | None = None
        self.last_error: str | None = None

    @property
    def configured(self) -> bool:
        return bool(self.api_key)

    def _http(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(timeout=httpx.Timeout(self.timeout, connect=10.0))
        return self._client

    async def close(self) -> None:
        if self._client is not None:
            await self._client.aclose()
            self._client = None

    async def _post(self, url: str, payload: dict) -> dict:
        raise NotImplementedError

    async def analyse(self, data: dict) -> dict[str, Any]:
        if not self.configured:
            return {"provider": self.name, "online": False, "error": "API key is not configured"}
        started = time.monotonic()
        prompt = "Market data (JSON):\n" + json.dumps(data, ensure_ascii=False, default=str)
        try:
            text = await self._complete(ANALYSIS_SYSTEM, prompt, max_tokens=450, temperature=0.1)
        except AIUnavailable as exc:
            return {"provider": self.name, "online": False, "error": str(exc)}
        parsed = _parse_json(text)
        if parsed is None:
            return {"provider": self.name, "online": False, "error": "AI returned an unreadable answer"}
        parsed.update(
            {
                "provider": self.name,
                "model": self.model,
                "online": True,
                "latency_ms": round((time.monotonic() - started) * 1000),
                "error": None,
            }
        )
        self.last_error = None
        return parsed

    async def chat(self, message: str, history: list[dict[str, str]], context: str | None = None) -> str:
        if not self.configured:
            raise AIUnavailable("Gemini API key is not configured on the server")
        lines = [CHAT_SYSTEM]
        if context:
            lines.append("Current verified analysis context:\n" + context[:5000])
        lines.append("Conversation:")
        for item in history[-10:]:
            role = "User" if item.get("role") == "user" else "Assistant"
            lines.append(f"{role}: {str(item.get('content', ''))[:1500]}")
        lines.append(f"User: {message}")
        return await self._complete("\n".join(lines), message, max_tokens=700, temperature=0.3)

    async def _complete(self, system: str, user: str, max_tokens: int, temperature: float) -> str:
        raise NotImplementedError


class GeminiClient(BaseAIClient):
    name = "Gemini"

    async def _complete(self, system: str, user: str, max_tokens: int, temperature: float) -> str:
        url = (
            f"https://generativelanguage.googleapis.com/v1beta/models/{self.model}:generateContent"
            f"?key={self.api_key}"
        )
        body = {
            "systemInstruction": {"parts": [{"text": system}]},
            "contents": [{"role": "user", "parts": [{"text": user}]}],
            "generationConfig": {"temperature": temperature, "maxOutputTokens": max_tokens},
        }
        last: Exception | None = None
        for attempt in range(3):
            try:
                response = await self._http().post(url, json=body)
            except httpx.HTTPError as exc:
                last = AIUnavailable(f"Gemini network error: {exc}")
            else:
                if response.status_code in (429, 500, 502, 503, 504):
                    last = AIUnavailable(f"Gemini temporarily unavailable ({response.status_code})")
                elif response.status_code != 200:
                    self.last_error = f"Gemini HTTP {response.status_code}"
                    raise AIUnavailable(f"Gemini rejected the request ({response.status_code})")
                else:
                    try:
                        payload = response.json()
                        parts = payload["candidates"][0]["content"]["parts"]
                        text = "".join(str(part.get("text", "")) for part in parts).strip()
                    except (KeyError, IndexError, TypeError, ValueError) as exc:
                        raise AIUnavailable("Gemini returned a malformed response") from exc
                    if not text:
                        raise AIUnavailable("Gemini returned an empty answer")
                    return text
            if attempt < 2:
                await asyncio.sleep(1.5 * (attempt + 1))
        self.last_error = str(last)
        raise last or AIUnavailable("Gemini failed")


class MistralClient(BaseAIClient):
    name = "Mistral"

    async def _complete(self, system: str, user: str, max_tokens: int, temperature: float) -> str:
        body = {
            "model": self.model,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
        }
        last: Exception | None = None
        for attempt in range(3):
            try:
                response = await self._http().post(
                    "https://api.mistral.ai/v1/chat/completions",
                    json=body,
                    headers={"Authorization": f"Bearer {self.api_key}"},
                )
            except httpx.HTTPError as exc:
                last = AIUnavailable(f"Mistral network error: {exc}")
            else:
                if response.status_code in (429, 500, 502, 503, 504):
                    last = AIUnavailable(f"Mistral temporarily unavailable ({response.status_code})")
                elif response.status_code != 200:
                    self.last_error = f"Mistral HTTP {response.status_code}"
                    raise AIUnavailable(f"Mistral rejected the request ({response.status_code})")
                else:
                    try:
                        text = response.json()["choices"][0]["message"]["content"]
                    except (KeyError, IndexError, TypeError, ValueError) as exc:
                        raise AIUnavailable("Mistral returned a malformed response") from exc
                    if isinstance(text, list):
                        text = " ".join(str(part.get("text", "")) for part in text if isinstance(part, dict))
                    text = str(text).strip()
                    if not text:
                        raise AIUnavailable("Mistral returned an empty answer")
                    return text
            if attempt < 2:
                await asyncio.sleep(1.5 * (attempt + 1))
        self.last_error = str(last)
        raise last or AIUnavailable("Mistral failed")
