"""Verify a deployed NEXUS AI backend without printing any credentials."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import argparse
import os
import sys

import httpx


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("base_url")
    parser.add_argument("--gemini", action="store_true", help="call the assistant with an authenticated test account")
    args = parser.parse_args()
    base = args.base_url.rstrip("/")

    with httpx.Client(base_url=base, timeout=60) as client:
        response = client.get("/api/health")
        print("health_status:", response.status_code)
        print("health_body:", response.json())
        response.raise_for_status()
        body = response.json()
        if body.get("database") != "ok":
            print("FAIL: database is not ok")
            return 1

        if args.gemini:
            email = os.getenv("NEXUS_VERIFY_EMAIL", "").strip()
            password = os.getenv("NEXUS_VERIFY_PASSWORD", "").strip()
            if not email or not password:
                print("FAIL: set NEXUS_VERIFY_EMAIL and NEXUS_VERIFY_PASSWORD for --gemini")
                return 2
            login = client.post("/api/auth/login", json={"email": email, "password": password, "device": "verify-script"})
            if login.status_code != 200:
                print("login_status:", login.status_code)
                return 1
            token = login.json()["access_token"]
            chat = client.post(
                "/api/assistant/chat",
                headers={"Authorization": f"Bearer {token}"},
                json={"message": "Reply with exactly NEXUS-OK", "mode": "chat"},
            )
            print("assistant_status:", chat.status_code)
            if chat.status_code != 200:
                print("assistant_body:", chat.text[:500])
                return 1
            reply = chat.json()
            print("assistant_model:", reply.get("model"))
            print("assistant_answer:", reply.get("answer", "")[:300])
            if "NEXUS-OK" not in reply.get("answer", ""):
                print("FAIL: Gemini reply did not contain NEXUS-OK")
                return 1
    print("RESULT: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
