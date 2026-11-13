"""Minimal Gemini REST client. The API key stays on the server."""
from __future__ import annotations

from typing import Any

import httpx

from app.config import Settings

GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models"

TOOL_DECLARATIONS = [
    {
        "name": "create_project",
        "description": "Create a NEXUS project owned by the signed-in user.",
        "parameters": {
            "type": "OBJECT",
            "properties": {
                "name": {"type": "STRING", "description": "Short unique project name"},
                "description": {"type": "STRING"},
                "goals": {"type": "STRING"},
            },
            "required": ["name"],
        },
    },
    {
        "name": "create_file",
        "description": "Create a text file inside Smart Files. Never execute it.",
        "parameters": {
            "type": "OBJECT",
            "properties": {
                "path": {"type": "STRING", "description": "Absolute virtual path such as /notes/plan.md"},
                "content": {"type": "STRING"},
                "project_id": {"type": "STRING", "description": "Optional existing project id"},
            },
            "required": ["path"],
        },
    },
]


class GeminiError(Exception):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


class GeminiClient:
    def __init__(self, settings: Settings, transport: httpx.AsyncBaseTransport | None = None) -> None:
        self.settings = settings
        self._transport = transport

    @property
    def configured(self) -> bool:
        return self.settings.gemini_configured

    async def generate(
        self,
        contents: list[dict[str, Any]],
        system_instruction: str,
        tools: list[dict] | None = None,
    ) -> dict[str, Any]:
        if not self.configured:
            raise GeminiError("GEMINI_NOT_CONFIGURED", "GEMINI_API_KEY is not configured on the server")
        body: dict[str, Any] = {
            "systemInstruction": {"parts": [{"text": system_instruction}]},
            "contents": contents,
            "generationConfig": {
                "temperature": 0.4,
                "maxOutputTokens": self.settings.gemini_max_output_tokens,
            },
        }
        if tools:
            body["tools"] = [{"functionDeclarations": tools}]
        try:
            async with httpx.AsyncClient(
                timeout=httpx.Timeout(self.settings.gemini_timeout_seconds, connect=10.0),
                transport=self._transport,
            ) as client:
                response = await client.post(
                    f"{GEMINI_BASE}/{self.settings.gemini_model}:generateContent",
                    headers={
                        "x-goog-api-key": self.settings.gemini_api_key,
                        "Content-Type": "application/json",
                    },
                    json=body,
                )
        except httpx.TimeoutException as exc:
            raise GeminiError("GEMINI_TIMEOUT", "Gemini did not answer before the timeout") from exc
        except httpx.HTTPError as exc:
            raise GeminiError("GEMINI_UNREACHABLE", "Could not reach the Gemini API") from exc

        if response.status_code == 429:
            raise GeminiError("GEMINI_RATE_LIMIT", "Gemini rate limit reached; try again shortly")
        if response.status_code in {401, 403}:
            raise GeminiError("GEMINI_AUTH", "Gemini rejected the server API key")
        if response.status_code >= 400:
            raise GeminiError("GEMINI_ERROR", f"Gemini returned HTTP {response.status_code}")
        try:
            payload = response.json()
        except ValueError as exc:
            raise GeminiError("GEMINI_BAD_RESPONSE", "Gemini returned a non-JSON response") from exc
        candidates = payload.get("candidates") or []
        if not candidates:
            blocked = (payload.get("promptFeedback") or {}).get("blockReason")
            raise GeminiError(
                "GEMINI_BLOCKED" if blocked else "GEMINI_EMPTY",
                "Gemini did not return an answer" + (f" ({blocked})" if blocked else ""),
            )
        return candidates[0].get("content") or {}

    async def close(self) -> None:
        return None
