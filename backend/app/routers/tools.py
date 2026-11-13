"""NEXUS Store: only capabilities that exist in this backend are listed."""
from __future__ import annotations

from fastapi import APIRouter

from app.deps import CurrentUser
from app.schemas import ToolOut

router = APIRouter(prefix="/tools", tags=["tools"])

AVAILABLE_TOOLS = [
    ToolOut(
        id="assistant",
        name="NEXUS Assistant",
        summary="Gemini conversation with saved history, project context and file context.",
        status="available",
        category="Intelligence",
        endpoint="/api/assistant/chat",
    ),
    ToolOut(
        id="smart-files",
        name="Smart Files",
        summary="Create, read, rename and delete text files and folders in a private workspace.",
        status="available",
        category="Workspace",
        endpoint="/api/files",
    ),
    ToolOut(
        id="projects",
        name="Projects",
        summary="Separate project memory with goals, files and conversations.",
        status="available",
        category="Workspace",
        endpoint="/api/projects",
    ),
    ToolOut(
        id="developer-studio",
        name="Developer Studio",
        summary="Edit code and ask Gemini to explain, review or propose fixes. Code is never executed.",
        status="available",
        category="Development",
        endpoint="/api/assistant/chat",
    ),
    ToolOut(
        id="security-center",
        name="Security Center",
        summary="Session inventory, revocation, server health and account security checks.",
        status="available",
        category="System",
        endpoint="/api/security/status",
    ),
]


@router.get("", response_model=list[ToolOut])
async def list_tools(user: CurrentUser) -> list[ToolOut]:
    return AVAILABLE_TOOLS
