"""NEXUS Assistant endpoint backed by Gemini."""
from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request

from app.config import get_settings
from app.deps import CurrentUser, DbSession
from app.schemas import AssistantIn, AssistantOut
from app.services.assistant import run_assistant
from app.services.gemini import GeminiClient, GeminiError

router = APIRouter(prefix="/assistant", tags=["assistant"])


def get_gemini(request: Request) -> GeminiClient:
    return request.app.state.gemini


@router.post("/chat", response_model=AssistantOut)
async def assistant_chat(
    payload: AssistantIn,
    user: CurrentUser,
    db: DbSession,
    request: Request,
) -> AssistantOut:
    client: GeminiClient = get_gemini(request)
    try:
        result = await run_assistant(
            db=db,
            user=user,
            client=client,
            settings=get_settings(),
            message=payload.message,
            chat_id=payload.chat_id,
            project_id=payload.project_id,
            mode=payload.mode,
        )
    except GeminiError as exc:
        raise HTTPException(status_code=503, detail=f"{exc.code}: {exc.message}") from exc
    return AssistantOut(
        chat_id=result.chat.id,
        answer=result.answer,
        model=get_settings().gemini_model,
        actions=result.actions,
        created_files=result.created_files,
        used_context=result.used_context,
    )
