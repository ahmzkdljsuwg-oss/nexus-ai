#!/usr/bin/env python3
"""Deploy the NEXUS AI backend to Railway and verify it over HTTPS.

Requires RAILWAY_TOKEN in the environment. Project-creation mode is used when
RAILWAY_PROJECT_ID is absent, so a fresh account can deploy without manual setup.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

import httpx

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
PROJECT_NAME = os.getenv("RAILWAY_PROJECT_NAME", "nexus-ai")
SERVICE_NAME = os.getenv("RAILWAY_SERVICE_NAME", "nexus-ai")
SKIP_GEMINI = "--skip-gemini" in sys.argv


def fail(message: str) -> None:
    print(f"::error::{message}")
    raise SystemExit(1)


def run(args: list[str], *, cwd: Path = BACKEND, capture: bool = False) -> str:
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=capture)
    if result.returncode != 0:
        if capture and result.stderr:
            print(result.stderr.strip())
        fail(f"Command failed: {' '.join(args)}")
    return (result.stdout or "").strip() if capture else ""


def railway(*args: str) -> str:
    return run(["railway", *args], capture=True)


def main() -> None:
    if not os.getenv("RAILWAY_TOKEN"):
        fail("RAILWAY_TOKEN is not configured")

    run(["railway", "whoami"])

    project_id = os.getenv("RAILWAY_PROJECT_ID")
    if project_id:
        railway("link", "--project", project_id)
    else:
        args = ["init", "--name", PROJECT_NAME, "--json"]
        if os.getenv("RAILWAY_WORKSPACE"):
            args += ["--workspace", os.environ["RAILWAY_WORKSPACE"]]
        railway(*args)

    projects = json.loads(railway("list", "--json") or "[]")
    match = next((item for item in projects if item.get("name") == PROJECT_NAME), None)
    if not match:
        fail(f"Railway project {PROJECT_NAME} was not created")
    project_id = match.get("id", project_id or "")
    print(f"Railway project: {PROJECT_NAME} ({project_id})")

    environment = os.getenv("RAILWAY_ENVIRONMENT", "production")
    service_args = ["--project", project_id, "--environment", environment, "--service", SERVICE_NAME]

    railway("add", "--database", "postgres", "--json")
    try:
        railway("add", "--service", SERVICE_NAME, "--json")
    except SystemExit:
        pass  # the service may already exist

    variables = {
        "DATABASE_URL": "${{Postgres.DATABASE_URL}}",
        "CORS_ORIGINS": "*",
        "LOG_LEVEL": os.getenv("LOG_LEVEL", "INFO"),
        "SCANNER_ENABLED": "true",
    }
    for key in ("GEMINI_API_KEY", "GEMINI_MODEL", "MISTRAL_API_KEY", "MISTRAL_MODEL", "MT5_BRIDGE_URL", "MT5_BRIDGE_KEY", "BRIDGE_KEY"):
        value = os.getenv(key)
        if value:
            variables[key] = value
    for key, value in variables.items():
        railway("variable", "set", f"{key}={value}", *service_args, "--skip-deploys", "--json")

    railway("up", "--ci", *service_args)

    domain = json.loads(railway("domain", "--json", *service_args) or "{}")
    base_url = domain.get("domain") or domain.get("url") or ""
    if base_url and not base_url.startswith("http"):
        base_url = f"https://{base_url}"
    if not base_url:
        fail("Railway did not return a public domain")

    health = wait_for_health(base_url)
    print(json.dumps({"base_url": base_url, "health": health}, indent=2))

    gemini: dict = {"tested": False}
    if not SKIP_GEMINI:
        gemini = check_gemini(base_url)
        if not gemini.get("ok"):
            fail(f"Gemini live check failed: {gemini.get('detail')}")

    record = {
        "base_url": base_url,
        "project_id": project_id,
        "service": SERVICE_NAME,
        "environment": environment,
        "health": health,
        "gemini": gemini,
        "deployed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    (ROOT / "deployment.json").write_text(json.dumps(record, indent=2), encoding="utf-8")


def wait_for_health(base_url: str) -> dict:
    last_error = "no response"
    for _ in range(40):
        try:
            response = httpx.get(f"{base_url}/api/health", timeout=15)
            if response.status_code == 200:
                payload = response.json()
                if payload.get("database") == "postgresql":
                    return payload
                last_error = "health answered but PostgreSQL is not connected"
            else:
                last_error = f"HTTP {response.status_code}"
        except Exception as exc:  # noqa: BLE001
            last_error = type(exc).__name__
        time.sleep(5)
    fail(f"Health check did not pass: {last_error}")
    return {}


def check_gemini(base_url: str) -> dict:
    try:
        response = httpx.post(
            f"{base_url}/api/chat",
            json={"message": "Reply with the single word READY."},
            timeout=45,
        )
    except Exception as exc:  # noqa: BLE001
        return {"ok": False, "tested": True, "detail": type(exc).__name__}
    try:
        body = response.json()
    except ValueError:
        body = {}
    if response.status_code == 200 and body.get("provider") == "Gemini" and body.get("answer"):
        return {"ok": True, "tested": True, "model": body.get("model"), "answer": body.get("answer", "")[:120]}
    detail = body.get("detail") if isinstance(body, dict) else None
    return {"ok": False, "tested": True, "status": response.status_code, "detail": detail or response.text[:300]}


if __name__ == "__main__":
    main()
