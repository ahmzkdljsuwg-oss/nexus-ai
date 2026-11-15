"""Exercises the backend over a real TCP socket, without external API keys."""
from __future__ import annotations

import os
import socket
import subprocess
import sys
import time
from pathlib import Path

import httpx
import pytest

BACKEND = Path(__file__).resolve().parents[1]


def free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


@pytest.fixture(scope="module")
def live_server(tmp_path_factory: pytest.TempPathFactory):
    port = free_port()
    db = tmp_path_factory.mktemp("http") / "integration.db"
    env = {
        **os.environ,
        "DATABASE_URL": f"sqlite+aiosqlite:///{db}",
        "JWT_SECRET": "http-integration-secret-long-enough",
        "ENVIRONMENT": "test",
        "GEMINI_API_KEY": "",
        "PORT": str(port),
    }
    process = subprocess.Popen(
        [sys.executable, "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", str(port)],
        cwd=BACKEND,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    base = f"http://127.0.0.1:{port}"
    deadline = time.time() + 25
    while time.time() < deadline:
        if process.poll() is not None:
            output = process.stdout.read() if process.stdout else ""
            pytest.fail(f"uvicorn exited early:\n{output}")
        try:
            if httpx.get(f"{base}/api/health", timeout=1).status_code == 200:
                break
        except httpx.HTTPError:
            time.sleep(0.2)
    else:
        process.terminate()
        pytest.fail("uvicorn did not become ready")
    yield base
    process.terminate()
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()


def test_health_over_real_http(live_server: str) -> None:
    response = httpx.get(f"{live_server}/api/health", timeout=10)
    body = response.json()
    assert response.status_code == 200
    assert body["status"] == "ok"
    assert body["database"] == "ok"
    assert body["gemini_configured"] is False


def test_register_login_and_read_account_over_real_http(live_server: str) -> None:
    email = f"http-{time.time_ns()}@nexus.ai"
    password = "integration-pass-1"
    register = httpx.post(
        f"{live_server}/api/auth/register",
        json={"email": email, "name": "HTTP", "password": password},
        timeout=10,
    )
    assert register.status_code == 201, register.text
    login = httpx.post(
        f"{live_server}/api/auth/login",
        json={"email": email, "password": password, "device": "pytest"},
        timeout=10,
    )
    assert login.status_code == 200, login.text
    token = login.json()["access_token"]
    me = httpx.get(f"{live_server}/api/account", headers={"Authorization": f"Bearer {token}"}, timeout=10)
    assert me.status_code == 200
    assert me.json()["email"] == email


def test_protected_route_rejects_missing_token_over_real_http(live_server: str) -> None:
    response = httpx.get(f"{live_server}/api/projects", timeout=10)
    assert response.status_code == 401
