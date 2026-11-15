"""Checks the Swift app's declared HTTP routes against the backend OpenAPI schema."""
from __future__ import annotations

import re
from pathlib import Path

import pytest

from app.main import app

SWIFT_ROOT = Path(__file__).resolve().parents[2] / "ios" / "NexusAI"
PATH_PATTERN = re.compile(r'(?:get|send|sendNoContent)\("(api/[^"]+)"')

EXPECTED_METHODS = {
    "api/health": {"get"},
    "api/auth/register": {"post"},
    "api/auth/login": {"post"},
    "api/auth/logout": {"post"},
    "api/auth/sessions": {"get"},
    "api/auth/sessions/": {"delete"},
    "api/account": {"get", "patch"},
    "api/settings": {"patch"},
    "api/projects": {"get", "post"},
    "api/projects/": {"patch", "delete"},
    "api/files": {"get", "post"},
    "api/files/": {"patch", "delete"},
    "api/chats": {"get"},
    "api/chats/": {"get"},
    "api/assistant/chat": {"post"},
    "api/security/status": {"get"},
    "api/tools": {"get"},
}


def swift_routes() -> set[str]:
    routes: set[str] = set()
    for source in SWIFT_ROOT.rglob("*.swift"):
        for route in PATH_PATTERN.findall(source.read_text(encoding="utf-8")):
            routes.add(re.sub(r"\\\([^)]*\)", "", route))
    return routes


@pytest.mark.parametrize("route", sorted(EXPECTED_METHODS))
def test_swift_route_exists_in_backend(route: str) -> None:
    schema = app.openapi()
    candidates = {path for path in schema["paths"] if path.startswith("/" + route)}
    assert candidates, f"Swift client calls {route} but backend exposes no matching path"
    methods = set()
    for path in candidates:
        methods.update(schema["paths"][path].keys())
    missing = EXPECTED_METHODS[route] - methods
    assert not missing, f"{route} is missing HTTP methods {sorted(missing)} in backend"


def test_client_and_backend_route_inventory_agree() -> None:
    backend_paths = {path.lstrip("/") for path in app.openapi()["paths"]}
    missing = {route for route in swift_routes() if not any(p.startswith(route) for p in backend_paths)}
    assert not missing, f"Swift client routes with no backend handler: {sorted(missing)}"
