from __future__ import annotations

import pytest

from tests.conftest import auth, register


@pytest.mark.asyncio
async def test_health_reports_database_and_gemini_state(client):
    response = await client.get("/api/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["database"] == "ok"
    assert body["gemini_configured"] is False


@pytest.mark.asyncio
async def test_register_login_and_me(client):
    data = await register(client, "owner@nexus.ai")
    assert data["user"]["email"] == "owner@nexus.ai"
    assert data["access_token"]

    login = await client.post(
        "/api/auth/login", json={"email": "OWNER@nexus.ai", "password": "strong-pass-1"}
    )
    assert login.status_code == 200
    token = login.json()["access_token"]
    me = await client.get("/api/auth/me", headers=auth(token))
    assert me.status_code == 200
    assert me.json()["name"] == "Test User"


@pytest.mark.asyncio
async def test_duplicate_registration_and_bad_password(client):
    await register(client, "dup@nexus.ai")
    duplicate = await client.post(
        "/api/auth/register",
        json={"email": "dup@nexus.ai", "name": "Other", "password": "strong-pass-1"},
    )
    assert duplicate.status_code == 409
    bad = await client.post(
        "/api/auth/login", json={"email": "dup@nexus.ai", "password": "wrong-password"}
    )
    assert bad.status_code == 401


@pytest.mark.asyncio
async def test_protected_routes_require_a_valid_session(client):
    assert (await client.get("/api/projects")).status_code == 401
    assert (await client.get("/api/projects", headers=auth("not-a-jwt"))).status_code == 401


@pytest.mark.asyncio
async def test_session_inventory_and_logout(client):
    data = await register(client, "sessions@nexus.ai")
    headers = auth(data["access_token"])
    sessions = await client.get("/api/auth/sessions", headers=headers)
    assert sessions.status_code == 200
    assert len(sessions.json()) == 1
    assert sessions.json()[0]["current"] is True

    assert (await client.post("/api/auth/logout", headers=headers)).status_code == 204
    assert (await client.get("/api/auth/me", headers=headers)).status_code == 401


@pytest.mark.asyncio
async def test_settings_are_persisted(client):
    data = await register(client, "settings@nexus.ai")
    headers = auth(data["access_token"])
    update = await client.patch(
        "/api/settings", headers=headers, json={"locale": "ar", "sound_enabled": False}
    )
    assert update.status_code == 200
    assert update.json()["locale"] == "ar"
    assert update.json()["sound_enabled"] is False
    fetched = await client.get("/api/settings", headers=headers)
    assert fetched.json()["locale"] == "ar"


@pytest.mark.asyncio
async def test_projects_crud_and_user_isolation(client):
    a = await register(client, "a-projects@nexus.ai")
    b = await register(client, "b-projects@nexus.ai")
    ha, hb = auth(a["access_token"]), auth(b["access_token"])

    created = await client.post(
        "/api/projects",
        headers=ha,
        json={"name": "NEXUS Core", "description": "Backend", "goals": "Ship"},
    )
    assert created.status_code == 201
    project_id = created.json()["id"]

    assert len((await client.get("/api/projects", headers=ha)).json()) == 1
    assert (await client.get("/api/projects", headers=hb)).json() == []
    assert (await client.get(f"/api/projects/{project_id}", headers=hb)).status_code == 404

    updated = await client.patch(
        f"/api/projects/{project_id}", headers=ha, json={"goals": "Ship safely"}
    )
    assert updated.json()["goals"] == "Ship safely"
    assert (await client.delete(f"/api/projects/{project_id}", headers=hb)).status_code == 404
    assert (await client.delete(f"/api/projects/{project_id}", headers=ha)).status_code == 204
    assert (await client.get(f"/api/projects/{project_id}", headers=ha)).status_code == 404


@pytest.mark.asyncio
async def test_files_create_read_update_rename_delete_and_traversal(client, user_a):
    headers = auth(user_a["token"])
    folder = await client.post(
        "/api/files", headers=headers, json={"path": "/notes", "is_folder": True}
    )
    assert folder.status_code == 201
    created = await client.post(
        "/api/files",
        headers=headers,
        json={"path": "/notes/todo.md", "content": "first"},
    )
    assert created.status_code == 201
    file_id = created.json()["id"]

    fetched = await client.get(f"/api/files/{file_id}", headers=headers)
    assert fetched.json()["content"] == "first"
    updated = await client.patch(
        f"/api/files/{file_id}", headers=headers, json={"content": "second"}
    )
    assert updated.json()["content"] == "second"
    renamed = await client.patch(
        f"/api/files/{file_id}", headers=headers, json={"path": "/notes/plan.md"}
    )
    assert renamed.json()["path"] == "/notes/plan.md"

    traversal = await client.post(
        "/api/files", headers=headers, json={"path": "/../../etc/passwd"}
    )
    assert traversal.status_code == 422
    duplicate = await client.post(
        "/api/files", headers=headers, json={"path": "/notes/plan.md"}
    )
    assert duplicate.status_code == 409

    folder_id = folder.json()["id"]
    assert (await client.delete(f"/api/files/{folder_id}", headers=headers)).status_code == 204
    assert (await client.get(f"/api/files/{file_id}", headers=headers)).status_code == 404


@pytest.mark.asyncio
async def test_files_are_isolated_between_users(client):
    a = await register(client, "owner-files@nexus.ai")
    b = await register(client, "other-files@nexus.ai")
    created = await client.post(
        "/api/files", headers=auth(a["access_token"]), json={"path": "/secret.txt", "content": "private"}
    )
    file_id = created.json()["id"]
    assert (await client.get(f"/api/files/{file_id}", headers=auth(b["access_token"]))).status_code == 404
    assert (await client.get("/api/files", headers=auth(b["access_token"]))).json() == []


@pytest.mark.asyncio
async def test_chats_store_messages_and_are_isolated(client, user_a):
    headers = auth(user_a["token"])
    chat = await client.post("/api/chats", headers=headers, json={"title": "First"})
    assert chat.status_code == 201
    chat_id = chat.json()["id"]
    detail = await client.get(f"/api/chats/{chat_id}", headers=headers)
    assert detail.status_code == 200
    assert detail.json()["messages"] == []
    renamed = await client.patch(f"/api/chats/{chat_id}", headers=headers, json={"title": "Renamed"})
    assert renamed.json()["title"] == "Renamed"
    assert (await client.delete(f"/api/chats/{chat_id}", headers=headers)).status_code == 204


@pytest.mark.asyncio
async def test_tools_and_security_surfaces_are_real(client, user_a):
    headers = auth(user_a["token"])
    tools = await client.get("/api/tools", headers=headers)
    assert tools.status_code == 200
    assert {tool["id"] for tool in tools.json()} >= {"assistant", "smart-files", "projects"}
    security = await client.get("/api/security/status", headers=headers)
    assert security.status_code == 200
    assert security.json()["authenticated"] is True
    assert security.json()["active_sessions"] == 1


@pytest.mark.asyncio
async def test_assistant_requires_gemini_configuration(client, user_a):
    response = await client.post(
        "/api/assistant/chat", headers=auth(user_a["token"]), json={"message": "Hello"}
    )
    assert response.status_code == 503
    assert "GEMINI_NOT_CONFIGURED" in response.json()["detail"]


@pytest.mark.asyncio
async def test_account_update_name_and_password(client):
    data = await register(client, "profile@nexus.ai")
    headers = auth(data["access_token"])
    updated = await client.patch(
        "/api/account", headers=headers, json={"name": "Renamed User", "password": "new-strong-pass"}
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["name"] == "Renamed User"
    old_login = await client.post(
        "/api/auth/login", json={"email": "profile@nexus.ai", "password": "strong-pass-1"}
    )
    assert old_login.status_code == 401
    new_login = await client.post(
        "/api/auth/login", json={"email": "profile@nexus.ai", "password": "new-strong-pass"}
    )
    assert new_login.status_code == 200
    assert new_login.json()["user"]["name"] == "Renamed User"
