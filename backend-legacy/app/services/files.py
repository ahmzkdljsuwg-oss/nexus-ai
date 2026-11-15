"""Virtual text-file system. Paths are user-scoped and never touch the host disk."""
from __future__ import annotations

import re

from fastapi import HTTPException

from app.models import FileEntry


def normalize_path(raw: str, allow_root: bool = False) -> str:
    value = (raw or "").strip().replace("\\", "/")
    if not value:
        raise HTTPException(status_code=422, detail="Path is required")
    parts = []
    for part in value.split("/"):
        if part in {"", "."}:
            continue
        if part == "..":
            raise HTTPException(status_code=422, detail="Path traversal is not allowed")
        if len(part) > 120:
            raise HTTPException(status_code=422, detail="A path segment is too long")
        parts.append(part)
    path = "/" + "/".join(parts)
    if path == "/" and not allow_root:
        raise HTTPException(status_code=422, detail="Root cannot be used as a file path")
    return path


def parent_of(path: str) -> str:
    if path.count("/") <= 1:
        return "/"
    return path.rsplit("/", 1)[0]


def safe_folder_name(name: str) -> str:
    value = re.sub(r"[^\w .\-]", "_", name.strip(), flags=re.UNICODE)
    return value[:120] or "folder"


def is_descendant(path: str, folder: str) -> bool:
    return path.startswith(folder.rstrip("/") + "/")


def serialise(entry: FileEntry) -> dict:
    return {
        "id": entry.id,
        "project_id": entry.project_id,
        "path": entry.path,
        "is_folder": entry.is_folder,
        "content": entry.content,
        "updated_at": entry.updated_at,
    }
