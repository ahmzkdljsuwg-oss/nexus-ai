from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class AnalyseRequest(BaseModel):
    market: str = Field(min_length=2, max_length=24)
    asset: str | None = Field(default=None, max_length=80)
    duration_mode: Literal["manual", "auto"] = "auto"
    duration: int | None = Field(default=None, ge=5, le=3600)
    language: Literal["en", "ar"] = "en"


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=4000)


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    history: list[ChatMessage] = Field(default_factory=list, max_length=20)
    context: str | None = Field(default=None, max_length=6000)
