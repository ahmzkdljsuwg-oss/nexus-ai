#!/usr/bin/env python3
"""Deploy NEXUS AI to Railway with PostgreSQL, then verify it.

Requires RAILWAY_TOKEN in the environment. GEMINI_API_KEY is optional; when it is
present the key is set on the service as well and the real Gemini check runs.
No secret is ever printed by this script.
"""
from __future__ import annotations

import argparse
import json
import os
import secrets
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"


def railway_bin() -> str:
    candidate = os.getenv("RAILWAY_BIN", "").strip()
    if candidate:
        return candidate
    found = shutil.which("railway")
    if found:
        return found
    fallback = Path("/tmp/node_modules/.bin/railway")
    if fallback.exists():
        return str(fallback)
    raise SystemExit("railway CLI not found; install it or set RAILWAY_BIN")


def run(args: list[str], *, stdin: str | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        [railway_bin(), *args],
        cwd=ROOT,
        input=stdin,
        text=True,
        capture_output=True,
        env=os.environ.copy(),
    )
    if check and result.returncode != 0:
        message = (result.stderr or result.stdout).strip()
        raise SystemExit(f"railway {' '.join(args[:2])} failed: {message[:800]}")
    return result


def run_json(args: list[str], *, check: bool = True) -> dict:
    result = run([*args, "--json"], check=False)
    if result.returncode != 0:
        if check:
            message = (result.stderr or result.stdout).strip()
            raise SystemExit(f"railway {' '.join(args)} failed: {message[:800]}")
        return {}
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        if check:
            message = (result.stderr or result.stdout).strip()
            raise SystemExit(f"railway {' '.join(args)} returned non-JSON output: {message[:500]}") from exc
        return {}


def find_name(payload: object) -> str | None:
    if isinstance(payload, dict):
        if isinstance(payload.get("name"), str):
            return payload["name"]
        for value in payload.values():
            name = find_name(value)
            if name:
                return name
    elif isinstance(payload, list):
        for value in payload:
            name = find_name(value)
            if name:
                return name
    return None


def ensure_project(name: str, workspace: str | None) -> None:
    args = ["init", "--name", name]
    if workspace:
        args += ["--workspace", workspace]
    result = run_json(args, check=False)
    if result:
        print("project:", name)
        return

    projects = run_json(["list"])
    entries = projects if isinstance(projects, list) else projects.get("projects", [])
    match = next((item for item in entries if isinstance(item, dict) and item.get("name") == name), None)
    if not match:
        raise SystemExit(f"could not create or find Railway project {name}")
    project_id = match.get("id") or match.get("projectId")
    if not project_id:
        raise SystemExit("existing Railway project has no id")
    link = ["link", str(project_id), "--json"]
    if workspace:
        link += ["--workspace", workspace]
    run(link)
    print("project: reusing", name)


def service_names() -> list[dict]:
    payload = run_json(["service", "list"])
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]
    services = payload.get("services", [])
    return [item for item in services if isinstance(item, dict)]


def ensure_service(name: str) -> None:
    if any(item.get("name") == name for item in service_names()):
        print("service: reusing", name)
    else:
        run_json(["add", "--service", name])
        print("service: created", name)
    run(["link", "--service", name, "--json"], check=False)


def ensure_postgres() -> str:
    existing = service_names()
    for item in existing:
        label = str(item.get("name", "")).lower()
        if "postgres" in label:
            print("database: reusing", item.get("name"))
            return str(item.get("name"))
    payload = run_json(["add", "--database", "postgres"])
    name = find_name(payload) or "Postgres"
    print("database: created", name)
    return name


def set_variable(key: str, value: str | None, service: str) -> None:
    if value is None:
        return
    if value == "":
        return
    run(["variable", "set", key, "--stdin", "--skip-deploys", "--service", service], stdin=value + "\n")


def deploy(service: str) -> None:
    print("uploading source and starting deployment ...")
    result = run(["up", "--service", service, "--detach", "--yes"], check=False)
    if result.returncode != 0:
        message = (result.stderr or result.stdout).strip()
        raise SystemExit(f"railway up failed: {message[-1200:]}")
    print("deployment started")


def public_domain(service: str) -> str | None:
    result = run(["domain", "--service", service, "--json"], check=False)
    if result.returncode != 0:
        return None
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None
    if isinstance(payload, dict):
        value = payload.get("domain") or payload.get("hostname") or payload.get("url")
        if value:
            return str(value)
    return None


def wait_for_health(url: str, timeout: int = 600) -> dict:
    import httpx

    deadline = time.time() + timeout
    last = ""
    while time.time() < deadline:
        try:
            response = httpx.get(f"{url}/api/health", timeout=20)
            if response.status_code == 200:
                body = response.json()
                if body.get("database") == "ok":
                    return body
                last = f"database={body.get('database')}"
            else:
                last = f"HTTP {response.status_code}"
        except Exception as exc:  # network is expected to fail while booting
            last = type(exc).__name__
        time.sleep(10)
    raise SystemExit(f"health check did not pass within {timeout}s ({last})")


def verify(url: str, gemini: bool) -> int:
    args = [sys.executable, str(BACKEND / "scripts" / "verify_production.py"), url]
    if gemini:
        args.append("--gemini")
    result = subprocess.run(args, cwd=BACKEND, text=True)
    return result.returncode


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-name", default="nexus-ai")
    parser.add_argument("--service", default="nexus-api")
    parser.add_argument("--workspace", default=os.getenv("RAILWAY_WORKSPACE", ""))
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--skip-gemini", action="store_true")
    args = parser.parse_args()

    if not os.getenv("RAILWAY_TOKEN", "").strip():
        raise SystemExit("RAILWAY_TOKEN is not set")

    ensure_project(args.project_name, args.workspace.strip() or None)
    database = ensure_postgres()
    ensure_service(args.service)

    set_variable("ENVIRONMENT", "production", args.service)
    set_variable("LOG_LEVEL", "INFO", args.service)
    set_variable("ALLOW_REGISTRATION", "true", args.service)
    set_variable("GEMINI_MODEL", os.getenv("GEMINI_MODEL", "gemini-2.5-flash"), args.service)
    set_variable("DATABASE_URL", "${{%s.DATABASE_URL}}" % database, args.service)
    set_variable("JWT_SECRET", secrets.token_hex(32), args.service)

    gemini_key = os.getenv("GEMINI_API_KEY", "").strip()
    if gemini_key:
        set_variable("GEMINI_API_KEY", gemini_key, args.service)
        print("gemini: key configured")
    else:
        print("gemini: GEMINI_API_KEY not provided; assistant verification will be skipped")

    deploy(args.service)
    domain = public_domain(args.service) or ""
    url = domain if domain.startswith("http") else f"https://{domain}" if domain else ""
    if not url:
        raise SystemExit("deployment started but no public domain was returned")
    url = url.rstrip("/")
    print("url:", url)

    health = wait_for_health(url, args.timeout)
    print("health: ok", json.dumps(health, default=str))

    status = verify(url, bool(gemini_key) and not args.skip_gemini)
    record = {
        "project": args.project_name,
        "service": args.service,
        "database_service": database,
        "url": url,
        "health": health,
        "gemini_configured": health.get("gemini_configured"),
        "verification_exit_code": status,
        "verified_at": datetime.now(timezone.utc).isoformat(),
    }
    (ROOT / "deployment.json").write_text(json.dumps(record, indent=2, default=str) + "\n")
    if status != 0:
        print("verification failed; see output above")
        return status
    print("RESULT: deployed and verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
