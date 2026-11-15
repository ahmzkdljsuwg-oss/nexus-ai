from __future__ import annotations

import json
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
ROOT = BACKEND.parent


def test_railway_uses_dockerfile_and_health_check() -> None:
    config = json.loads((BACKEND / "railway.json").read_text())
    assert config["build"]["builder"] == "DOCKERFILE"
    assert config["deploy"]["healthcheckPath"] == "/api/health"
    assert "${PORT" in config["deploy"]["startCommand"]


def test_dockerfile_runs_as_non_root_and_exposes_port() -> None:
    dockerfile = (BACKEND / "Dockerfile").read_text()
    assert "USER nexus" in dockerfile
    assert "EXPOSE 8080" in dockerfile
    assert "uvicorn app.main:app" in dockerfile


def test_env_example_lists_required_runtime_variables_without_values() -> None:
    lines = [line.strip() for line in (BACKEND / ".env.example").read_text().splitlines()]
    values = dict(line.split("=", 1) for line in lines if line and not line.startswith("#") and "=" in line)
    for key in ("DATABASE_URL", "JWT_SECRET", "GEMINI_API_KEY", "GEMINI_MODEL"):
        assert key in values
    assert values["DATABASE_URL"] == ""
    assert values["JWT_SECRET"] == ""
    assert values["GEMINI_API_KEY"] == ""


def test_secrets_are_not_tracked_in_source() -> None:
    import subprocess

    tracked = subprocess.run(
        ["git", "ls-files", "*.env", ".env"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    ).stdout.strip()
    assert ".env" not in tracked.splitlines()
