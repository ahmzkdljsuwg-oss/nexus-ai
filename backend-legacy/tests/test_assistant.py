from __future__ import annotations

import json

import httpx
import pytest

from app.config import Settings
from app.services.gemini import GeminiClient, GeminiError
from tests.conftest import auth, register


class FakeGemini:
    configured = True

    def __init__(self, responses):
        self.responses = list(responses)
        self.calls = []

    async def generate(self, contents, system_instruction, tools=None):
        self.calls.append({"contents": contents, "system": system_instruction, "tools": tools})
        return self.responses.pop(0)


@pytest.mark.asyncio
async def test_assistant_saves_history_and_sends_context(client, user_a):
    from app.main import app

    fake = FakeGemini([
        {"parts": [{"text": "First answer"}]},
        {"parts": [{"text": "Second answer"}]},
    ])
    app.state.gemini = fake
    headers = auth(user_a["token"])
    project = await client.post(
        "/api/projects",
        headers=headers,
        json={"name": "Context", "description": "NEXUS context project", "goals": "Test memory"},
    )
    project_id = project.json()["id"]
    await client.post(
        "/api/files",
        headers=headers,
        json={"path": "/context/notes.md", "content": "unique-context-marker", "project_id": project_id},
    )

    first = await client.post(
        "/api/assistant/chat",
        headers=headers,
        json={"message": "Hello", "project_id": project_id},
    )
    assert first.status_code == 200, first.text
    body = first.json()
    assert body["answer"] == "First answer"
    assert body["used_context"] == ["/context/notes.md"]
    assert "unique-context-marker" in fake.calls[0]["contents"][-1]["parts"][0]["text"]
    assert "Context" in fake.calls[0]["system"]

    second = await client.post(
        "/api/assistant/chat",
        headers=headers,
        json={"message": "Remember me", "chat_id": body["chat_id"]},
    )
    assert second.status_code == 200
    sent = fake.calls[1]["contents"]
    assert [item["role"] for item in sent] == ["user", "model", "user"]
    assert sent[1]["parts"][0]["text"] == "First answer"

    history = await client.get(f"/api/chats/{body['chat_id']}", headers=headers)
    assert history.status_code == 200
    assert [message["role"] for message in history.json()["messages"]] == [
        "user",
        "assistant",
        "user",
        "assistant",
    ]


@pytest.mark.asyncio
async def test_assistant_tool_creates_project_and_file(client, user_a):
    from app.main import app

    fake = FakeGemini([
        {
            "parts": [
                {
                    "functionCall": {
                        "name": "create_project",
                        "args": {"name": "Studio", "description": "Built by assistant"},
                    }
                }
            ]
        },
        {
            "parts": [
                {
                    "functionCall": {
                        "name": "create_file",
                        "args": {"path": "/studio/readme.md", "content": "# Studio"},
                    }
                }
            ]
        },
        {"parts": [{"text": "Project and file created."}]},
    ])
    app.state.gemini = fake
    headers = auth(user_a["token"])
    response = await client.post(
        "/api/assistant/chat", headers=headers, json={"message": "Create a studio project"}
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["answer"] == "Project and file created."
    assert body["created_files"] == ["/studio/readme.md"]
    assert [action["tool"] for action in body["actions"]] == ["create_project", "create_file"]

    projects = (await client.get("/api/projects", headers=headers)).json()
    assert projects[0]["name"] == "Studio"
    files = (await client.get("/api/files", headers=headers)).json()
    assert files[0]["path"] == "/studio/readme.md"


@pytest.mark.asyncio
async def test_assistant_cannot_attach_another_users_project(client):
    a = await register(client, "assistant-a@nexus.ai")
    b = await register(client, "assistant-b@nexus.ai")
    project = await client.post(
        "/api/projects", headers=auth(a["access_token"]), json={"name": "Private"}
    )
    response = await client.post(
        "/api/assistant/chat",
        headers=auth(b["access_token"]),
        json={"message": "Read it", "project_id": project.json()["id"]},
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_gemini_client_uses_header_key_and_surfaces_rate_limit():
    seen = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen["key"] = request.headers.get("x-goog-api-key")
        seen["url"] = str(request.url)
        seen["body"] = json.loads(request.content)
        return httpx.Response(200, json={"candidates": [{"content": {"parts": [{"text": "hi"}]}}]})

    settings = Settings(gemini_api_key="test-key", gemini_model="gemini-test")
    client = GeminiClient(settings, transport=httpx.MockTransport(handler))
    content = await client.generate([{"role": "user", "parts": [{"text": "hello"}]}], "system")
    assert content["parts"][0]["text"] == "hi"
    assert seen["key"] == "test-key"
    assert "key=" not in seen["url"]
    assert seen["body"]["systemInstruction"]["parts"][0]["text"] == "system"

    limited = GeminiClient(
        settings,
        transport=httpx.MockTransport(lambda request: httpx.Response(429, json={})),
    )
    with pytest.raises(GeminiError) as error:
        await limited.generate([], "system")
    assert error.value.code == "GEMINI_RATE_LIMIT"


@pytest.mark.asyncio
async def test_real_gemini_connection_automatically_when_key_available():
    import os

    key = os.getenv("GEMINI_API_KEY", "").strip()
    if not key:
        pytest.skip("GEMINI_API_KEY is not set")
    settings = Settings(gemini_api_key=key)
    client = GeminiClient(settings)
    content = await client.generate(
        [{"role": "user", "parts": [{"text": "Reply with exactly: NEXUS-OK"}]}],
        "You are a connectivity probe.",
    )
    text = "".join(part.get("text", "") for part in content.get("parts", []))
    assert "NEXUS-OK" in text
