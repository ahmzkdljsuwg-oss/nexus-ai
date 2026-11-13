"""API request and response models."""
from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class APIModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class UserOut(APIModel):
    id: str
    email: EmailStr
    name: str
    locale: str
    appearance: str
    sound_enabled: bool
    assistant_voice: bool
    created_at: datetime


class RegisterIn(BaseModel):
    email: EmailStr
    name: str = Field(min_length=1, max_length=120)
    password: str = Field(min_length=8, max_length=128)


class LoginIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)
    device: str = Field(default="iPhone", max_length=120)


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_at: datetime
    user: UserOut


class AccountUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    password: str | None = Field(default=None, min_length=8, max_length=128)


class SettingsUpdate(BaseModel):
    locale: Literal["en", "ar"] | None = None
    appearance: Literal["dark", "midnight"] | None = None
    sound_enabled: bool | None = None
    assistant_voice: bool | None = None


class SessionOut(APIModel):
    id: str
    device: str
    created_at: datetime
    last_seen_at: datetime
    expires_at: datetime
    current: bool = False


class ProjectIn(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    description: str = Field(default="", max_length=8000)
    goals: str = Field(default="", max_length=8000)


class ProjectUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=160)
    description: str | None = Field(default=None, max_length=8000)
    goals: str | None = Field(default=None, max_length=8000)


class ProjectOut(APIModel):
    id: str
    name: str
    description: str
    goals: str
    created_at: datetime
    updated_at: datetime
    file_count: int = 0
    chat_count: int = 0


class FileIn(BaseModel):
    path: str = Field(min_length=1, max_length=512)
    is_folder: bool = False
    content: str = Field(default="", max_length=400_000)
    project_id: str | None = None


class FileUpdate(BaseModel):
    path: str | None = Field(default=None, min_length=1, max_length=512)
    content: str | None = Field(default=None, max_length=400_000)


class FileOut(APIModel):
    id: str
    project_id: str | None
    path: str
    is_folder: bool
    content: str
    updated_at: datetime


class ChatIn(BaseModel):
    title: str = Field(default="New conversation", max_length=200)
    project_id: str | None = None


class ChatUpdate(BaseModel):
    title: str = Field(min_length=1, max_length=200)


class MessageOut(APIModel):
    id: str
    role: str
    content: str
    created_at: datetime


class ChatOut(APIModel):
    id: str
    project_id: str | None
    title: str
    created_at: datetime
    updated_at: datetime
    message_count: int = 0
    last_message: str = ""


class ChatDetail(ChatOut):
    messages: list[MessageOut]


class AssistantIn(BaseModel):
    message: str = Field(min_length=1, max_length=20_000)
    chat_id: str | None = None
    project_id: str | None = None
    mode: Literal["chat", "explain", "review", "fix"] = "chat"


class AssistantAction(BaseModel):
    tool: str
    status: str
    detail: str


class AssistantOut(BaseModel):
    chat_id: str
    answer: str
    model: str
    actions: list[AssistantAction]
    created_files: list[str]
    used_context: list[str]


class ToolOut(BaseModel):
    id: str
    name: str
    summary: str
    status: Literal["available", "planned"]
    category: str
    endpoint: str | None = None


class HealthOut(BaseModel):
    status: str
    service: str
    version: str
    database: str
    gemini_configured: bool
    gemini_model: str
    time: datetime
