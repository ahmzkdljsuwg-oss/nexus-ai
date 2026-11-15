"""Environment configuration for the NEXUS AI trading backend.

Only public/backend values live here. No secret is ever sent to the mobile app.
"""
from __future__ import annotations

import os
from dataclasses import dataclass

try:
    from dotenv import load_dotenv

    load_dotenv()
except Exception:  # pragma: no cover
    pass


def _text(name: str, default: str | None = None) -> str | None:
    value = os.getenv(name)
    if value is None:
        return default
    value = value.strip().strip('"').strip("'").strip()
    return value or default


def _flag(name: str, default: bool) -> bool:
    raw = _text(name)
    if raw is None:
        return default
    return raw.lower() in {"1", "true", "yes", "on"}


def _http_url(name: str) -> str | None:
    raw = _text(name)
    if not raw:
        return None
    url = raw.strip().rstrip("/")
    if not url.startswith(("http://", "https://")):
        url = "https://" + url
    if url.endswith("/docs"):
        url = url[: -len("/docs")]
    return url


def normalise_database_url(url: str) -> str:
    if url.startswith("postgres://"):
        return "postgresql+asyncpg://" + url[len("postgres://"):]
    if url.startswith("postgresql://"):
        return "postgresql+asyncpg://" + url[len("postgresql://"):]
    if url.startswith("sqlite://") and "+aiosqlite" not in url:
        return url.replace("sqlite://", "sqlite+aiosqlite://", 1)
    return url


@dataclass(frozen=True)
class Settings:
    twelve_data_api_key: str | None
    eo_bridge_url: str | None
    eo_bridge_key: str | None
    mt5_bridge_url: str | None
    mt5_bridge_key: str | None
    gemini_api_key: str | None
    gemini_model: str
    mistral_api_key: str | None
    mistral_model: str
    database_url: str
    log_level: str
    cors_origins: str
    history_limit: int
    request_min_interval: float

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            twelve_data_api_key=_text("TWELVE_DATA_API_KEY"),
            eo_bridge_url=_http_url("EO_BRIDGE_URL"),
            eo_bridge_key=_text("EO_BRIDGE_KEY"),
            mt5_bridge_url=_http_url("MT5_BRIDGE_URL"),
            mt5_bridge_key=_text("MT5_BRIDGE_KEY"),
            gemini_api_key=_text("GEMINI_API_KEY"),
            gemini_model=_text("GEMINI_MODEL", "gemini-2.0-flash") or "gemini-2.0-flash",
            mistral_api_key=_text("MISTRAL_API_KEY"),
            mistral_model=_text("MISTRAL_MODEL", "mistral-small-latest") or "mistral-small-latest",
            database_url=_text("DATABASE_URL", "sqlite+aiosqlite:///./nexus.db") or "",
            log_level=(_text("LOG_LEVEL", "INFO") or "INFO").upper(),
            cors_origins=_text("CORS_ORIGINS", "*") or "*",
            history_limit=max(20, int(_text("HISTORY_LIMIT", "200") or 200)),
            request_min_interval=max(0.0, float(_text("REQUEST_MIN_INTERVAL", "1.0") or 1.0)),
        )

    @property
    def async_database_url(self) -> str:
        return normalise_database_url(self.database_url)

    @property
    def bridge_url(self) -> str | None:
        return self.eo_bridge_url

    def describe(self) -> dict[str, object]:
        return {
            "twelve_data": bool(self.twelve_data_api_key),
            "expertoption_bridge": bool(self.eo_bridge_url and self.eo_bridge_key),
            "mt5_bridge": bool(self.mt5_bridge_url and self.mt5_bridge_key),
            "gemini": bool(self.gemini_api_key),
            "mistral": bool(self.mistral_api_key),
            "database": "postgresql" if "postgresql" in self.async_database_url else "sqlite",
        }


settings = Settings.from_env()
