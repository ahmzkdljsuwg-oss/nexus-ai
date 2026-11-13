"""Gemini orchestration with user-scoped project and file tools."""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.models import Chat, FileEntry, Message, Project, User
from app.services.files import normalize_path
from app.services.gemini import GeminiClient, GeminiError, TOOL_DECLARATIONS

MODE_INSTRUCTIONS = {
    "chat": "Answer clearly and helpfully. Be concise unless the user asks for depth.",
    "explain": "Explain the supplied code line by line for its purpose, assumptions and edge cases.",
    "review": "Review the supplied code for correctness, security and maintainability. Be specific.",
    "fix": "Diagnose the supplied code and propose a corrected version. Do not claim it was executed.",
}


@dataclass
class AssistantResult:
    chat: Chat
    answer: str
    actions: list[dict[str, str]] = field(default_factory=list)
    created_files: list[str] = field(default_factory=list)
    used_context: list[str] = field(default_factory=list)


def _system_prompt(user: User, project: Project | None, mode: str) -> str:
    language = "Arabic" if user.locale == "ar" else "English"
    project_block = "No project is attached to this conversation."
    if project is not None:
        project_block = (
            f"Attached project: {project.name}\n"
            f"Description: {project.description or '(empty)'}\n"
            f"Goals: {project.goals or '(empty)'}"
        )
    return (
        "You are NEXUS Assistant inside the NEXUS AI iPhone operating environment. "
        "You help with software, files and projects. Never invent prices, test results, "
        "credentials or claims of execution. Code is never executed on the server. "
        "When the user asks to create a project or text file you may call the provided tools; "
        "those tools only affect the signed-in user's own workspace. "
        f"Reply in {language}. Use Markdown when it improves readability.\n\n"
        f"{project_block}\n\nMode: {mode}. {MODE_INSTRUCTIONS.get(mode, MODE_INSTRUCTIONS['chat'])}"
    )


async def _context_files(db: AsyncSession, user_id: str, project_id: str | None) -> tuple[str, list[str]]:
    query = select(FileEntry).where(FileEntry.user_id == user_id, FileEntry.is_folder.is_(False))
    if project_id:
        query = query.where(FileEntry.project_id == project_id)
    rows = (await db.scalars(query.order_by(FileEntry.updated_at.desc()).limit(8))).all()
    blocks, names = [], []
    budget = 12_000
    for row in rows:
        snippet = row.content[:2500]
        if len(snippet) > budget:
            break
        budget -= len(snippet)
        names.append(row.path)
        blocks.append(f"--- FILE {row.path} ---\n{snippet}")
    return "\n\n".join(blocks), names


async def _history(db: AsyncSession, chat_id: str) -> list[dict[str, Any]]:
    rows = (
        await db.scalars(select(Message).where(Message.chat_id == chat_id).order_by(Message.created_at.asc()))
    ).all()
    return [
        {"role": "user" if row.role == "user" else "model", "parts": [{"text": row.content}]}
        for row in rows[-24:]
    ]


async def _run_tool(
    name: str,
    args: dict[str, Any],
    db: AsyncSession,
    user: User,
    default_project_id: str | None,
    actions: list[dict[str, str]],
    created_files: list[str],
    settings: Settings,
) -> str:
    if name == "create_project":
        project_name = str(args.get("name") or "").strip()[:160]
        if not project_name:
            return json.dumps({"ok": False, "error": "name is required"})
        duplicate = await db.scalar(
            select(Project).where(Project.user_id == user.id, Project.name == project_name)
        )
        if duplicate is not None:
            return json.dumps({"ok": False, "error": "a project with this name already exists"})
        project = Project(
            user_id=user.id,
            name=project_name,
            description=str(args.get("description") or "")[:8000],
            goals=str(args.get("goals") or "")[:8000],
        )
        db.add(project)
        await db.flush()
        actions.append({"tool": name, "status": "created", "detail": project.name})
        return json.dumps({"ok": True, "project_id": project.id, "name": project.name})

    if name == "create_file":
        try:
            path = normalize_path(str(args.get("path") or ""))
        except HTTPException as exc:
            return json.dumps({"ok": False, "error": str(exc.detail)})
        content = str(args.get("content") or "")
        if len(content.encode("utf-8")) > settings.max_file_bytes:
            return json.dumps({"ok": False, "error": "file is too large"})
        project_id = str(args.get("project_id") or default_project_id or "") or None
        if project_id:
            project = await db.get(Project, project_id)
            if project is None or project.user_id != user.id:
                return json.dumps({"ok": False, "error": "project not found"})
        duplicate = await db.scalar(
            select(FileEntry).where(FileEntry.user_id == user.id, FileEntry.path == path)
        )
        if duplicate is not None:
            return json.dumps({"ok": False, "error": "a file or folder already exists at this path"})
        entry = FileEntry(
            user_id=user.id, project_id=project_id, path=path, is_folder=False, content=content
        )
        db.add(entry)
        await db.flush()
        actions.append({"tool": name, "status": "created", "detail": path})
        created_files.append(path)
        return json.dumps({"ok": True, "file_id": entry.id, "path": path})

    return json.dumps({"ok": False, "error": f"unknown tool {name}"})


async def run_assistant(
    *,
    db: AsyncSession,
    user: User,
    client: GeminiClient,
    settings: Settings,
    message: str,
    chat_id: str | None,
    project_id: str | None,
    mode: str,
) -> AssistantResult:
    project: Project | None = None
    if project_id:
        project = await db.get(Project, project_id)
        if project is None or project.user_id != user.id:
            raise HTTPException(status_code=404, detail="Project not found")

    if not client.configured:
        raise GeminiError("GEMINI_NOT_CONFIGURED", "GEMINI_API_KEY is not configured on the server")

    if chat_id:
        chat = await db.get(Chat, chat_id)
        if chat is None or chat.user_id != user.id:
            raise HTTPException(status_code=404, detail="Conversation not found")
        if project is not None and chat.project_id != project.id:
            chat.project_id = project.id
    else:
        title = message.strip().splitlines()[0][:80] or "New conversation"
        chat = Chat(user_id=user.id, project_id=project_id, title=title)
        db.add(chat)
        await db.flush()

    if chat.project_id and project is None:
        project = await db.get(Project, chat.project_id)
        if project is not None and project.user_id != user.id:
            project = None

    file_context, context_names = await _context_files(db, user.id, chat.project_id)
    contents = await _history(db, chat.id)
    prompt = message.strip()
    if file_context:
        prompt += f"\n\n[Workspace context — real saved files]\n{file_context}"
    contents.append({"role": "user", "parts": [{"text": prompt}]})

    actions: list[dict[str, str]] = []
    created_files: list[str] = []
    system = _system_prompt(user, project, mode)
    answer = ""

    for _ in range(3):
        content = await client.generate(contents, system, TOOL_DECLARATIONS)
        parts = content.get("parts") or []
        text = "".join(str(part.get("text") or "") for part in parts).strip()
        calls = [part["functionCall"] for part in parts if isinstance(part.get("functionCall"), dict)]
        if text:
            answer = text
        if not calls:
            break
        contents.append({"role": "model", "parts": parts})
        responses = []
        for call in calls:
            payload = await _run_tool(
                str(call.get("name") or ""),
                call.get("args") if isinstance(call.get("args"), dict) else {},
                db,
                user,
                chat.project_id,
                actions,
                created_files,
                settings,
            )
            responses.append(
                {"functionResponse": {"name": str(call.get("name") or ""), "response": {"result": payload}}}
            )
        contents.append({"role": "user", "parts": responses})

    if not answer:
        content = await client.generate(contents, system, None)
        answer = "".join(
            str(part.get("text") or "") for part in (content.get("parts") or [])
        ).strip()
    if not answer:
        raise GeminiError("GEMINI_EMPTY", "Gemini returned no visible answer")

    db.add(Message(chat_id=chat.id, user_id=user.id, role="user", content=message.strip()))
    db.add(Message(chat_id=chat.id, user_id=user.id, role="assistant", content=answer))
    if chat.title in {"New conversation", ""}:
        chat.title = message.strip().splitlines()[0][:80]
    await db.commit()
    await db.refresh(chat)

    return AssistantResult(
        chat=chat,
        answer=answer,
        actions=actions,
        created_files=created_files,
        used_context=context_names,
    )
