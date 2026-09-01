"""Canonical local conversation metadata for every FatCat client."""

from __future__ import annotations

import json
import os
import threading
from copy import deepcopy
from pathlib import Path


class SessionConflict(ValueError):
    """Raised when code tries to silently replace a saved Hermes session."""


class ConversationStore:
    def __init__(self, path: Path):
        self.path = path
        self._lock = threading.RLock()
        self._document = self._load()

    def snapshot(self) -> dict:
        with self._lock:
            return deepcopy(self._document)

    def get(self, conversation_id: str) -> dict | None:
        with self._lock:
            record = self._find(conversation_id)
            return deepcopy(record) if record else None

    def create(self, conversation_id: str, title: str, workspace_path: str) -> dict:
        conversation_id = conversation_id.strip()
        if not conversation_id:
            raise ValueError("conversation_id is required")
        with self._lock:
            if self._find(conversation_id):
                raise ValueError(f"conversation already exists: {conversation_id}")
            record = {
                "id": conversation_id,
                "title": title.strip() or "New chat",
                "workspace_path": str(Path(workspace_path).expanduser()),
                "session_id": None,
                "messages": [],
            }
            self._document["records"].append(record)
            self._document["selected_id"] = conversation_id
            self._save()
            return deepcopy(record)

    def select(self, conversation_id: str) -> None:
        with self._lock:
            if self._find(conversation_id) is None:
                raise KeyError(conversation_id)
            self._document["selected_id"] = conversation_id
            self._save()

    def attach_session(self, conversation_id: str, session_id: str) -> None:
        session_id = session_id.strip()
        if not session_id:
            raise ValueError("session_id is required")
        with self._lock:
            record = self._required(conversation_id)
            existing = record.get("session_id")
            if existing and existing != session_id:
                raise SessionConflict(f"conversation {conversation_id} is already attached to {existing}")
            if existing == session_id:
                return
            record["session_id"] = session_id
            self._save()

    def append_message(self, conversation_id: str, message_id: str, role: str, text: str) -> dict:
        if role not in {"user", "assistant", "system"}:
            raise ValueError(f"unsupported message role: {role}")
        with self._lock:
            record = self._required(conversation_id)
            existing = next((item for item in record["messages"] if item["id"] == message_id), None)
            if existing:
                return deepcopy(existing)
            message = {"id": message_id, "role": role, "text": text}
            record["messages"].append(message)
            self._save()
            return deepcopy(message)

    def append_assistant_delta(self, conversation_id: str, message_id: str, text: str) -> dict:
        with self._lock:
            record = self._required(conversation_id)
            message = next((item for item in record["messages"] if item["id"] == message_id), None)
            if message is None:
                message = {"id": message_id, "role": "assistant", "text": ""}
                record["messages"].append(message)
            message["text"] += text
            self._save()
            return deepcopy(message)

    def _load(self) -> dict:
        try:
            value = json.loads(self.path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            return {"selected_id": None, "records": []}
        except (OSError, json.JSONDecodeError) as error:
            raise ValueError(f"invalid conversation store: {error}") from error
        if not isinstance(value, dict) or not isinstance(value.get("records"), list):
            raise ValueError("invalid conversation store document")
        value.setdefault("selected_id", None)
        return value

    def _find(self, conversation_id: str) -> dict | None:
        return next((item for item in self._document["records"] if item.get("id") == conversation_id), None)

    def _required(self, conversation_id: str) -> dict:
        record = self._find(conversation_id)
        if record is None:
            raise KeyError(conversation_id)
        return record

    def _save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.path.with_suffix(self.path.suffix + ".tmp")
        temporary.write_text(json.dumps(self._document, separators=(",", ":")), encoding="utf-8")
        os.replace(temporary, self.path)
